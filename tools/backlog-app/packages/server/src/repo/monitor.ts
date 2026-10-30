// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Watches the repository's state the write gate and the read model depend on: the branch
 * of the working tree, the commit of `main`, a merge in progress, and the dirty paths
 * (research R9, R10).
 *
 * Everything is read with lock-free git commands every three seconds (`git status` with optional
 * locks off), so a run that checks out, commits or merges at the same moment is never disturbed.
 */

import { currentBranch, mergeInProgress, resolveRef, statusEntries, type StatusEntry } from "./git.ts";
import type { ServerContext } from "../context.ts";

/** The repository state at one moment. */
export interface RepoState {
  /** The working tree's branch (`HEAD` when detached). */
  branch: string;
  /** The commit `main` points to. */
  mainCommit: string | null;
  /** A merge is in progress. */
  merging: boolean;
  /** The dirty paths of the working tree. */
  dirty: StatusEntry[];
}

/** Milliseconds between polls. */
const POLL_MS = 3000;

/** A listener of state changes. */
export type RepoListener = (state: RepoState, previous: RepoState | null) => void;

/** The poller of the repository state. */
export class RepoMonitor {
  /** The server context. */
  private readonly ctx: ServerContext;

  /** The latest state. */
  private current: RepoState | null = null;

  /** The poll timer. */
  private timer: NodeJS.Timeout | null = null;

  /** A poll in flight (polls never overlap; callers share it). */
  private inFlight: Promise<RepoState | null> | null = null;

  /** Listeners of changes. */
  private readonly listeners = new Set<RepoListener>();

  /** True after {@link RepoMonitor.stop}: no further polls. */
  private stopped = false;

  /**
   * Creates the monitor.
   *
   * @param ctx - The server context.
   */
  constructor(ctx: ServerContext) {
    this.ctx = ctx;
  }

  /** Starts polling. */
  start(): void {
    void this.refresh();
    this.timer = setInterval(() => void this.refresh(), POLL_MS);
  }

  /** Stops polling. */
  stop(): void {
    this.stopped = true;
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  /**
   * The latest state.
   *
   * @returns The state, or null before the first poll.
   */
  get state(): RepoState | null {
    return this.current;
  }

  /**
   * Subscribes to changes.
   *
   * @param listener - Called with the new and the previous state.
   * @returns The unsubscribe function.
   */
  onChange(listener: RepoListener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  /**
   * Polls now (also right after the app committed, so the gate reflects it at once).
   *
   * @returns The new state, or the previous one when git failed.
   */
  refresh(): Promise<RepoState | null> {
    if (this.stopped) return Promise.resolve(this.current);
    this.inFlight ??= this.poll().finally(() => {
      this.inFlight = null;
    });
    return this.inFlight;
  }

  /**
   * A state read entirely after this call (for the write gate after the edit lock was taken; a
   * shared poll in flight may predate the lock - see `LoopMonitor.fresh`).
   *
   * @returns The state of a poll started after the call.
   */
  async fresh(): Promise<RepoState | null> {
    await this.idle();
    return this.refresh();
  }

  /**
   * Resolves when no poll is running.
   *
   * @returns Resolves when idle.
   */
  async idle(): Promise<void> {
    while (this.inFlight) await this.inFlight;
  }

  /**
   * Reads the state once and tells the listeners about a change.
   *
   * @returns The state.
   */
  private async poll(): Promise<RepoState | null> {
    try {
      const root = this.ctx.repo.root;
      const [branch, mainCommit, dirty] = await Promise.all([
        currentBranch(root),
        resolveRef(root, "main"),
        statusEntries(root),
      ]);
      const state: RepoState = { branch, mainCommit, merging: mergeInProgress(this.ctx.repo), dirty };
      const previous = this.current;
      this.current = state;
      if (previous === null || JSON.stringify(previous) !== JSON.stringify(state)) {
        for (const listener of this.listeners) listener(state, previous);
      }
      return state;
    } catch {
      return this.current;
    }
  }
}
