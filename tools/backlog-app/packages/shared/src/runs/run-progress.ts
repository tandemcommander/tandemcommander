// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file How far a run is and when it will end (feature 415, research R5): fixed shares of the
 * implementation flow's phases, the task progress inside *implement*, the time spent in other
 * phases against their expected share, and the median duration of earlier closed runs blended with
 * the projection of the run's own pace. An estimate, always shown with its basis.
 */

import type { Phase } from "../schemas/runs.ts";
import { PHASE_ORDER } from "./run-state.ts";

/** The expected share of each phase of an implementation run (sums to 1). */
export const PHASE_WEIGHTS: Readonly<Partial<Record<Phase, number>>> = {
  selection: 0.02,
  measure: 0.08,
  specify: 0.05,
  clarify: 0.03,
  plan: 0.07,
  tasks: 0.03,
  analyze: 0.04,
  implement: 0.38,
  verify: 0.12,
  review: 0.12,
  close: 0.04,
  merge: 0.02,
};

/** Expected duration when fewer than three earlier runs are known: three hours. */
export const DEFAULT_EXPECTED_SECONDS = 3 * 3600;

/** What the estimate rests on. */
export interface ProgressInput {
  /** The current phase. */
  phase: Phase;
  /** `item` or `triage`. */
  kind: "item" | "triage";
  /** When the current phase began (epoch ms), or null. */
  phaseStartedMs: number | null;
  /** Task progress of `tasks.md`, or null. */
  tasks: { done: number; total: number } | null;
  /** Seconds since the run started. */
  elapsedSeconds: number;
  /** Median duration of earlier closed runs and how many (null median: too few). */
  history: { medianSeconds: number | null; count: number };
  /** Now (epoch ms). */
  nowMs: number;
}

/** The estimate. */
export interface ProgressEstimate {
  /** Fraction done, 0 - 1. */
  fraction: number;
  /** Fraction of the current phase done, 0 - 1. */
  phaseFraction: number;
  /** Seconds since the start. */
  elapsedSeconds: number;
  /** Expected total seconds. */
  expectedTotalSeconds: number;
  /** Expected remaining seconds (0 when done). */
  remainingSeconds: number;
  /** Expected end (epoch ms). */
  expectedEndMs: number;
  /** True when the run finished (done) or stopped. */
  finished: boolean;
  /** What the estimate rests on, in words. */
  basis: string;
}

/**
 * Sum of the weights of the phases before the given one.
 *
 * @param phase - A phase.
 * @returns The share already behind.
 */
function shareBefore(phase: Phase): number {
  const index = PHASE_ORDER.indexOf(phase);
  let sum = 0;
  for (const p of PHASE_ORDER.slice(0, Math.max(0, index))) sum += PHASE_WEIGHTS[p] ?? 0;
  return sum;
}

/**
 * Estimates the progress of a run.
 *
 * @param input - Phase, tasks, times and history.
 * @returns The estimate.
 */
export function estimateProgress(input: ProgressInput): ProgressEstimate {
  const elapsed = Math.max(0, input.elapsedSeconds);
  const median = input.history.medianSeconds;
  const expectedBase = median && input.history.count >= 3 ? median : DEFAULT_EXPECTED_SECONDS;
  const basisHistory =
    median && input.history.count >= 3
      ? `median of ${input.history.count} closed runs`
      : "default of 3 h (fewer than 3 closed runs known)";
  if (input.phase === "done" || input.phase === "stopped") {
    return {
      fraction: input.phase === "done" ? 1 : shareBefore("close"),
      phaseFraction: 1,
      elapsedSeconds: elapsed,
      expectedTotalSeconds: elapsed,
      remainingSeconds: 0,
      expectedEndMs: input.nowMs,
      finished: true,
      basis: input.phase === "done" ? "finished" : "stopped",
    };
  }
  if (input.kind === "triage") {
    // A triage has no phases to weigh: time against a fixed 15 minutes.
    const total = Math.max(900, elapsed * 1.05);
    const fraction = Math.min(0.95, elapsed / total);
    return {
      fraction,
      phaseFraction: fraction,
      elapsedSeconds: elapsed,
      expectedTotalSeconds: total,
      remainingSeconds: Math.max(0, total - elapsed),
      expectedEndMs: input.nowMs + Math.max(0, total - elapsed) * 1000,
      finished: false,
      basis: "a triage takes about 15 min",
    };
  }
  const weight = PHASE_WEIGHTS[input.phase] ?? 0;
  const before = shareBefore(input.phase);
  let phaseFraction = 0;
  let basis = basisHistory;
  if (input.phase === "implement" && input.tasks && input.tasks.total > 0) {
    phaseFraction = Math.min(1, input.tasks.done / input.tasks.total);
    basis = `${basisHistory}; tasks ${input.tasks.done}/${input.tasks.total}`;
  } else if (weight > 0 && input.phaseStartedMs !== null) {
    const inPhase = Math.max(0, (input.nowMs - input.phaseStartedMs) / 1000);
    phaseFraction = Math.min(0.9, inPhase / Math.max(60, expectedBase * weight));
  }
  const fraction = Math.min(0.99, before + weight * phaseFraction);
  // The run's own pace counts more the further it is.
  let expectedTotal = expectedBase;
  if (fraction >= 0.05 && elapsed > 0) {
    const projected = elapsed / fraction;
    const w = Math.min(1, fraction * 1.5);
    expectedTotal = (1 - w) * expectedBase + w * projected;
    basis = `${basis}; own pace`;
  }
  expectedTotal = Math.max(expectedTotal, elapsed * 1.02 + 60);
  const remaining = Math.max(0, expectedTotal - elapsed);
  return {
    fraction,
    phaseFraction,
    elapsedSeconds: elapsed,
    expectedTotalSeconds: expectedTotal,
    remainingSeconds: remaining,
    expectedEndMs: input.nowMs + remaining * 1000,
    finished: false,
    basis,
  };
}
