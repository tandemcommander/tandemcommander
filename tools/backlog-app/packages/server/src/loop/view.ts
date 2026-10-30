// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The loop view: what the backlog loop does, derived from `loop.py status --json`
 * (data-model *Loop view*; analysis A2 §1.2).
 *
 * The server never reads or writes the loop's state files itself: `status --json` reads them with
 * the loop's own retries on Windows sharing errors and checks process identity (pid + creation
 * time), which Node cannot do. A file the loop replaces atomically is therefore never held open by
 * this process (analysis A2 §5.1, measured WinError 5). The monitor polls every two seconds and
 * publishes a change only when the derived view changed.
 */

import { z } from "zod";
import type { LoopShown, LoopView } from "@backlog-app/shared";

/** The part of a `loop.json` record the view uses (the loop writes more). */
const RawLoopSchema = z.looseObject({
  pid: z.number().optional(),
  started: z.string().optional(),
  state: z.string().optional(),
  detail: z.string().nullable().optional(),
  until: z.string().nullable().optional(),
  ctrl_c_safe: z.boolean().nullable().optional(),
  updated: z.string().optional(),
  slug: z.string().nullable().optional(),
  trace: z.string().nullable().optional(),
  counts: z.record(z.string(), z.number()).optional(),
  blocked_streak: z.number().optional(),
  usage: z.record(z.string(), z.unknown()).nullable().optional(),
  auto_triage: z.boolean().optional(),
});

/** The part of a `run.json` record the view uses. */
const RawRunSchema = z.looseObject({
  slug: z.string(),
  session: z.string().optional(),
  phase: z.string().optional(),
  why: z.string().nullable().optional(),
  wait_until: z.number().nullable().optional(),
  trace: z.string().nullable().optional(),
  base: z.string().nullable().optional(),
  started: z.string().optional(),
  started_epoch: z.number().optional(),
});

/** The output of `loop.py status --json` (feature 247, extended by 342 and 344). */
export const RawStatusSchema = z.looseObject({
  loop: RawLoopSchema.nullable(),
  live: z.boolean(),
  run: RawRunSchema.nullable(),
  triage: z.record(z.string(), z.unknown()).nullable(),
  paused: z.boolean(),
  stop: z.boolean(),
  lock: z.record(z.string(), z.string()).nullable(),
  lock_text: z.string(),
  trace: z.string().nullable(),
  traces_bytes: z.number(),
  kill: z.boolean().optional(),
  last: z.record(z.string(), z.unknown()).nullable().optional(),
  edit_lock: z
    .object({
      pid: z.number().nullable().optional(),
      started: z.string().nullable().optional(),
      purpose: z.string().nullable().optional(),
      live: z.boolean(),
    })
    .nullable()
    .optional(),
  log: z.string().optional(),
  orphan: z.boolean().optional(),
});

/** The raw status. */
export type RawStatus = z.infer<typeof RawStatusSchema>;

/** Hours after which the run lock counts as stale (the backlog tool's `STALE_HOURS`). */
const STALE_LOCK_HOURS = 24;

/** Seconds without a heartbeat after which a loop that claims to be live is shown as dead. */
const HEARTBEAT_DEAD_SECONDS = 30;

/**
 * Parses the loop's local time stamp `YYYY-MM-DD HH:MM:SS` (or ISO).
 *
 * @param value - The stamp.
 * @returns Milliseconds since the epoch, or null.
 */
export function parseStamp(value: string | null | undefined): number | null {
  if (!value) return null;
  const time = Date.parse(value.includes("T") ? value : value.replace(" ", "T"));
  return Number.isNaN(time) ? null : time;
}

/**
 * Converts the loop's local stamp into the ISO-like form the client parses (local time, no zone).
 *
 * @param value - The stamp.
 * @returns `YYYY-MM-DDTHH:MM:SS`, or null.
 */
function isoLocal(value: string | null | undefined): string | null {
  return value ? value.replace(" ", "T") : null;
}

/**
 * Converts seconds since the epoch into an ISO time.
 *
 * @param seconds - Epoch seconds, possibly absent.
 * @returns The ISO time, or null.
 */
function isoFromEpoch(seconds: unknown): string | null {
  return typeof seconds === "number" && Number.isFinite(seconds)
    ? new Date(seconds * 1000).toISOString()
    : null;
}

/**
 * Reads the utilisation of one usage window of a `rate_limit_info` record.
 *
 * @param usage - The record.
 * @param name - `five_hour` or `seven_day`.
 * @returns Utilisation 0-1, or null.
 */
function windowUse(usage: Record<string, unknown>, name: string): number | null {
  const windows = usage["unifiedWindows"];
  if (!windows || typeof windows !== "object") return null;
  const window = (windows as Record<string, unknown>)[name];
  if (!window || typeof window !== "object") return null;
  const value = (window as Record<string, unknown>)["utilization"];
  return typeof value === "number" ? value : null;
}

/**
 * Derives the loop view from a raw status (pure; tested with recorded fixtures).
 *
 * @param raw - The output of `status --json`.
 * @param now - The current time in milliseconds (injectable for tests).
 * @returns The view.
 */
export function deriveLoopView(raw: RawStatus, now: number = Date.now()): LoopView {
  const loop = raw.loop;
  const run = raw.run;
  const heartbeat = parseStamp(loop?.updated);
  const heartbeatAge = heartbeat === null ? null : Math.max(0, Math.round((now - heartbeat) / 1000));
  const state = loop?.state ?? null;
  const busy = state === "running" || state === "triage";
  const needsPerson = run !== null && (run.phase === "failed" || run.phase === "lost");

  let shown: LoopShown;
  let detail: string;
  // The order of the branches is the priority: a live loop is described by itself; without one, a
  // run a person must look at outranks a crashed loop, which outranks a foreign lock holder.
  if (raw.live && loop) {
    // A live loop: its own state, refined by the pending control flags.
    if (raw.kill) {
      shown = "kill-pending";
      detail = "a hard stop was requested; the loop handles it within a second";
    } else if (raw.paused && busy) {
      shown = "pause-pending";
      detail = `${loop.detail ?? state} - pauses when this finishes`;
    } else if (raw.stop && busy) {
      shown = "stop-pending";
      detail = `${loop.detail ?? state} - stops when this finishes`;
    } else if (
      heartbeatAge !== null &&
      heartbeatAge > HEARTBEAT_DEAD_SECONDS &&
      state !== "running" &&
      state !== "triage"
    ) {
      // While claude runs the loop still ticks every second; a silent waiting loop is suspicious.
      shown = "dead";
      detail = `the loop has not written its heartbeat for ${heartbeatAge} s`;
    } else {
      shown =
        (["starting", "running", "triage", "waiting", "idle", "paused", "limit", "backoff"] as const).find(
          (s) => s === state,
        ) ?? "running";
      detail = loop.detail ?? state ?? "running";
    }
  } else if (needsPerson) {
    shown = "stopped-for-person";
    detail = `the run of ${run.slug} cannot be continued automatically (${run.phase}${run.why ? `: ${run.why}` : ""})`;
  } else if (loop) {
    // `loop.json` without a live process: the loop was killed (closed window, crash) before it
    // could remove its state file.
    shown = "dead";
    detail = `the loop of pid ${loop.pid ?? "?"} ended without cleanup at about ${loop.updated ?? "?"}`;
  } else if (raw.lock && !run) {
    shown = "run-outside-loop";
    detail = `a run outside the loop holds the lock (item ${raw.lock["slug"] ?? "-"})`;
  } else {
    shown = "not-running";
    detail = run ? `not running - the run of ${run.slug} is continued by the next start` : "not running";
  }

  const lockStarted = parseStamp(raw.lock?.["started"]);
  const usage = loop?.usage ?? null;
  const last = raw.last ?? null;
  const editLock = raw.edit_lock?.live
    ? {
        pid: raw.edit_lock.pid ?? 0,
        started: raw.edit_lock.started ?? "",
        purpose: raw.edit_lock.purpose ?? "",
      }
    : null;

  return {
    shown,
    detail,
    until: isoLocal(loop?.until ?? null),
    live: raw.live,
    heartbeatAge,
    pid: loop?.pid ?? null,
    started: isoLocal(loop?.started ?? null),
    // A dead loop's last slug is history, not "the item being implemented now".
    slug: raw.live ? (loop?.slug ?? null) : null,
    trace: raw.trace,
    counts: loop?.counts ?? {},
    blockedStreak: loop?.blocked_streak ?? 0,
    usage: usage
      ? {
          status: typeof usage["status"] === "string" ? usage["status"] : null,
          resetsAt: isoFromEpoch(usage["resetsAt"]),
          fiveHour: windowUse(usage, "five_hour"),
          sevenDay: windowUse(usage, "seven_day"),
        }
      : null,
    // Only an explicit `false` warns: older loop states lack the key.
    ctrlCSafe: loop?.ctrl_c_safe !== false,
    // A stop flag left by a loop that is gone is no pending request any more.
    flags: { pause: raw.paused, stop: raw.stop && raw.live, kill: raw.kill === true },
    lock: raw.lock
      ? {
          slug: raw.lock["slug"] ?? "-",
          branch: raw.lock["branch"] ?? "-",
          started: isoLocal(raw.lock["started"] ?? null) ?? "",
          host: raw.lock["host"] ?? "-",
          // Stale only suggests the release dialog; releasing still needs the typed slug and a
          // server check that no loop and no claude of a run is alive.
          stale: lockStarted !== null && now - lockStarted > STALE_LOCK_HOURS * 3600_000,
        }
      : null,
    interruptedRun:
      run && !raw.live
        ? {
            slug: run.slug,
            phase: run.phase ?? "unknown",
            why: run.why ?? null,
            waitUntil: isoFromEpoch(run.wait_until),
            needsPerson,
          }
        : null,
    orphanClaude: raw.orphan === true,
    tracesBytes: raw.traces_bytes,
    lastEnd:
      last && typeof last["ended"] === "string"
        ? {
            ended: isoLocal(last["ended"]) ?? last["ended"],
            exitCode: typeof last["exit_code"] === "number" ? last["exit_code"] : null,
            reason: typeof last["reason"] === "string" ? last["reason"] : "unknown",
          }
        : null,
    editLock,
    autoTriage: loop?.auto_triage === true,
  };
}
