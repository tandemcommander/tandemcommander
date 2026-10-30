// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Schemas of the backlog as the application shows it (data-model.md, *Projections*).
 *
 * The backlog is owned by `tools/backlog/backlog.py`; the server reads it through the tool's JSON
 * commands (`board`, `show`, `legend`, `check`, `next`), validates the raw output and converts it
 * into these shapes (camelCase, integers, `null` instead of `-`). The web client receives only
 * these shapes. Field meanings follow the item format of feature 242
 * (`specs/242-backlog-system/contracts/item-format.md`).
 */

import { z } from "zod";

/** A slug: the item's folder name, lowercase ASCII words joined by single hyphens, at most 60 characters. */
export const SlugSchema = z
  .string()
  .max(60)
  .regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, "not a backlog slug");

/** A calendar date `YYYY-MM-DD` as the backlog writes it. */
export const DateSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "not a YYYY-MM-DD date");

/** The names of the overview sections, in their order in `BACKLOG.md`. */
export const SECTION_NAMES = [
  "In progress",
  "Next",
  "Decisions for the maintainer",
  "Person steps",
  "Inbox",
  "Parked",
  "Rejected",
] as const;

/** One of the seven overview sections. */
export const SectionNameSchema = z.enum(SECTION_NAMES);

/** A section name (`"Next"`, `"Inbox"`, ...). */
export type SectionName = z.infer<typeof SectionNameSchema>;

/** The four sections whose row order is the maintainer's priority (only they can be reordered). */
export const ORDERED_SECTIONS: readonly SectionName[] = [
  "In progress",
  "Next",
  "Decisions for the maintainer",
  "Person steps",
];

/** One value of a legend table with its explanation (e.g. area `encoding`). */
export const LegendValueSchema = z.object({
  /** The value as written in item headers. */
  value: z.string(),
  /** The legend's explanation of the value. */
  meaning: z.string(),
});

/** One legend value. */
export type LegendValue = z.infer<typeof LegendValueSchema>;

/**
 * The legend of `BACKLOG.md`: the vocabulary of every item field. The application has no built-in
 * list of areas, types, sources or who values; a new legend row appears without a code change
 * (FR-008).
 */
export const LegendSchema = z.object({
  /** Item types (`bug`, `feature`, ...). */
  types: z.array(LegendValueSchema),
  /** Statuses (`new`, `open`, `blocked`, `in-progress`, `parked`, `rejected`). */
  statuses: z.array(LegendValueSchema),
  /** Areas (`encoding`, `archives`, ...). */
  areas: z.array(LegendValueSchema),
  /** Who can do the item (`agent`, `person`, `both`). */
  who: z.array(LegendValueSchema),
  /** Effort estimates (`S`, `M`, `L`, `?`, `-`). */
  efforts: z.array(LegendValueSchema),
  /** Source forms (`manual`, `github#N`, `review:NNN`, ...); `value` holds the form. */
  sources: z.array(LegendValueSchema),
  /** Severity anchors; `value` holds a range such as `9-10`. */
  severity: z.array(LegendValueSchema),
});

/** The backlog legend. */
export type Legend = z.infer<typeof LegendSchema>;

/** The verification stamp of an item: the date and the commit it was verified at. */
export const VerifiedSchema = z.object({
  /** Day of the verification. */
  date: DateSchema,
  /** Abbreviated or full commit hash the item was verified at. */
  commit: z.string(),
});

/** The header fields every item has (the 15 keys of the item format, in app form). */
export const ItemHeaderSchema = z.object({
  /** The item's identifier (its folder name); never changes. */
  slug: SlugSchema,
  /** One-line title. */
  title: z.string(),
  /** Legend type. */
  type: z.string(),
  /** Legend status. */
  status: z.string(),
  /** Severity 0-10. */
  severity: z.number().int().min(0).max(10),
  /** Legend area. */
  area: z.string(),
  /** Where the item came from (`manual`, `github#12`, `review:341`, ...). */
  source: z.string(),
  /** Who can do it: `agent`, `person` or `both`. */
  who: z.string(),
  /** Creation day. */
  created: DateSchema,
  /** Day of the last change. */
  updated: DateSchema,
  /** Verification stamp, or null when never verified. */
  verified: VerifiedSchema.nullable(),
  /** Effort estimate. */
  effort: z.string(),
  /** Feature number of the run implementing it (only while `in-progress`), else null. */
  feature: z.string().nullable(),
  /** Related items (informational). */
  related: z.array(z.string()),
  /** Items that must be done first (hard dependency). */
  dependsOn: z.array(z.string()),
  /** Reason of a `blocked`, `parked` or `rejected` status, else null. */
  reason: z.string().nullable(),
});

/** The header of an item. */
export type ItemHeader = z.infer<typeof ItemHeaderSchema>;

/** A row of an overview section that is an item. */
export const ItemRowSchema = ItemHeaderSchema.extend({
  /** Discriminator of the row kind. */
  kind: z.literal("item"),
  /** 1-based position within an ordered section, null in the sorted sections. */
  position: z.number().int().positive().nullable(),
  /** Raw Markdown body (only when the board was read with bodies, for search). */
  body: z.string().optional(),
  /** Text of `issue.md` of a GitHub-imported item (only with bodies). */
  issue: z.string().optional(),
});

/** An item row of the board. */
export type ItemRow = z.infer<typeof ItemRowSchema>;

/** A hand-written row of `BACKLOG.md` without an item link (kept verbatim by the tool). */
export const NoteRowSchema = z.object({
  /** Discriminator of the row kind. */
  kind: z.literal("note"),
  /** The row's text. */
  note: z.string(),
});

/** A board row: an item or a note. */
export const BoardRowSchema = z.discriminatedUnion("kind", [ItemRowSchema, NoteRowSchema]);

/** A board row. */
export type BoardRow = z.infer<typeof BoardRowSchema>;

/** One overview section with its rows in order. */
export const SectionSchema = z.object({
  /** The section's name. */
  name: SectionNameSchema,
  /** Whether the row order is a priority the maintainer sets. */
  ordered: z.boolean(),
  /** The rows in the order of `BACKLOG.md`. */
  rows: z.array(BoardRowSchema),
});

/** One section of the board. */
export type Section = z.infer<typeof SectionSchema>;

/** An item whose header cannot be read; shown, never editable. */
export const UnreadableItemSchema = z.object({
  /** The folder name. */
  slug: z.string(),
  /** Path of its `desc.md`, relative to the repository root. */
  path: z.string(),
  /** The check finding that makes it unreadable. */
  finding: z.string(),
});

/** Where a projection was read from (research R10). */
export const ReadRefSchema = z.enum(["worktree", "main"]);

/** `worktree` (the files on disk) or `main` (git objects of the main line, during runs). */
export type ReadRef = z.infer<typeof ReadRefSchema>;

/** The whole overview: sections, rows, revision. */
export const BoardSchema = z.object({
  /** SHA-256 of `BACKLOG.md` as read; changing requests on the order carry it (research R12). */
  revision: z.string(),
  /** Where the board was read from. */
  ref: ReadRefSchema,
  /** Day of the last triage (`Last triaged:` line). */
  lastTriaged: DateSchema.nullable(),
  /** The seven sections in overview order. */
  sections: z.array(SectionSchema),
  /** Items that cannot be read. */
  unreadable: z.array(UnreadableItemSchema),
});

/** The backlog overview. */
export type Board = z.infer<typeof BoardSchema>;

/** One body section of an item (`Problem`, `Evidence`, ..., `Log`). */
export const BodySectionSchema = z.object({
  /** Section name without the `## `. */
  name: z.string(),
  /** Markdown text of the section without its heading. */
  markdown: z.string(),
});

/** One entry of an item's *Log*. */
export const LogEntrySchema = z.object({
  /** Day of the entry. */
  date: DateSchema,
  /** Text after the em dash. */
  text: z.string(),
});

/** One line of a person step's *Steps* checklist. */
export const StepSchema = z.object({
  /** 1-based number of the line among the checklist lines. */
  index: z.number().int().positive(),
  /** Whether the line is ticked. */
  done: z.boolean(),
  /** The line's text. */
  text: z.string(),
});

/** One option of a decision item. */
export const OptionSchema = z.object({
  /** The option's key (`A`, `B`, ...). */
  key: z.string(),
  /** The option's text. */
  text: z.string(),
});

/** The extra files of an item folder. */
export const ItemFilesSchema = z.object({
  /** The imported GitHub issue (`issue.md`), if any. */
  issue: z
    .object({
      /** Issue number. */
      number: z.number().int().nullable(),
      /** The `key: value` lines at the top of `issue.md` (url, author, state, labels, ...). */
      head: z.record(z.string(), z.string()),
    })
    .nullable(),
  /** The prepared answer (`reply.md`) and its state, if any. */
  reply: z.object({ state: z.string() }).nullable(),
  /** File names in `evidence/`. */
  evidence: z.array(z.string()),
});

/** A check finding (`<path>:<line>: <rule>: <message>`). */
export const FindingSchema = z.object({
  /** File path relative to the repository root. */
  path: z.string(),
  /** 1-based line, 0 when the finding concerns the whole file. */
  line: z.number().int(),
  /** One of the 18 rule ids of feature 242. */
  rule: z.string(),
  /** Human-readable message. */
  message: z.string(),
});

/** One check finding. */
export type Finding = z.infer<typeof FindingSchema>;

/** Whether an autonomous run could take the item, and why not. */
export const EligibilitySchema = z.object({
  /** True when the item is eligible for a run. */
  eligible: z.boolean(),
  /** The tool's reason when not eligible (e.g. `who person`), else null. */
  reason: z.string().nullable(),
});

/** One item with everything the detail view shows. */
export const ItemSchema = ItemHeaderSchema.extend({
  /** SHA-256 of `desc.md` as read; changing requests on the item carry it (research R12). */
  revision: z.string(),
  /** Where the item was read from. */
  ref: ReadRefSchema,
  /** The section the board shows it in. */
  section: SectionNameSchema.nullable(),
  /** Position in an ordered section, else null. */
  position: z.number().int().positive().nullable(),
  /** Body sections in file order. */
  body: z.array(BodySectionSchema),
  /** Parsed *Log*. */
  log: z.array(LogEntrySchema),
  /** Parsed *Steps* checklist (person steps). */
  steps: z.array(StepSchema),
  /** Parsed *Options* (decisions). */
  options: z.array(OptionSchema),
  /** Extra files of the folder. */
  files: ItemFilesSchema,
  /** Items whose `depends-on` names this one. */
  dependents: z.array(z.string()),
  /** The item's own check findings. */
  findings: z.array(FindingSchema),
  /** Run eligibility. */
  eligibility: EligibilitySchema,
});

/** A full item. */
export type Item = z.infer<typeof ItemSchema>;

/** Result of the consistency check. */
export const CheckResultSchema = z.object({
  /** Number of findings. */
  total: z.number().int().min(0),
  /** The findings. */
  findings: z.array(FindingSchema),
});

/** The check result. */
export type CheckResult = z.infer<typeof CheckResultSchema>;

/** What the next autonomous run would take, and why the rows above it are skipped. */
export const NextUpSchema = z.object({
  /** The eligible item, or null when nothing is eligible. */
  slug: z.string().nullable(),
  /** Every row above it (or every row of Next) that is skipped, with the reason. */
  skipped: z.array(z.object({ slug: z.string(), reason: z.string() })),
});

/** The next-up answer. */
export type NextUp = z.infer<typeof NextUpSchema>;

/** An item that was closed and removed; it lives on only in git history (research R16). */
export const ClosedItemSchema = z.object({
  /** The slug it had. */
  slug: z.string(),
  /** Its last title. */
  title: z.string(),
  /** Its last type, area and severity (for filters). */
  type: z.string(),
  /** Its last area. */
  area: z.string(),
  /** Its last severity. */
  severity: z.number().int().nullable(),
  /** The commit that removed it. */
  closedIn: z.object({ hash: z.string(), date: z.string(), subject: z.string() }),
  /** Feature number that closed it, when the commit or the log names one. */
  feature: z.string().nullable(),
  /** The last description (Markdown of `desc.md` before the removal), only in the detail answer. */
  lastDescription: z.string().optional(),
});

/** A closed item. */
export type ClosedItem = z.infer<typeof ClosedItemSchema>;

/** One commit of an item's history. */
export const HistoryCommitSchema = z.object({
  /** Full commit hash. */
  hash: z.string(),
  /** Author date, ISO 8601. */
  date: z.string(),
  /** Commit subject. */
  subject: z.string(),
  /** Author name. */
  author: z.string(),
});

/** One commit of an item's history. */
export type HistoryCommit = z.infer<typeof HistoryCommitSchema>;
