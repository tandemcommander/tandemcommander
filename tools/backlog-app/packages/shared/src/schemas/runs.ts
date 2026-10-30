// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Schemas of runs: one implementation of an item (or an auto-triage) by the loop, with its
 * phase, attempts, trace events and figures (data-model.md, *Run*, *Trace event*).
 *
 * Sources are the loop's `run.json`, the trace folder `.agent-traces/<dir>/` (`trace.jsonl`,
 * `meta.json`, feature 342), `index.jsonl`, the `RUNS.md` journal and git. Runs without a trace
 * (before feature 342, or manual runs) exist only as journal rows.
 */

import { z } from "zod";

/** The phases of an implementation run, in order (research R14). */
export const RUN_PHASES = [
  "starting",
  "selection",
  "measure",
  "specify",
  "clarify",
  "plan",
  "tasks",
  "analyze",
  "implement",
  "verify",
  "review",
  "close",
  "merge",
  "done",
  "stopped",
  "triage",
] as const;

/** One run phase. */
export const PhaseSchema = z.enum(RUN_PHASES);

/** A run phase. */
export type Phase = z.infer<typeof PhaseSchema>;

/** Outcome of a run. `running` while it is not finished. */
export const RUN_OUTCOMES = [
  "running",
  "closed",
  "blocked",
  "not-reproduced",
  "split",
  "nothing-to-do",
  "triaged",
  "killed",
  "failed",
  "lost",
  "unknown",
] as const;

/** One run outcome. */
export const OutcomeSchema = z.enum(RUN_OUTCOMES);

/** A run outcome. */
export type Outcome = z.infer<typeof OutcomeSchema>;

/** One attempt of a run (a claude process; continued attempts resume the same session). */
export const AttemptSchema = z.object({
  /** 1-based attempt number. */
  n: z.number().int().positive(),
  /** `start` or `continue`. */
  kind: z.string(),
  /** Why it was started (`-`, `usage-limit`, `error`, `stall`, `idle`, `killed`). */
  reason: z.string(),
  /** Start time (local or ISO, as recorded). */
  started: z.string().nullable(),
  /** End time, null while running. */
  ended: z.string().nullable(),
  /** How it ended in the loop's terms, null while running. */
  ending: z.string().nullable(),
});

/** One attempt. */
export type Attempt = z.infer<typeof AttemptSchema>;

/** Token and cost figures of a run (sum over attempts, each attempt's last `result`). */
export const CostSchema = z.object({
  /** Total cost in US dollars as claude reported it. */
  usd: z.number(),
  /** Input tokens. */
  inputTokens: z.number().int(),
  /** Output tokens. */
  outputTokens: z.number().int(),
  /** Tokens read from the prompt cache. */
  cacheRead: z.number().int(),
  /** Tokens written to the prompt cache. */
  cacheWrite: z.number().int(),
});

/** A tool call that has not returned yet. */
export const CurrentToolSchema = z.object({
  /** The tool's name (`Bash`, `Edit`, `Agent`, ...). */
  name: z.string(),
  /** A one-line summary of its input (the command, the file, the description). */
  summary: z.string(),
  /** When it started (ISO time, or receive time). */
  since: z.string().nullable(),
});

/** A commit of the run's branch. */
export const CommitSchema = z.object({
  /** Abbreviated hash. */
  hash: z.string(),
  /** Subject line. */
  subject: z.string(),
});

/** One run, live or ended. */
export const RunSchema = z.object({
  /** Trace folder name, or `runs-md:<row>` for a journal row without a trace. */
  id: z.string(),
  /** `item` or `triage`. */
  kind: z.enum(["item", "triage"]),
  /** The item, null for a triage. */
  slug: z.string().nullable(),
  /** The item's title, when known. */
  title: z.string().nullable(),
  /** Start time. */
  started: z.string().nullable(),
  /** End time, null while running. */
  ended: z.string().nullable(),
  /** Wall-clock duration in seconds (including waits between attempts). */
  durationSeconds: z.number().nullable(),
  /** The current or last phase. */
  phase: PhaseSchema,
  /** When each phase was first seen. */
  phaseTimeline: z.array(z.object({ phase: PhaseSchema, at: z.string().nullable() })),
  /** The attempts. */
  attempts: z.array(AttemptSchema),
  /** Outcome. */
  outcome: OutcomeSchema,
  /** Feature number, when the run created one. */
  feature: z.string().nullable(),
  /** The run's branch, when known. */
  branch: z.string().nullable(),
  /** Commits of the run. */
  commits: z.array(CommitSchema),
  /** Task progress from `tasks.md` (`[X]` / all), null outside implement. */
  tasks: z.object({ done: z.number().int(), total: z.number().int() }).nullable(),
  /** The tool call in flight, if any. */
  currentTool: CurrentToolSchema.nullable(),
  /** The last main-thread texts of the assistant, oldest first. */
  recentMessages: z.array(z.string()),
  /** True while a GUI probe runs on the hidden desktop (warn before a hard stop). */
  guiProbeRunning: z.boolean(),
  /** Cost figures, when the trace has results. */
  cost: CostSchema.nullable(),
  /** The journal's note (e.g. the blocked reason). */
  note: z.string().nullable(),
  /** True when a trace folder exists for the run. */
  hasTrace: z.boolean(),
});

/** One run. */
export type Run = z.infer<typeof RunSchema>;

/** Kinds of normalised trace events (data-model *Trace event*). */
export const TRACE_EVENT_KINDS = [
  "attempt",
  "init",
  "assistant-text",
  "thinking",
  "tool-use",
  "tool-result",
  "task",
  "rate-limit",
  "result",
  "system",
  "unparsable",
] as const;

/** One normalised line of `trace.jsonl`. */
export const TraceEventSchema = z.object({
  /** Byte offset of the line's start in `trace.jsonl` (the event id of the stream). */
  offset: z.number().int().min(0),
  /** Byte offset just after the line. */
  end: z.number().int().min(0),
  /** The event's own timestamp, if it has one. */
  at: z.string().nullable(),
  /** The kind of event. */
  kind: z.enum(TRACE_EVENT_KINDS),
  /** The tool call this event belongs to when it comes from a subagent, else null. */
  parentToolUseId: z.string().nullable(),
  /** The tool call id of a `tool-use` / `tool-result`. */
  toolUseId: z.string().nullable(),
  /** Tool name, attempt kind, result subtype, ... */
  name: z.string().nullable(),
  /** One-line rendering for lists. */
  summary: z.string(),
  /** Longer text (assistant text, a tool result excerpt), cut to a few kilobytes. */
  text: z.string().nullable(),
  /** True when the event marks an error (tool error, failed result). */
  isError: z.boolean(),
});

/** A normalised trace event. */
export type TraceEvent = z.infer<typeof TraceEventSchema>;

/** Kind of a trace event. */
export type TraceEventKind = (typeof TRACE_EVENT_KINDS)[number];

/** Aggregates over runs for the statistics panel. */
export const RunStatsSchema = z.object({
  /** Number of runs per outcome. */
  byOutcome: z.record(z.string(), z.number().int()),
  /** Number of runs per item area. */
  byArea: z.record(z.string(), z.number().int()),
  /** Runs per ISO week (`2026-W44`) and outcome. */
  byWeek: z.array(z.object({ week: z.string(), counts: z.record(z.string(), z.number().int()) })),
  /** Total cost in US dollars of the runs with traces. */
  costUsd: z.number(),
  /** Median and mean wall-clock duration in seconds of finished runs. */
  durations: z.object({ median: z.number().nullable(), mean: z.number().nullable() }),
});

/** Run statistics. */
export type RunStats = z.infer<typeof RunStatsSchema>;
