// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The write gate: whether the backlog may be changed now, how, and why not (research R9 of
 * 344; redefined by feature 371, data-model *Write gate*; FR-001 - FR-006 of 371).
 *
 * Since 371 a live loop and a run in progress no longer close the gate: a change made while a run
 * holds the run lock lands on `main` through the app's side worktree (channel `main-ref`), a
 * change made while a loop lives is committed at once (channel `commit`), and only without a loop
 * does a change wait in the tray (channel `tray`). The two windows in which a run itself is on
 * `main` - its start until it has its branch, and its return - are read-only: the loop holds the
 * app's edit lock then (`run-starting`), or, for a run outside the loop, the primary working
 * tree's HEAD is `main` while the run lock is held (`run-on-main`). The item a run works on is
 * frozen (`frozenSlug`). The gate is computed from the loop view and the repository state; the
 * write queue evaluates it again under the edit lock immediately before every change.
 */

import type { GateState, LoopView, WriteChannel, WriteGate } from "@backlog-app/shared";
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

/**
 * Computes the write gate (pure; the decision table of data-model.md, first match wins).
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
   * @param channel - How a change is applied (only in `free`).
   * @param frozenSlug - The item a run works on.
   * @returns The gate.
   */
  const gate = (
    state: GateState,
    reason: string,
    channel: WriteChannel | null = null,
    frozenSlug: string | null = null,
  ): WriteGate => ({
    state,
    writable: state === "free",
    channel: state === "free" ? channel : null,
    frozenSlug,
    reason,
    checkClean: checkTotal === 0,
    branch,
    headIsMain,
    dirtyOutsideBacklog,
  });

  // 1-2: nothing is known, or the backlog cannot be read.
  if (!loop || !repo) return gate("degraded", "starting up - reading the loop and the repository");
  if (degraded)
    return gate("degraded", "the backlog cannot be read; it is shown read-only (see the Check page)");
  // 3: a merge in the working tree.
  if (repo.merging) {
    return gate(
      "merge-in-progress",
      "a merge is in progress - finish it in the terminal (keep both rows, sync, check)",
    );
  }
  // 4: a stale run lock with no live loop (the release dialog).
  if (loop.lock?.stale && !loop.live) {
    return gate(
      "stale-lock",
      `a stale run lock of ${loop.lock.slug} (since ${loop.lock.started}) - release it only if no run is alive`,
    );
  }
  const frozen = loop.lock?.slug ?? null;
  // 5-6: a live edit lock of another process (the app's own does not close its own gate).
  if (loop.editLock && loop.editLock.pid !== process.pid) {
    if (loop.live && loop.editLock.pid === loop.pid) {
      return gate(
        "run-starting",
        frozen
          ? `read-only for a moment: the run of ${frozen} is on main (${loop.editLock.purpose.replace(/^loop: /, "")}); changes open again once it is on its branch`
          : `read-only for a moment: the loop is starting a run (${loop.editLock.purpose.replace(/^loop: /, "")}); changes open again once the run is on its branch`,
        null,
        frozen,
      );
    }
    return gate(
      "edit-in-progress",
      `another backlog app (pid ${loop.editLock.pid}) is changing the backlog: ${loop.editLock.purpose}`,
    );
  }
  // 7-8: a run holds the run lock.
  if (loop.lock) {
    if (headIsMain) {
      return gate(
        "run-on-main",
        `read-only for a moment: the run of ${loop.lock.slug} is on main (its start or its end); changes open again once it is on its branch`,
        null,
        frozen,
      );
    }
    return gate(
      "free",
      "",
      "main-ref",
      frozen,
    );
  }
  // 9: the loop's own auto-triage, or a hard stop being handled.
  if (loop.shown === "triage" || loop.shown === "kill-pending") {
    return gate("auto-triage", "read-only while the loop's current step finishes");
  }
  // 10: the maintainer's own branch.
  if (!headIsMain) {
    return gate(
      "not-on-main",
      `the working tree is on ${branch}; backlog changes are made on main (switch in the terminal)`,
    );
  }
  // 11: an interrupted run without a lock waits to be continued: its item stays frozen.
  if (loop.interruptedRun && !loop.interruptedRun.needsPerson && loop.interruptedRun.phase !== "new") {
    return gate("free", "", loop.live ? "commit" : "tray", loop.interruptedRun.slug);
  }
  // 12-13: a live loop commits at once; otherwise the tray.
  return gate("free", "", loop.live ? "commit" : "tray");
}
