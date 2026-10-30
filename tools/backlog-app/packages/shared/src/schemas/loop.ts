// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Schemas of the backlog loop as the application shows it (data-model.md, *Loop view*).
 *
 * The loop (`tools/backlog/loop.py`, feature 247) owns its state files in
 * `.git/tandem-backlog-loop/`; the server reads them and `loop.py status --json` and derives one
 * `shown` state in words (analysis A2 §1.2). The application never writes these files: it
 * controls the loop only through the loop's own commands (research R13).
 */

import { z } from "zod";

/**
 * The state shown to the maintainer. The first eight are the loop's own `state` values; the rest
 * are derived from flags, liveness and the run record.
 */
export const LOOP_SHOWN_STATES = [
  "not-running",
  "starting",
  "running",
  "triage",
  "waiting",
  "idle",
  "paused",
  "limit",
  "backoff",
  "pause-pending",
  "stop-pending",
  "kill-pending",
  "dead",
  "run-outside-loop",
  "stopped-for-person",
] as const;

/** One shown loop state. */
export const LoopShownSchema = z.enum(LOOP_SHOWN_STATES);

/** A shown loop state. */
export type LoopShown = z.infer<typeof LoopShownSchema>;

/** The last usage-limit information the loop saw (`rate_limit_info` of claude). */
export const UsageSchema = z.object({
  /** `allowed`, `allowed_warning` or `rejected` (claude waits for the limit). */
  status: z.string().nullable(),
  /** When the current limit window resets (ISO time), if known. */
  resetsAt: z.string().nullable(),
  /** Utilisation 0-1 of the five-hour window, if reported. */
  fiveHour: z.number().nullable(),
  /** Utilisation 0-1 of the seven-day window, if reported. */
  sevenDay: z.number().nullable(),
});

/** The run lock (`.git/tandem-backlog-run.lock`) as read. */
export const RunLockSchema = z.object({
  /** The item the run holds the lock for (`-` before selection). */
  slug: z.string(),
  /** The run's feature branch (`-` until the run created it). */
  branch: z.string(),
  /** When the lock was taken (local time). */
  started: z.string(),
  /** Host name of the machine that took it. */
  host: z.string(),
  /** True when the lock is older than 24 hours. */
  stale: z.boolean(),
});

/** The run lock. */
export type RunLock = z.infer<typeof RunLockSchema>;

/** A run that is not finished while no live loop runs it (`run.json` without a loop). */
export const InterruptedRunSchema = z.object({
  /** The item. */
  slug: z.string(),
  /** The run's phase in the loop's terms (`running`, `killed`, `waiting`, `failed`, `lost`, `new`). */
  phase: z.string(),
  /** Why it stopped, in the loop's words. */
  why: z.string().nullable(),
  /** When the next start may continue it (ISO time), for a waiting run. */
  waitUntil: z.string().nullable(),
  /** True when the run needs a person (`failed` / `lost`): continuing is not automatic. */
  needsPerson: z.boolean(),
});

/** How and why the last loop ended (`last.json`, feature 344). */
export const LoopEndSchema = z.object({
  /** When it ended (local time). */
  ended: z.string(),
  /** The process exit code. */
  exitCode: z.number().int().nullable(),
  /** The loop's reason (`stop`, `max-items`, `until-idle`, `hard-stop`, ...). */
  reason: z.string(),
});

/** The loop's state as shown everywhere in the application. */
export const LoopViewSchema = z.object({
  /** The state in one word (see {@link LOOP_SHOWN_STATES}). */
  shown: LoopShownSchema,
  /** The loop's own description of what it does (`loop.json` `detail`), or a derived sentence. */
  detail: z.string(),
  /** End of a usage-limit or backoff wait (ISO time), if any. */
  until: z.string().nullable(),
  /** True when the loop process is alive (the loop's own identity check). */
  live: z.boolean(),
  /** Seconds since the loop last wrote its heartbeat, or null without a loop record. */
  heartbeatAge: z.number().nullable(),
  /** Process id of the loop, if there is a loop record. */
  pid: z.number().int().nullable(),
  /** When the loop started (local time). */
  started: z.string().nullable(),
  /** The item the loop works on now, if any. */
  slug: z.string().nullable(),
  /** The folder of the current trace (`.agent-traces/<dir>`), if any. */
  trace: z.string().nullable(),
  /** Finished runs of this loop by outcome. */
  counts: z.record(z.string(), z.number().int()),
  /** Number of `blocked` outcomes in a row. */
  blockedStreak: z.number().int(),
  /** Usage-limit figures, if the loop saw any. */
  usage: UsageSchema.nullable(),
  /** True when a Ctrl+C in the loop's window would not kill a running item. */
  ctrlCSafe: z.boolean(),
  /** The pending control flags. */
  flags: z.object({
    /** A pause is set (the item finishes, then the loop waits). */
    pause: z.boolean(),
    /** A stop is set (the item finishes, then the loop ends). */
    stop: z.boolean(),
    /** A hard stop is requested and not yet handled. */
    kill: z.boolean(),
  }),
  /** The run lock, or null when free. */
  lock: RunLockSchema.nullable(),
  /** A run waiting to be continued, or null. */
  interruptedRun: InterruptedRunSchema.nullable(),
  /** True when the claude of a dead loop is still working. */
  orphanClaude: z.boolean(),
  /** Total size of `.agent-traces/` in bytes. */
  tracesBytes: z.number().int(),
  /** How the last loop ended, if recorded. */
  lastEnd: LoopEndSchema.nullable(),
  /** The holder of the app's edit lock, if one is live. */
  editLock: z.object({ pid: z.number().int(), started: z.string(), purpose: z.string() }).nullable(),
  /** The options of `start` the loop was started with, as far as known. */
  autoTriage: z.boolean(),
});

/** The loop view. */
export type LoopView = z.infer<typeof LoopViewSchema>;

/** The options of `loop.py start` the application offers (research R13). */
export const LoopStartOptionsSchema = z.object({
  /** End after this many finished runs (0 = no limit). */
  maxItems: z.number().int().min(0).max(1000).optional(),
  /** Stop after this many `blocked` runs in a row. */
  maxBlocked: z.number().int().min(1).max(100).optional(),
  /** Seconds between looks at the backlog while waiting. */
  poll: z.number().int().min(5).max(3600).optional(),
  /** Model of the runs (`--model`); letters, digits, dots, dashes and brackets only. */
  model: z
    .string()
    .regex(/^[A-Za-z0-9._\-[\]]{1,64}$/)
    .optional(),
  /** End when nothing is eligible instead of waiting. */
  untilIdle: z.boolean().optional(),
  /** Run the auto-triage before runs when the Inbox has new items. */
  autoTriage: z.boolean().optional(),
  /** Drop the record of an interrupted run first (after a person cleaned up). */
  forgetRun: z.boolean().optional(),
  /** Commit the change tray before starting (research R11). */
  commitTray: z.boolean().optional(),
});

/** Options of a loop start. */
export type LoopStartOptions = z.infer<typeof LoopStartOptionsSchema>;
