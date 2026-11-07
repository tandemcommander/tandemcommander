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

/** Token counts of one message or of a reported total (feature 415). */
export const TokenUsageSchema = z.object({
  /** Uncached input tokens. */
  input: z.number(),
  /** Output tokens (for a streamed message: the count at its start, research R3 of 415). */
  output: z.number(),
  /** Tokens read from the prompt cache. */
  cacheRead: z.number(),
  /** Tokens written to the 5-minute prompt cache. */
  cacheWrite5m: z.number(),
  /** Tokens written to the 1-hour prompt cache. */
  cacheWrite1h: z.number(),
});

/** Token counts. */
export type TokenUsage = z.infer<typeof TokenUsageSchema>;

/** Usage-limit utilisation of a `rate_limit_event` (feature 415). */
export const LimitInfoSchema = z.object({
  /** `allowed`, `allowed_warning`, `rejected`, ... */
  status: z.string(),
  /** Utilisation of the 5-hour window (0-1), when given. */
  fiveHour: z.number().nullable(),
  /** Utilisation of the 7-day window (0-1), when given. */
  sevenDay: z.number().nullable(),
  /** When the limiting window resets (epoch seconds), when given. */
  resetsAt: z.number().nullable(),
});

/** Usage-limit information. */
export type LimitInfo = z.infer<typeof LimitInfoSchema>;

/**
 * Facts of an event taken from its line beyond the summary (feature 415, data-model
 * *TraceEvent.info*): what the human story, the metrics and the gallery need. Every field is
 * optional; older events have none.
 */
export const TraceInfoSchema = z.object({
  /** The tool input's own `description` (Bash, PowerShell, Agent), or the skill and its args. */
  description: z.string().optional(),
  /** The tool input's file (`file_path`, `notebook_path`, `path`). */
  filePath: z.string().optional(),
  /** The `subagent_type` of an Agent call. */
  subagentType: z.string().optional(),
  /** The id of the assistant message (one message spans several lines). */
  messageId: z.string().optional(),
  /** The model of the assistant message. */
  model: z.string().optional(),
  /** The message's usage, on the first event made from its line. */
  usage: TokenUsageSchema.optional(),
  /** Characters of text and tool input of the line (an estimate of its output). */
  outputChars: z.number().optional(),
  /** A result's cumulative cost of its claude process (`total_cost_usd`). */
  costUsd: z.number().optional(),
  /** A result's cumulative tokens of its process (the sum of `modelUsage`). */
  totals: TokenUsageSchema.optional(),
  /** The models of a result's totals. */
  totalsModels: z.array(z.string()).optional(),
  /** A rate-limit event's utilisation. */
  limits: LimitInfoSchema.optional(),
  /** A subagent task's status or progress line. */
  taskStatus: z.string().optional(),
  /** A shell command with its line breaks (cut to 2 000 characters). */
  command: z.string().optional(),
  /** The working directory of a session (`system/init`): the repository root. */
  cwd: z.string().optional(),
  /** The last characters of a tool result longer than the kept text (its verdict). */
  tail: z.string().optional(),
});

/** Extra facts of an event. */
export type TraceInfo = z.infer<typeof TraceInfoSchema>;

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
  /** Extra facts of the line (feature 415); absent on events of older servers. */
  info: TraceInfoSchema.optional(),
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

/** A recorded answer of the feature's specification (feature 415). */
export const DecisionSchema = z.object({
  /** The question. */
  question: z.string(),
  /** The answer. */
  answer: z.string(),
  /** How it was decided (`recommended`, `conservative`, `item`, `rule`, ...), or empty. */
  how: z.string(),
});

/** One recorded decision. */
export type Decision = z.infer<typeof DecisionSchema>;

/** One image of a run's gallery (feature 415). */
export const RunImageSchema = z.object({
  /** Its place in the run's list (for the order). */
  n: z.number().int().min(0),
  /**
   * Its stable key (16 hex digits of a hash of its real path): the only way the page names it -
   * a place may shift when a new image is found, a key does not.
   */
  key: z.string().regex(/^[0-9a-f]{16}$/),
  /** The file name. */
  name: z.string(),
  /** Where it lies, for display (relative to the repository, or `%TEMP%\...`). */
  where: z.string(),
  /** `trace` (the run opened or wrote it) or `feature` (found in the feature folder). */
  source: z.enum(["trace", "feature"]),
  /** Size in bytes, null when the file is gone. */
  size: z.number().nullable(),
  /** Modification time (ISO), null when the file is gone. */
  modified: z.string().nullable(),
});

/** One gallery image. */
export type RunImage = z.infer<typeof RunImageSchema>;

/** What the server knows about a run beyond its trace (feature 415, contracts/http-api.md). */
export const RunInsightSchema = z.object({
  /** The run's branch, when it has a feature branch. */
  branch: z.string().nullable(),
  /** The feature folder (`specs/NNN-name`), when it exists. */
  featureFolder: z.string().nullable(),
  /** The documents of the feature folder. */
  documents: z.array(
    z.object({
      /** The document's name (`spec`, `plan`, ...). */
      name: z.string(),
      /** The file name. */
      file: z.string(),
      /** Size in bytes. */
      size: z.number(),
      /** Modification time (ISO). */
      modified: z.string(),
    }),
  ),
  /** The clarifications of `spec.md`. */
  decisions: z.array(DecisionSchema),
  /** The autonomous-run assumptions of `spec.md`. */
  assumptions: z.array(z.string()),
  /** Fenced diagrams of `plan.md`. */
  diagrams: z.array(
    z.object({
      /** The heading above the diagram. */
      title: z.string(),
      /** The diagram text. */
      text: z.string(),
    }),
  ),
  /** The gallery. */
  images: z.array(RunImageSchema),
  /** The basis of the expected duration. */
  estimate: z.object({
    /** Median wall-clock seconds of earlier closed runs, null with too few. */
    medianSeconds: z.number().nullable(),
    /** How many closed runs it rests on. */
    count: z.number().int(),
  }),
});

/** A run's insight. */
export type RunInsight = z.infer<typeof RunInsightSchema>;

/** The names of the documents a run's feature folder may show (contracts/http-api.md). */
export const RUN_DOCUMENTS = [
  "spec",
  "plan",
  "tasks",
  "fix-log",
  "research",
  "data-model",
  "quickstart",
  "closing-report",
] as const;
