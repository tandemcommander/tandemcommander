// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The write queue: every change of the backlog, one at a time, under the edit lock and
 * behind a fresh evaluation of the write gate (research R9, R12 of 344; the channels of feature
 * 371, research R1-R5; FR-023, FR-024 of 344, FR-001 - FR-005 of 371).
 *
 * Order of one operation:
 * 1. wait for the previous operation (the tool takes no lock of its own: two changing commands at
 *    once can lose rows, analysis A1 §3);
 * 2. take the edit lock - from now on a resumed loop waits; a lock the loop holds (a run starts or
 *    returns to `main`) is waited for up to 30 s;
 * 3. refresh the loop and repository state and evaluate the gate again; closed = refused; the
 *    gate names the channel: `tray` (the primary tree, pending), `commit` (the primary tree,
 *    committed at once), `main-ref` (the side worktree of `main`, committed and landed on `main`);
 * 4. compare the revisions the user's view was based on with the files of the channel's tree
 *    (`changed-underneath`);
 * 5. run the operation (the tool), stage its changes;
 * 6. per channel: record in the tray / commit the tray / verify (findings, the frozen item),
 *    commit in the worktree, check the primary HEAD, land on `main`;
 * 7. release the lock, reload the read model, publish the gate.
 */

import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { ApiError, type Change, type Finding, type WriteChannel, type WriteGate } from "@backlog-app/shared";
import type { Services } from "../services.ts";
import { EditLock } from "./edit-lock.ts";
import { SideWorktree } from "./side-worktree.ts";
import { ChangeTray, type Snapshot } from "./tray.ts";

/** The revisions a view was based on. */
export interface Base {
  /** SHA-256 of `BACKLOG.md`. */
  board?: string | undefined;
  /** SHA-256 of the item's `desc.md`. */
  item?: string | undefined;
}

/** How long the queue waits for an edit lock the loop holds before refusing. */
const LOOP_LOCK_WAIT_MS = 30_000;

/** Milliseconds between attempts to take a loop-held lock. */
const LOOP_LOCK_RETRY_MS = 500;

/**
 * The SHA-256 of a file's bytes (open-read-close), or null when it does not exist.
 *
 * @param path - The file.
 * @returns The hex digest or null.
 */
export function fileHash(path: string): string | null {
  try {
    return createHash("sha256").update(readFileSync(path)).digest("hex");
  } catch {
    return null;
  }
}

/** A change an operation staged (recorded in the tray once the queue knows the outcome). */
export interface StagedChange {
  /** The operation. */
  operation: Change["operation"];
  /** The items it concerned. */
  slugs: string[];
  /** One line for the tray and the commit message. */
  summary: string;
  /** The maintainer's reason. */
  reason: string | null;
  /** The snapshot taken before the operation. */
  before: Snapshot;
  /** Files the tool wrote or deleted (repository-relative). */
  written: string[];
  /** Check findings the tool reported with the change. */
  findings: Finding[];
  /** The tray entry, filled in by the queue once the change is recorded. */
  change: Change | null;
}

/** What an operation gets from the queue. */
export interface WriteContext {
  /** The channel the gate chose. */
  channel: WriteChannel;
  /** The tree the operation acts on (`--root` of the tool). */
  root: string;
  /** The item a run works on (never changed), or null. */
  frozenSlug: string | null;
  /** The gate as evaluated under the lock. */
  gate: WriteGate;
  /**
   * Stages a change for the tray; returns the entry object, whose `change` the queue fills in
   * (state, commit, channel) before the operation's answer leaves the queue.
   *
   * @param input - The change.
   * @returns The staged entry.
   */
  stage: (input: Omit<StagedChange, "change">) => StagedChange;
  /**
   * The SHA-256 of a file of the channel's tree (for the revisions of the answer).
   *
   * @param relative - Path relative to the tree, `/`-separated.
   * @returns The hex digest or null.
   */
  hashOf: (relative: string) => string | null;
}

/** Options of {@link WriteQueue.run}. */
export interface RunOptions {
  /** The channels the operation may run in (default: every channel). */
  channels?: WriteChannel[];
}

/** The serial queue of changes. */
export class WriteQueue {
  /** The server's services. */
  private readonly services: Services;

  /** The edit lock. */
  readonly lock: EditLock;

  /** The side worktree of `main` (feature 371). */
  readonly worktree: SideWorktree;

  /** The end of the queue (the last operation's promise). */
  private tail: Promise<unknown> = Promise.resolve();

  /**
   * Creates the queue.
   *
   * @param services - The server's services.
   */
  constructor(services: Services) {
    this.services = services;
    this.lock = new EditLock(services.ctx.repo.commonDir);
    this.worktree = new SideWorktree(services.ctx);
  }

  /**
   * Resolves when every queued operation has finished.
   *
   * @returns Resolves when idle.
   */
  async idle(): Promise<void> {
    let tail = this.tail;
    for (;;) {
      await tail;
      if (tail === this.tail) return;
      tail = this.tail;
    }
  }

  /**
   * Runs one operation in the queue.
   *
   * @param purpose - What it changes (written into the edit lock).
   * @param base - The revisions the view was based on, or null for operations without a view.
   * @param slug - The item whose revision `base.item` refers to.
   * @param operation - The change itself.
   * @param options - Allowed channels.
   * @returns The operation's result.
   */
  run<T>(
    purpose: string,
    base: Base | null,
    slug: string | null,
    operation: (ctx: WriteContext) => Promise<T>,
    options: RunOptions = {},
  ): Promise<T> {
    const next = this.tail.then(
      () => this.execute(purpose, base, slug, operation, options),
      () => this.execute(purpose, base, slug, operation, options),
    );
    // Keep the chain alive after a failure.
    this.tail = next.catch(() => undefined);
    return next;
  }

  /**
   * Takes the edit lock, waiting while the loop holds it (a run starts or returns to `main`).
   *
   * @param purpose - What the app changes.
   * @throws ApiError `busy` when the loop still holds it after the wait, or another app holds it.
   */
  private async acquire(purpose: string): Promise<void> {
    const loopPid = this.services.loop.view?.live ? this.services.loop.view.pid : null;
    const until = Date.now() + LOOP_LOCK_WAIT_MS;
    for (;;) {
      try {
        this.lock.acquire(purpose, loopPid);
        return;
      } catch (error) {
        const held = this.lock.holder();
        if (
          !(error instanceof ApiError && error.code === "busy") ||
          loopPid === null ||
          held?.pid !== loopPid ||
          Date.now() >= until
        ) {
          throw error;
        }
        await new Promise((resolve) => setTimeout(resolve, LOOP_LOCK_RETRY_MS));
      }
    }
  }

  /**
   * One operation (see the file overview for the order).
   *
   * @param purpose - What it changes.
   * @param base - The view's revisions.
   * @param slug - The item of `base.item`.
   * @param operation - The change.
   * @param options - Allowed channels.
   * @returns The operation's result.
   */
  private async execute<T>(
    purpose: string,
    base: Base | null,
    slug: string | null,
    operation: (ctx: WriteContext) => Promise<T>,
    options: RunOptions,
  ): Promise<T> {
    await this.acquire(purpose);
    try {
      await Promise.all([this.services.loop.fresh(), this.services.repo.fresh()]);
      const gate = this.services.gate();
      if (!gate.writable || !gate.channel) throw new ApiError("gate-closed", gate.reason, gate);
      const channel = gate.channel;
      if (options.channels && !options.channels.includes(channel)) {
        throw new ApiError(
          "gate-closed",
          channel === "main-ref"
            ? "not while a run is in progress: the working tree belongs to the run"
            : `not in this state (${gate.state})`,
          gate,
        );
      }
      const mainCommit = this.services.repo.state?.mainCommit ?? null;
      if (channel === "main-ref") {
        if (!mainCommit) throw new ApiError("gate-closed", "main has no commit", gate);
        await this.worktree.sync(mainCommit);
      }
      const root = channel === "main-ref" ? this.worktree.path : this.services.ctx.repo.root;
      /**
       * The hash of a file of the channel's tree.
       *
       * @param relative - Repository-relative path.
       * @returns The hex digest or null.
       */
      const hashOf = (relative: string): string | null => fileHash(join(root, ...relative.split("/")));
      if (base?.board) {
        const now = hashOf("backlog/BACKLOG.md");
        if (now !== base.board) {
          throw new ApiError(
            "changed-underneath",
            "the backlog changed since this view was loaded - it was reloaded",
            { board: now },
          );
        }
      }
      if (base?.item && slug) {
        const now = hashOf(`backlog/items/${slug}/desc.md`);
        if (now !== base.item) {
          throw new ApiError(
            "changed-underneath",
            "this item changed since it was loaded - it was reloaded",
            { item: now },
          );
        }
      }
      const frozen = gate.frozenSlug;
      const frozenPath = frozen ? `backlog/items/${frozen}/desc.md` : null;
      const frozenBefore = frozenPath ? hashOf(frozenPath) : null;
      const staged: StagedChange[] = [];
      const ctx: WriteContext = {
        channel,
        root,
        frozenSlug: frozen,
        gate,
        stage: (input) => {
          const entry: StagedChange = { ...input, change: null };
          staged.push(entry);
          return entry;
        },
        hashOf,
      };
      let result: T;
      try {
        result = await operation(ctx);
      } catch (error) {
        if (channel === "main-ref") await this.worktree.revert();
        throw error;
      }
      if (channel === "tray") {
        this.recordStaged(staged, root, "tray", null);
        return result;
      }
      // Committing channels: a change that leaves check findings is never committed - a backlog
      // with findings would hold the loop and could not be merged by the run's recipe.
      const findings = staged.flatMap((s) => s.findings);
      if (findings.length > 0) {
        await this.discard(staged, channel, root);
        throw new ApiError("check-findings", "the change would leave check findings - nothing was changed", {
          findings,
        });
      }
      // The frozen item (the run's) must not change, also not through another item's lists.
      if (frozenPath && hashOf(frozenPath) !== frozenBefore) {
        await this.discard(staged, channel, root);
        throw new ApiError(
          "frozen-item",
          `the change would alter ${frozen}, which a run works on - nothing was changed`,
        );
      }
      if (channel === "commit") {
        const recorded = this.recordStaged(staged, root, "commit", null);
        const message = this.services.tray.proposedMessage();
        const hash = await this.services.tray.commit(message, []);
        this.services.tray.markChannel(
          recorded.map((c) => c.id),
          "commit",
        );
        for (const entry of staged) {
          if (entry.change) {
            entry.change.state = "committed";
            entry.change.commit = hash;
            entry.change.channel = "commit";
          }
        }
        return result;
      }
      // main-ref: commit in the worktree, make sure the primary tree is not on main, land.
      const paths = [...new Set(staged.flatMap((s) => s.written))];
      if (paths.length === 0) {
        await this.worktree.revert();
        return result;
      }
      const message = ChangeTray.messageFor(staged);
      const hash = await this.worktree.commit(paths, message);
      const head = await this.worktree.primaryHead();
      if (head === "refs/heads/main" || !this.lock.holds()) {
        await this.worktree.revert();
        throw new ApiError(
          "gate-closed",
          "the run moved to main at this moment (its start or its end) - try again in a minute",
          gate,
        );
      }
      if (!(await this.worktree.landOnMain(hash, mainCommit!))) {
        await this.worktree.revert();
        throw new ApiError(
          "changed-underneath",
          "main moved while the change was being applied (the run's return) - the view was reloaded",
          { board: null },
        );
      }
      this.recordStaged(staged, root, "main-ref", hash);
      return result;
    } finally {
      // The lock goes first (the loop must not wait for our reading); then the answer waits until
      // the read model shows the change, so the page's next reads are not stale.
      this.lock.release();
      await this.services.repo.refresh();
      await this.services.read.fresh().catch(() => undefined);
      this.services.publishGate();
    }
  }

  /**
   * Records staged changes in the tray.
   *
   * @param staged - The changes.
   * @param root - The tree they ran in.
   * @param channel - Their channel.
   * @param commit - The commit, when committed at once.
   * @returns The tray entries.
   */
  private recordStaged(
    staged: StagedChange[],
    root: string,
    channel: WriteChannel,
    commit: string | null,
  ): Change[] {
    const recorded: Change[] = [];
    for (const entry of staged) {
      const change = this.services.tray.record({
        operation: entry.operation,
        slugs: entry.slugs,
        summary: entry.summary,
        reason: entry.reason,
        before: entry.before,
        written: entry.written,
        root,
        channel,
        ...(commit ? { commit } : {}),
      });
      entry.change = change;
      recorded.push(change);
    }
    return recorded;
  }

  /**
   * Discards what staged changes wrote: the side worktree is reverted; in the primary tree the
   * files are restored from the snapshots, newest change first.
   *
   * @param staged - The changes.
   * @param channel - The channel.
   * @param root - The tree.
   */
  private async discard(staged: StagedChange[], channel: WriteChannel, root: string): Promise<void> {
    if (channel === "main-ref") {
      await this.worktree.revert();
      return;
    }
    // The commit channel in the primary tree: record and undo, so the tray's own checks apply.
    const recorded = this.recordStaged(staged, root, "commit", null);
    for (const change of recorded.reverse()) {
      try {
        this.services.tray.undo(change.id);
      } catch {
        // A file changed by something else meanwhile stays as it is; the tray shows it pending.
      }
    }
  }
}
