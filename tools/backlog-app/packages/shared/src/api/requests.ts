// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Request bodies and answers of the changing API routes (contracts/http-api.md).
 *
 * Every changing request that acts on the backlog carries `base`: the revisions the user's view
 * was based on. The server compares them under the edit lock and refuses a stale change with
 * `409 changed-underneath` (research R12), so a change a run or a terminal made in between is
 * never silently overwritten.
 */

import { z } from "zod";
import { FindingSchema, SectionNameSchema, SlugSchema } from "../schemas/backlog.ts";
import { ChangeSchema } from "../schemas/app-state.ts";

/** The revisions a view was based on. */
export const BaseSchema = z.object({
  /** SHA-256 of `BACKLOG.md` (moves, reorders, new items). */
  board: z.string().optional(),
  /** SHA-256 of the item's `desc.md` (item changes). */
  item: z.string().optional(),
});

/** A one-line text (no line breaks or control characters), as the tool requires for reasons. */
const OneLine = z
  .string()
  .min(1)
  .max(2000)
  .regex(/^[^\p{Cc}]*$/u, "must be one line without control characters");

/** Header fields a `set` may change (status and dates are never set directly). */
export const SETTABLE_FIELDS = [
  "title",
  "type",
  "severity",
  "area",
  "source",
  "who",
  "effort",
  "related",
  "depends-on",
] as const;

/** Change header fields of an item. */
export const SetFieldsRequestSchema = z.object({
  /** Revisions of the view. */
  base: BaseSchema,
  /** New values; lists as arrays of slugs, severity as a number. */
  set: z.record(z.enum(SETTABLE_FIELDS), z.union([z.string(), z.number(), z.array(SlugSchema)])),
  /** Why (becomes the log line). */
  reason: OneLine.optional(),
  /** Position in the new section when the change moves the row. */
  position: z.number().int().positive().optional(),
});

/** Move an item to a section (also park, reject, reopen, back to Inbox). */
export const MoveRequestSchema = z.object({
  /** Revisions of the view. */
  base: BaseSchema,
  /** Target section. */
  section: SectionNameSchema,
  /** 1-based position in an ordered section; default the end. */
  position: z.number().int().positive().optional(),
  /** Required for Parked, Rejected and moves out of them. */
  reason: OneLine.optional(),
});

/** The full new order of an ordered section. */
export const OrderRequestSchema = z.object({
  /** Revisions of the view. */
  base: BaseSchema,
  /** All item slugs of the section in their new order. */
  order: z.array(SlugSchema).min(1),
});

/** Block an item. */
export const BlockRequestSchema = z.object({
  /** Revisions of the view. */
  base: BaseSchema,
  /** What it waits for. */
  reason: OneLine,
});

/** Unblock an item. */
export const UnblockRequestSchema = z.object({
  /** Revisions of the view. */
  base: BaseSchema,
  /** Optional note for the log. */
  note: OneLine.optional(),
});

/** Close an item without a feature (it was fixed elsewhere, or is obsolete). */
export const CloseRequestSchema = z.object({
  /** Revisions of the view. */
  base: BaseSchema,
  /** Why it is closed (also recorded in the commit message). */
  reason: OneLine,
});

/** Replace, add or remove one body section. */
export const BodyRequestSchema = z.object({
  /** Revisions of the view. */
  base: BaseSchema,
  /** New Markdown of the section; absent with `remove`. */
  markdown: z.string().max(200_000).optional(),
  /** Remove an optional section. */
  remove: z.boolean().optional(),
  /** Log line text (default `edited <section>`). */
  log: OneLine.optional(),
});

/** Tick or untick a checklist line of a person step. */
export const StepRequestSchema = z.object({
  /** Revisions of the view. */
  base: BaseSchema,
  /** Ticked or not. */
  done: z.boolean(),
  /** The result, for the log. */
  note: OneLine.optional(),
});

/** Follow-up of a decision. */
export const DecideThenSchema = z.object({
  /** What happens to the item after the decision is logged. */
  action: z.enum(["keep", "move", "set-type", "park", "close"]),
  /** Target section for `move`. */
  section: SectionNameSchema.optional(),
  /** Position for `move` / `set-type`. */
  position: z.number().int().positive().optional(),
  /** New type for `set-type` (or with `move`). */
  type: z.string().optional(),
  /** New who for `set-type`. */
  who: z.string().optional(),
});

/** Record the maintainer's decision on a decision item. */
export const DecideRequestSchema = z.object({
  /** Revisions of the view. */
  base: BaseSchema,
  /** The chosen option's key. */
  option: z.string().min(1).max(8),
  /** The decision sentence. */
  decision: OneLine,
  /** The follow-up. */
  then: DecideThenSchema,
});

/** Set the state of `reply.md`. */
export const ReplyRequestSchema = z.object({
  /** Revisions of the view. */
  base: BaseSchema,
  /** New state. */
  state: z.enum(["not-sent", "sent"]),
});

/** Append a log line. */
export const LogRequestSchema = z.object({
  /** Revisions of the view. */
  base: BaseSchema,
  /** The text. */
  text: OneLine,
});

/** Stamp an item as verified at HEAD of `main`. */
export const VerifyRequestSchema = z.object({
  /** Revisions of the view. */
  base: BaseSchema,
  /** Optional note. */
  note: OneLine.optional(),
});

/** Create a new item. */
export const NewItemRequestSchema = z.object({
  /** Revisions of the view (the board). */
  base: BaseSchema,
  /** Title (one line). */
  title: OneLine.max(200),
  /** Legend type. */
  type: z.string(),
  /** Severity 0-10. */
  severity: z.number().int().min(0).max(10),
  /** Legend area. */
  area: z.string(),
  /** Who. */
  who: z.string().optional(),
  /** Effort. */
  effort: z.string().optional(),
  /** Source form (default `manual`). */
  source: z.string().optional(),
  /** Related slugs. */
  related: z.array(SlugSchema).optional(),
  /** Dependencies. */
  dependsOn: z.array(SlugSchema).optional(),
  /** Explicit slug when the title gives none. */
  slug: SlugSchema.optional(),
  /** Body texts (Markdown); the tool's template fills absent required sections. */
  problem: z.string().max(200_000).optional(),
  /** Evidence text. */
  evidence: z.string().max(200_000).optional(),
  /** Expected text. */
  expected: z.string().max(200_000).optional(),
  /** Optional approach text. */
  approach: z.string().max(200_000).optional(),
  /** Optional notes. */
  notes: z.string().max(200_000).optional(),
  /** Question of a decision. */
  question: z.string().max(200_000).optional(),
  /** Options of a decision. */
  options: z.string().max(200_000).optional(),
  /** Recommendation of a decision. */
  recommendation: z.string().max(200_000).optional(),
  /** Steps of a person step. */
  steps: z.string().max(200_000).optional(),
  /** Place it directly instead of leaving it in the Inbox. */
  place: z
    .object({ section: SectionNameSchema, position: z.number().int().positive().optional() })
    .optional(),
});

/** Import GitHub issues. */
export const ImportRequestSchema = z.object({
  /** Revisions of the view (the board). */
  base: BaseSchema,
  /** One issue number... */
  number: z.number().int().positive().optional(),
  /** ...or every new issue with this label. */
  label: z.string().min(1).max(100).optional(),
  /** Only report what would be imported. */
  dryRun: z.boolean().optional(),
  /** Area for the new items. */
  area: z.string().optional(),
  /** Severity for the new items. */
  severity: z.number().int().min(0).max(10).optional(),
  /** Type for a single issue. */
  type: z.string().optional(),
});

/** One change applied to several items. */
export const BulkRequestSchema = z.object({
  /** Revisions of the view (the board). */
  base: BaseSchema,
  /** The items. */
  slugs: z.array(SlugSchema).min(1).max(200),
  /** The operation. */
  operation: z.discriminatedUnion("kind", [
    z.object({ kind: z.literal("block"), reason: OneLine }),
    z.object({ kind: z.literal("unblock"), note: OneLine.optional() }),
    z.object({ kind: z.literal("move"), section: SectionNameSchema, reason: OneLine.optional() }),
    z.object({
      kind: z.literal("set"),
      set: z.record(z.enum(SETTABLE_FIELDS), z.union([z.string(), z.number()])),
      reason: OneLine.optional(),
    }),
  ]),
});

/** The answer of every changing backlog route. */
export const ChangeResultSchema = z.object({
  /** True when the tool wrote the change. */
  ok: z.boolean(),
  /** Check findings after a written change (show as a warning; never retry). */
  findings: z.array(FindingSchema),
  /** Notices of the tool (e.g. `moved to 'Person steps' (type / who changed)`). */
  notices: z.array(z.string()),
  /** The tray entry that records the change. */
  change: ChangeSchema.nullable(),
  /** The new board revision. */
  board: z.string(),
  /** The new item revision, when an item changed and still exists. */
  item: z.string().nullable(),
  /** Text output of the tool for dry runs and imports. */
  output: z.string().optional(),
});

/** The answer of a changing route. */
export type ChangeResult = z.infer<typeof ChangeResultSchema>;

/** Commit the tray. */
export const CommitRequestSchema = z.object({
  /** The commit message (edited proposal). */
  message: z.string().min(1).max(20_000),
  /** Dirty backlog paths changed outside the app that the maintainer ticked. */
  includeOutside: z.array(z.string()).default([]),
});

/** Undo one pending change. */
export const UndoRequestSchema = z.object({
  /** The change to undo (must be the newest not undone). */
  changeId: z.string(),
});

/** Confirmation text for dangerous loop and lock actions (typed by the maintainer). */
export const ConfirmRequestSchema = z.object({
  /** Must equal the running item's slug (or `triage`), or the lock's slug. */
  confirm: z.string().min(1).max(80),
});

/** Run one chosen item. */
export const RunItemRequestSchema = z.object({
  /** The item. */
  slug: SlugSchema,
  /** Optional model. */
  model: z
    .string()
    .regex(/^[A-Za-z0-9._\-[\]]{1,64}$/)
    .optional(),
  /** Commit the tray first. */
  commitTray: z.boolean().optional(),
});
