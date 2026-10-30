// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The read model: the board, legend, next-up and check result the views show, read through
 * the backlog tool and kept until something changes (research R1, R10).
 *
 * Where the data comes from (research R10):
 * - the working tree, when it is on `main` and no run holds the run lock - then uncommitted
 *   changes of the change tray are visible;
 * - otherwise `main`'s git objects (`--ref main`): during a run the working tree is on the run's
 *   branch, and reading files a run replaces risks failing its atomic replace (analysis A2 §5.1).
 *   `main` is also what the loop takes its next item from.
 *
 * Reloads happen when the watcher sees a change in `backlog/` (working tree), when `main` moves,
 * when the source changes, and every 20 seconds as a safety net for lost notifications. A changed
 * revision is published as `board.changed`.
 */

import { watch, type FSWatcher } from "node:fs";
import { join } from "node:path";
import type { Board, CheckResult, Legend, NextUp, ReadRef } from "@backlog-app/shared";
import type { ServerContext } from "../context.ts";
import type { BacklogTool } from "./tool.ts";

/** Everything the views read, from one source at one moment. */
export interface Snapshot {
  /** Where it was read from. */
  source: ReadRef;
  /** The board, with item bodies and issue texts (stripped before sending to clients). */
  board: Board;
  /** The legend. */
  legend: Legend;
  /** The next-up answer. */
  next: NextUp;
  /** The check result (only from the working tree; from `main` the last known one). */
  check: CheckResult;
  /** When it was read (ms since the epoch). */
  at: number;
}

/** Milliseconds of quiet after a file notification before reloading. */
const DEBOUNCE_MS = 250;

/** Milliseconds between safety reloads. */
const SAFETY_MS = 20_000;

/** The cached read model with its reload triggers. */
export class ReadModel {
  /** The server context. */
  private readonly ctx: ServerContext;

  /** The backlog tool. */
  private readonly tool: BacklogTool;

  /** Decides the source (working tree or `main`) from the gate's inputs. */
  private readonly sourceOf: () => ReadRef;

  /** The current snapshot. */
  private current: Snapshot | null = null;

  /** A reload in flight (callers share it). */
  private loading: Promise<Snapshot> | null = null;

  /** True when a reload was requested while one was running. */
  private reloadAgain = false;

  /** The file watcher of `backlog/` (only while reading the working tree). */
  private watcher: FSWatcher | null = null;

  /** Debounce timer of file notifications. */
  private debounce: NodeJS.Timeout | null = null;

  /** Safety reload timer. */
  private safety: NodeJS.Timeout | null = null;

  /** True after {@link ReadModel.stop}: no further reloads are scheduled. */
  private stopped = false;

  /** The last read failure (the backlog cannot be read: degraded mode). */
  private failure: string | null = null;

  /**
   * Creates the read model.
   *
   * @param ctx - The server context.
   * @param tool - The backlog tool.
   * @param sourceOf - Returns where to read from now.
   */
  constructor(ctx: ServerContext, tool: BacklogTool, sourceOf: () => ReadRef) {
    this.ctx = ctx;
    this.tool = tool;
    this.sourceOf = sourceOf;
  }

  /** Starts the safety reloads and the watcher. */
  start(): void {
    this.safety = setInterval(() => this.invalidate(), SAFETY_MS);
    this.syncWatcher();
  }

  /** Stops timers and the watcher. */
  stop(): void {
    this.stopped = true;
    if (this.safety) clearInterval(this.safety);
    if (this.debounce) clearTimeout(this.debounce);
    this.watcher?.close();
    this.watcher = null;
  }

  /**
   * The last read failure, if the backlog could not be read.
   *
   * @returns The message or null.
   */
  get degraded(): string | null {
    return this.failure;
  }

  /**
   * The current snapshot, loading it first if there is none or the source changed.
   *
   * @returns The snapshot.
   */
  async snapshot(): Promise<Snapshot> {
    if (this.current && this.current.source === this.sourceOf()) return this.current;
    return this.reload();
  }

  /**
   * The snapshot already loaded, without waiting (null before the first load).
   *
   * @returns The snapshot or null.
   */
  peek(): Snapshot | null {
    return this.current;
  }

  /**
   * Resolves when no reload is running (at shutdown: a running tool process keeps its working
   * folder in use, which Windows does not let anyone delete).
   *
   * @returns Resolves when idle.
   */
  async idle(): Promise<void> {
    while (this.loading) await this.loading.catch(() => undefined);
  }

  /**
   * Loads anew now and resolves with a snapshot read after the call - for the end of the app's
   * own change, so its answer (and every read after it) already shows the change. Without it a
   * page that reloads the board on the answer gets the previous board and revision, and its next
   * change is refused as `changed-underneath` (found by the e2e test of Q11/Q12: undo, then
   * reorder at once).
   *
   * @returns The new snapshot.
   */
  async fresh(): Promise<Snapshot> {
    // The debounced reload this replaces would only repeat the work.
    if (this.debounce) clearTimeout(this.debounce);
    this.debounce = null;
    // A load in flight may have started before the change: wait for it, then load again.
    await this.idle();
    return this.reload();
  }

  /** Marks the data stale and reloads soon (after the debounce). */
  invalidate(): void {
    if (this.stopped) return;
    if (this.debounce) clearTimeout(this.debounce);
    this.debounce = setTimeout(() => {
      this.debounce = null;
      void this.reload().catch(() => undefined);
    }, DEBOUNCE_MS);
  }

  /**
   * Starts or stops the `backlog/` watcher to match the source: the working tree is watched only
   * while it is the source. During a run no handle is kept on the run's folders (analysis A2 §5.1).
   */
  syncWatcher(): void {
    const wanted = this.sourceOf() === "worktree";
    if (wanted && !this.watcher) {
      try {
        this.watcher = watch(join(this.ctx.repo.root, "backlog"), { recursive: true }, () =>
          this.invalidate(),
        );
        this.watcher.on("error", () => {
          // A lost watcher is recreated on the next sync; the safety reload covers the gap.
          this.watcher?.close();
          this.watcher = null;
        });
      } catch {
        this.watcher = null;
      }
    } else if (!wanted && this.watcher) {
      this.watcher.close();
      this.watcher = null;
    }
  }

  /**
   * Reloads now (coalescing concurrent requests) and publishes changes.
   *
   * @returns The new snapshot.
   */
  async reload(): Promise<Snapshot> {
    if (this.loading) {
      // The load in flight may have started before the change that asked for this reload: share
      // it now, and load once more when it ends. Many requests during one load cost one more load,
      // not one each. (Writes never depend on this snapshot: their revision check hashes the files.)
      this.reloadAgain = true;
      return this.loading;
    }
    this.loading = this.load().finally(() => {
      this.loading = null;
      if (this.reloadAgain) {
        this.reloadAgain = false;
        void this.reload().catch(() => undefined);
      }
    });
    return this.loading;
  }

  /**
   * Reads everything from the current source.
   *
   * @returns The snapshot.
   */
  private async load(): Promise<Snapshot> {
    const source = this.sourceOf();
    try {
      const [board, legend, next, check] = await Promise.all([
        this.tool.board(source, true),
        this.tool.legend(source),
        this.tool.next(source),
        // The check reads the working tree only; from `main` the last result stands.
        source === "worktree"
          ? this.tool.check()
          : Promise.resolve(this.current?.check ?? { total: 0, findings: [] }),
      ]);
      const previous = this.current;
      const snapshot: Snapshot = { source, board, legend, next, check, at: Date.now() };
      this.current = snapshot;
      this.failure = null;
      if (!previous || previous.board.revision !== board.revision || previous.source !== source) {
        this.ctx.hub.publish("board.changed", { board: board.revision, ref: source });
      }
      if (!previous || previous.check.total !== check.total) {
        this.ctx.hub.publish("check.changed", { total: check.total });
      }
      return snapshot;
    } catch (error) {
      // Degraded mode: keep showing the last good snapshot rather than an empty backlog; the write
      // gate is `degraded` (read-only) while `failure` is set.
      this.failure = error instanceof Error ? error.message : String(error);
      if (this.current) return this.current;
      throw error;
    }
  }
}
