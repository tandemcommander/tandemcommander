// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The write gate: whether the backlog may be changed now, and why not (research R9,
 * analysis A4 §4.1; FR-023).
 *
 * The rules come from the skills and the loop (analysis A1 §6.3): changes are made only on `main`,
 * never while a run holds the run lock (the run is on its feature branch and a change would land
 * in its commit or break its fast-forward), never while the loop runs unpaused (it may start a run
 * at any second) or runs its auto-triage, and never during a merge. The gate is computed here from
 * the loop view and the repository state; the write queue evaluates it again under the edit lock
 * immediately before every change.
 */

import type { GateState, LoopView, WriteGate } from "@backlog-app/shared";
import type { RepoState } from "../repo/monitor.ts";

/** What the gate is computed from. */
export interface GateInputs {
  /** The loop view (null before the first poll: treated as unknown = closed). */
  loop: LoopView | null;
  /** The repository state (null before the first poll). */
  repo: RepoState | null;
  /** The backlog could not be read (malformed overview, conflict markers). */
  degraded: boolean;
  /** Number of check findings. */
  checkTotal: number;
}

/** The loop states in which the loop is between runs and could start one at any moment. */
const LOOP_BETWEEN_RUNS: ReadonlySet<string> = new Set([
  "starting",
  "waiting",
  "idle",
  "limit",
  "backoff",
  "running",
]);

/**
 * Computes the write gate (pure).
 *
 * @param inputs - Loop view, repository state, read health, check result.
 * @returns The gate.
 */
export function computeGate(inputs: GateInputs): WriteGate {
  const { loop, repo, degraded, checkTotal } = inputs;
  const branch = repo?.branch ?? "?";
  const headIsMain = branch === "main";
  const dirtyOutsideBacklog = (repo?.dirty ?? [])
    .map((entry) => entry.path)
    .filter((path) => !path.startsWith("backlog/"));

  /**
   * Builds the answer for a state.
   *
   * @param state - The gate state.
   * @param reason - Why (shown at every disabled control).
   * @returns The gate.
   */
  const gate = (state: GateState, reason: string): WriteGate => ({
    state,
    writable: state === "free",
    reason,
    checkClean: checkTotal === 0,
    branch,
    headIsMain,
    dirtyOutsideBacklog,
  });

  if (!loop || !repo) return gate("degraded", "starting up - reading the loop and the repository");
  if (degraded)
    return gate("degraded", "the backlog cannot be read; it is shown read-only (see the Check page)");
  if (repo.merging) {
    return gate(
      "merge-in-progress",
      "a merge is in progress - finish it in the terminal (keep both rows, sync, check)",
    );
  }
  if (loop.lock) {
    if (loop.lock.stale && !loop.live) {
      return gate(
        "stale-lock",
        `a stale run lock of ${loop.lock.slug} (since ${loop.lock.started}) - release it only if no run is alive`,
      );
    }
    return gate(
      "run-holds-lock",
      `read-only: a run of ${loop.lock.slug} holds the lock (branch ${loop.lock.branch}); the board shows main`,
    );
  }
  if (
    loop.shown === "triage" ||
    loop.shown === "pause-pending" ||
    loop.shown === "stop-pending" ||
    loop.shown === "kill-pending"
  ) {
    return gate("auto-triage", "read-only while the loop's current step finishes");
  }
  if (!headIsMain) {
    return gate(
      "not-on-main",
      `the working tree is on ${branch}; backlog changes are made on main (switch in the terminal)`,
    );
  }
  // The app's own edit lock (held during its own change) does not close its own gate.
  if (loop.editLock && loop.editLock.pid !== process.pid) {
    return gate(
      "edit-in-progress",
      `another backlog app (pid ${loop.editLock.pid}) is changing the backlog: ${loop.editLock.purpose}`,
    );
  }
  if (loop.live && LOOP_BETWEEN_RUNS.has(loop.shown)) {
    return gate(
      "loop-between-runs",
      "the loop runs and may start a run any second - pause it to change the backlog",
    );
  }
  if (loop.interruptedRun && !loop.interruptedRun.needsPerson && loop.interruptedRun.phase !== "new") {
    // An interrupted run is continued by the next start on its own branch; the item it works on
    // must not change meanwhile. Its lock is held, so this is normally covered above.
    return gate("run-holds-lock", `an interrupted run of ${loop.interruptedRun.slug} waits to be continued`);
  }
  return gate("free", "");
}
