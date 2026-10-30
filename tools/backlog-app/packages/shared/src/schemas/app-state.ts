// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Schemas of the state the application owns (data-model.md, *Application state*).
 *
 * Everything here is kept by the server in `<git-common-dir>/tandem-backlog-app/` - never in the
 * tracked tree, so the working tree stays clean for the loop's precheck (research R1) - or is
 * computed on the fly (the write gate).
 */

import { z } from "zod";

/** States of the write gate (research R9, analysis A4 §4.1). */
export const GATE_STATES = [
  "free",
  "loop-between-runs",
  "run-holds-lock",
  "auto-triage",
  "not-on-main",
  "merge-in-progress",
  "stale-lock",
  "edit-in-progress",
  "degraded",
] as const;

/** One write-gate state. */
export const GateStateSchema = z.enum(GATE_STATES);

/** A write-gate state. */
export type GateState = z.infer<typeof GateStateSchema>;

/** Whether the backlog may be changed now, and why not. */
export const WriteGateSchema = z.object({
  /** The state. */
  state: GateStateSchema,
  /** True only in `free`: changing controls are enabled. */
  writable: z.boolean(),
  /** The reason in words, shown at every disabled control. */
  reason: z.string(),
  /** False when the consistency check has findings (writes ask first). */
  checkClean: z.boolean(),
  /** The working tree's branch. */
  branch: z.string(),
  /** True when HEAD is `main`. */
  headIsMain: z.boolean(),
  /** Dirty paths outside `backlog/` (they keep the loop waiting; the app never commits them). */
  dirtyOutsideBacklog: z.array(z.string()),
});

/** The write gate. */
export type WriteGate = z.infer<typeof WriteGateSchema>;

/** Kinds of operations recorded in the change tray. */
export const CHANGE_OPERATIONS = [
  "move",
  "reorder",
  "set",
  "block",
  "unblock",
  "park",
  "reject",
  "reopen",
  "close",
  "new",
  "import",
  "body",
  "step",
  "decide",
  "reply",
  "log",
  "verify",
  "sync",
] as const;

/** One tray operation kind. */
export const ChangeOperationSchema = z.enum(CHANGE_OPERATIONS);

/** A file an operation touched, with its content hash before and after (null = absent). */
export const ChangedFileSchema = z.object({
  /** Path relative to the repository root, `/`-separated. */
  path: z.string(),
  /** SHA-256 before the operation, null when the file did not exist. */
  before: z.string().nullable(),
  /** SHA-256 after the operation, null when the file was deleted. */
  after: z.string().nullable(),
});

/** One entry of the change tray (research R11). */
export const ChangeSchema = z.object({
  /** Unique id. */
  id: z.string(),
  /** When the operation was applied (ISO time). */
  at: z.string(),
  /** The operation. */
  operation: ChangeOperationSchema,
  /** The items it concerned. */
  slugs: z.array(z.string()),
  /** One line in the style of the backlog skill's reports, e.g. `slug: Inbox -> Next #11`. */
  summary: z.string(),
  /** The reason the maintainer gave, if any. */
  reason: z.string().nullable(),
  /** The files it touched. */
  files: z.array(ChangedFileSchema),
  /** `pending` until committed, `undone` after an undo. */
  state: z.enum(["pending", "committed", "undone"]),
  /** The commit that recorded it, once committed. */
  commit: z.string().nullable(),
});

/** One change. */
export type Change = z.infer<typeof ChangeSchema>;

/** The change tray as the client sees it. */
export const TraySchema = z.object({
  /** Pending changes, oldest first. */
  pending: z.array(ChangeSchema),
  /** Dirty paths under `backlog/` that no pending change explains. */
  outside: z.array(z.string()),
  /** The commit message the app proposes. */
  proposedMessage: z.string(),
});

/** The tray. */
export type Tray = z.infer<typeof TraySchema>;

/** Kinds of notification events (research R21). */
export const EVENT_KINDS = [
  "run-ended",
  "stopped-for-person",
  "usage-limit",
  "usage-limit-over",
  "precheck-wait",
  "inbox-added",
  "check-findings",
  "loop-ended",
] as const;

/** One notification event, kept in `events.jsonl`. */
export const NotificationEventSchema = z.object({
  /** Monotonic id (a counter persisted with the log). */
  id: z.number().int().positive(),
  /** When it happened (ISO time). */
  at: z.string(),
  /** Its kind. */
  kind: z.enum(EVENT_KINDS),
  /** `info`, `attention` or `urgent` (urgent stays until opened). */
  severity: z.enum(["info", "attention", "urgent"]),
  /** Short title. */
  title: z.string(),
  /** One or two sentences. */
  text: z.string(),
  /** In-app address to open (`/runs/<id>`, `/items/<slug>`, ...). */
  link: z.string().nullable(),
});

/** One notification event. */
export type NotificationEvent = z.infer<typeof NotificationEventSchema>;

/** The maintainer's settings (`settings.json`). */
export const SettingsSchema = z.object({
  /** Colour theme. */
  theme: z.enum(["system", "light", "dark"]).default("system"),
  /** Row density of the tables. */
  density: z.enum(["compact", "comfortable"]).default("compact"),
  /** Notification preferences. */
  notifications: z
    .object({
      /** Desktop notifications through the browser (asked once). */
      desktop: z.boolean().default(false),
      /** Which event kinds notify. */
      events: z.record(z.string(), z.boolean()).default({}),
      /** Hours without desktop notifications, `HH:MM`-`HH:MM`, or null. */
      quietHours: z.object({ from: z.string(), to: z.string() }).nullable().default(null),
    })
    .default({ desktop: false, events: {}, quietHours: null }),
  /** Commit the tray before the loop starts or resumes: ask, always or never. */
  autoCommitBeforeLoop: z.enum(["ask", "always", "never"]).default("ask"),
  /** Budget in US dollars per AI job. */
  aiBudgetUsd: z.number().min(0.1).max(50).default(2),
  /** Visible columns per section. */
  columns: z.record(z.string(), z.array(z.string())).default({}),
  /** Id of the newest notification event the maintainer has seen. */
  lastSeenEventId: z.number().int().min(0).default(0),
  /** When the maintainer last opened the app (ISO time), for "since your last visit". */
  lastVisit: z.string().nullable().default(null),
});

/** The settings. */
export type Settings = z.infer<typeof SettingsSchema>;

/** A named filter and sort (`views.json`). */
export const SavedViewSchema = z.object({
  /** Unique name. */
  name: z.string().min(1).max(60),
  /** In-app address with the filter in its query. */
  url: z.string().startsWith("/"),
  /** Shown in the sidebar. */
  pinned: z.boolean().default(true),
  /** Built in, not deletable. */
  builtIn: z.boolean().default(false),
});

/** A saved view. */
export type SavedView = z.infer<typeof SavedViewSchema>;

/** Kinds of AI jobs (contracts/ai-jobs.md). */
export const AI_JOB_KINDS = [
  "ask",
  "draft-item",
  "triage-check",
  "verify",
  "auto-triage-plan",
  "assess-issue",
] as const;

/** One AI job kind. */
export const AiJobKindSchema = z.enum(AI_JOB_KINDS);

/** An AI job kind. */
export type AiJobKind = z.infer<typeof AiJobKindSchema>;

/** One AI job (`jobs/<id>.json`). */
export const AiJobSchema = z.object({
  /** Unique id. */
  id: z.string(),
  /** Kind. */
  kind: AiJobKindSchema,
  /** The input (question, sentence, slug). */
  input: z.record(z.string(), z.unknown()),
  /** Lifecycle state. */
  state: z.enum(["running", "done", "failed", "cancelled"]),
  /** Start time (ISO). */
  startedAt: z.string(),
  /** End time (ISO), null while running. */
  endedAt: z.string().nullable(),
  /** Cost in US dollars as claude reported it. */
  costUsd: z.number().nullable(),
  /** Progress lines (tool calls and texts), oldest first. */
  progress: z.array(z.object({ at: z.string(), text: z.string() })),
  /** The validated result, null until done. */
  proposal: z.unknown().nullable(),
  /** Failure text, if failed. */
  error: z.string().nullable(),
  /** The branch the working tree was on when the job ran. */
  branch: z.string(),
});

/** An AI job. */
export type AiJob = z.infer<typeof AiJobSchema>;
