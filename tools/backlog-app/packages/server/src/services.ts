// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The composition of the server's services: one instance of each, wired together, with the
 * rules that connect them.
 *
 * The central rule is the read source (research R10): the working tree is read only while it is on
 * `main`, no run holds the run lock and no auto-triage runs; otherwise everything is read from
 * `main`'s git objects. Whenever the loop or the repository changes, the source, the watcher and
 * the write gate are re-evaluated and changes are published to every tab.
 */

import type { ReadRef, WriteGate } from "@backlog-app/shared";
import type { ServerContext } from "./context.ts";
import { BacklogTool } from "./backlog/tool.ts";
import { ReadModel } from "./backlog/read-model.ts";
import { computeGate } from "./backlog/write-gate.ts";
import { LoopMonitor } from "./loop/monitor.ts";
import { LoopControl } from "./loop/control.ts";
import { RepoMonitor } from "./repo/monitor.ts";
import { SettingsStore } from "./settings/store.ts";
import { HistoryService } from "./features/history.ts";
import { WriteQueue } from "./backlog/write-queue.ts";
import { ChangeTray } from "./backlog/tray.ts";
import { RunsService } from "./runs/service.ts";
import { Notifications } from "./events/notifications.ts";
import type { SessionAuth } from "./gate/token.ts";

/** All services of one server process. */
export class Services {
  /** The server context. */
  readonly ctx: ServerContext;

  /** The session secrets. */
  readonly auth: SessionAuth;

  /** The backlog tool adapter. */
  readonly tool: BacklogTool;

  /** The repository state poller. */
  readonly repo: RepoMonitor;

  /** The loop status poller. */
  readonly loop: LoopMonitor;

  /** The loop's control commands. */
  readonly loopControl: LoopControl;

  /** The cached backlog read model. */
  readonly read: ReadModel;

  /** Settings and saved views. */
  readonly settings: SettingsStore;

  /** Item history and the closed-items archive. */
  readonly history: HistoryService;

  /** The serial queue of changes (edit lock, gate, revisions). */
  readonly queue: WriteQueue;

  /** The change tray (uncommitted changes, undo, commit). */
  readonly tray: ChangeTray;

  /** The live run and the run history. */
  readonly runs: RunsService;

  /** The notification log. */
  readonly notifications: Notifications;

  /** The last published gate (to publish only changes). */
  private lastGate = "";

  /** The last read source (to reload when it changes). */
  private lastSource: ReadRef | null = null;

  /** The commit of `main` the read model last saw (to reload when `main` moves). */
  private lastMain: string | null = null;

  /**
   * Creates and wires every service (nothing runs before {@link Services.start}).
   *
   * @param ctx - The server context.
   * @param auth - The session secrets.
   */
  constructor(ctx: ServerContext, auth: SessionAuth) {
    this.ctx = ctx;
    this.auth = auth;
    this.tool = new BacklogTool(ctx.repo.root);
    this.repo = new RepoMonitor(ctx);
    this.loop = new LoopMonitor(ctx);
    this.loopControl = new LoopControl(ctx, this.loop);
    this.read = new ReadModel(ctx, this.tool, () => this.source());
    this.settings = new SettingsStore(ctx.state);
    this.history = new HistoryService(ctx);
    this.queue = new WriteQueue(this);
    this.tray = new ChangeTray(ctx);
    this.runs = new RunsService(this);
    this.notifications = new Notifications(ctx);
    this.runs.onEnded = (id) => this.announceRunEnd(id);
  }

  /**
   * Announces the end of a run once the loop indexed it (its outcome comes from the journal).
   *
   * @param id - The run id.
   */
  private announceRunEnd(id: string): void {
    // The loop writes the index line right after the run ends; give it a few seconds.
    setTimeout(() => {
      void this.runs
        .list()
        .then((runs) => {
          const run = runs.find((r) => r.id === id);
          const outcome = run?.outcome ?? "unknown";
          this.notifications.announce({
            kind: "run-ended",
            severity: outcome === "closed" || outcome === "triaged" ? "info" : "attention",
            title:
              run?.kind === "triage"
                ? "The auto-triage ended"
                : `Run of ${run?.slug ?? "an item"}: ${outcome}`,
            text: run?.note ?? (run?.feature ? `Feature ${run.feature}.` : "See the run for details."),
            link: `/runs/${id}`,
          });
        })
        .catch(() => undefined);
    }, 4000);
  }

  /**
   * Commits the change tray before the loop starts or resumes, so the loop never waits on the
   * app's own uncommitted changes (research R11). Does nothing when the tray is empty.
   *
   * @returns The commit hash, or null when there was nothing to commit.
   */
  async commitTrayForLoop(): Promise<string | null> {
    if (this.tray.pending().length === 0) return null;
    const message = this.tray.proposedMessage();
    return this.queue.run("commit the change tray before the loop", null, null, () =>
      this.tray.commit(message, []),
    );
  }

  /**
   * Where the backlog is read from now (research R10).
   *
   * @returns `worktree` or `main`.
   */
  source(): ReadRef {
    const repo = this.repo.state;
    const loop = this.loop.view;
    if (!repo || repo.branch !== "main") return "main";
    if (!loop || loop.lock || loop.shown === "triage") return "main";
    return "worktree";
  }

  /**
   * The write gate now.
   *
   * @returns The gate.
   */
  gate(): WriteGate {
    return computeGate({
      loop: this.loop.view,
      repo: this.repo.state,
      degraded: this.read.degraded !== null,
      checkTotal: this.read.peek()?.check.total ?? 0,
    });
  }

  /** Starts the pollers and connects their changes. */
  start(): void {
    /** Re-evaluates source, watcher and gate after any change. */
    const onChange = (): void => {
      this.reconcile();
    };
    this.repo.onChange(onChange);
    this.loop.onChange(onChange);
    this.repo.start();
    this.loop.start();
    this.read.start();
    this.runs.start();
  }

  /** Stops every poller and watcher. */
  stop(): void {
    this.repo.stop();
    this.loop.stop();
    this.read.stop();
    this.runs.stop();
  }

  /**
   * Stops everything and waits until no tool or git process of the pollers runs any more.
   *
   * @returns Resolves when idle.
   */
  async stopAndDrain(): Promise<void> {
    this.stop();
    await this.queue.idle();
    await Promise.all([this.repo.idle(), this.loop.idle(), this.read.idle()]);
  }

  /**
   * Re-evaluates the source, the watcher and the gate after a change of the loop or the
   * repository, and publishes what changed.
   */
  reconcile(): void {
    const source = this.source();
    const main = this.repo.state?.mainCommit ?? null;
    if (source !== this.lastSource || (source === "main" && main !== this.lastMain)) {
      this.lastSource = source;
      this.lastMain = main;
      this.read.syncWatcher();
      this.read.invalidate();
    }
    this.publishGate();
    const snapshot = this.read.peek();
    this.notifications.observe({
      loop: this.loop.view,
      inbox: snapshot
        ? (snapshot.board.sections.find((sec) => sec.name === "Inbox")?.rows.length ?? 0)
        : null,
      check: snapshot ? snapshot.check.total : null,
    });
  }

  /** Publishes the gate when it changed. */
  publishGate(): void {
    const gate = this.gate();
    const key = JSON.stringify(gate);
    if (key !== this.lastGate) {
      this.lastGate = key;
      this.ctx.hub.publish("gate.changed", gate);
    }
  }
}
