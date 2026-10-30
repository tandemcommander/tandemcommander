// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Inputs and results of the AI jobs (contracts/ai-jobs.md, research R19).
 *
 * Every job kind has an input schema (what the maintainer asks) and a result schema (what claude
 * must answer). The result schema is passed to `claude -p --json-schema` as JSON Schema, so the
 * model is held to it, and the answer is validated again with the same zod schema before it is
 * shown: a result that does not match is a failed job, never a proposal. Results are previews -
 * nothing here writes; the server applies an edited proposal through the backlog tool after the
 * maintainer confirmed it.
 */

import { z } from "zod";
import { BaseSchema } from "../api/requests.ts";
import { AiJobKindSchema, AiJobSchema, type AiJobKind } from "./app-state.ts";
import { SectionNameSchema, SlugSchema } from "./backlog.ts";

/** A legend value (type, area, who, effort) as the model proposes it; the tool validates it. */
const LegendWord = z.string().min(1).max(60);

/** A severity 0-10. */
const Severity = z.number().int().min(0).max(10);

/** A position in an ordered section (1 = top). */
const Position = z.number().int().min(1).max(999);

/** A `file:line` reference the model cites as evidence. */
const EvidenceRef = z.string().min(1).max(400);

// --- inputs ---

/** Input of `ask`: a free question, optionally about one item. */
export const AiAskInputSchema = z.object({
  /** The question, any language. */
  question: z.string().min(1).max(4000),
  /** An item the question is about. */
  scope: SlugSchema.optional(),
});

/** Input of `draft-item`: one or more sentences, Czech or English. */
export const AiDraftItemInputSchema = z.object({
  /** What the item is about. */
  text: z.string().min(1).max(8000),
});

/** Input of the kinds that look at one item (`triage-check`, `verify`, `assess-issue`). */
export const AiSlugInputSchema = z.object({
  /** The item. */
  slug: SlugSchema,
});

/** Input of `auto-triage-plan`: nothing (every Inbox item). */
export const AiNoInputSchema = z.object({});

/** The input schema of every kind. */
export const AI_INPUT_SCHEMAS = {
  ask: AiAskInputSchema,
  "draft-item": AiDraftItemInputSchema,
  "triage-check": AiSlugInputSchema,
  verify: AiSlugInputSchema,
  "auto-triage-plan": AiNoInputSchema,
  "assess-issue": AiSlugInputSchema,
} as const satisfies Record<AiJobKind, z.ZodType>;

// --- results ---

/** Result of `ask`: a Markdown answer and the items and runs it relies on. */
export const AiAskResultSchema = z.object({
  /** The answer, Markdown. */
  answer: z.string(),
  /** Slugs of the items the answer relies on. */
  items: z.array(z.string()),
  /** Ids of the runs the answer relies on. */
  runs: z.array(z.string()),
});

/** Result of `ask`. */
export type AiAskResult = z.infer<typeof AiAskResultSchema>;

/** Result of `draft-item`: a complete new item, in English. */
export const AiDraftItemResultSchema = z.object({
  /** One-line title. */
  title: z.string().min(1).max(200),
  /** Legend type. */
  type: LegendWord,
  /** Severity 0-10. */
  severity: Severity,
  /** Legend area. */
  area: LegendWord,
  /** `agent`, `person` or `both`. */
  who: LegendWord,
  /** Effort estimate. */
  effort: LegendWord,
  /** Problem section, Markdown. */
  problem: z.string(),
  /** Evidence section, Markdown. */
  evidence: z.string(),
  /** Expected section, Markdown. */
  expected: z.string(),
  /** Related items. */
  related: z.array(z.string()),
  /** Items that must be done first. */
  dependsOn: z.array(z.string()),
  /** Where to place it, or null for the Inbox. */
  place: z.object({ section: SectionNameSchema, position: Position.nullable() }).nullable(),
  /** Why these values, one or two sentences. */
  why: z.string(),
});

/** Result of `draft-item`. */
export type AiDraftItemResult = z.infer<typeof AiDraftItemResultSchema>;

/** Verdicts of a placement check. */
export const AI_TRIAGE_VERDICTS = [
  "place",
  "park",
  "reject",
  "decision",
  "person-step",
  "duplicate",
] as const;

/** The fields of a placement check of one item. */
const triageFields = {
  /** What to do with the item. */
  verdict: z.enum(AI_TRIAGE_VERDICTS),
  /** The section it belongs in. */
  section: SectionNameSchema,
  /** Position in an ordered section, null for the end or an unordered section. */
  position: Position.nullable(),
  /** Severity 0-10. */
  severity: Severity,
  /** Legend area. */
  area: LegendWord,
  /** `agent`, `person` or `both`. */
  who: LegendWord,
  /** Effort estimate. */
  effort: LegendWord,
  /** Why, one or two sentences (becomes the reason of a park or reject). */
  reason: z.string().min(1).max(2000),
  /** The item this one duplicates (verdict `duplicate`). */
  duplicateOf: z.string().optional(),
  /** `file:line` references the verdict rests on. */
  evidence: z.array(EvidenceRef),
};

/** Result of `triage-check`. */
export const AiTriageCheckResultSchema = z.object(triageFields);

/** Result of `triage-check`. */
export type AiTriageCheckResult = z.infer<typeof AiTriageCheckResultSchema>;

/** Result of `verify`: is the item still true at the current code? */
export const AiVerifyResultSchema = z.object({
  /** The verdict. */
  verdict: z.enum(["still-true", "fixed", "partly", "unclear"]),
  /** The commit that fixed it, if known. */
  commit: z.string().optional(),
  /** `file:line` references the verdict rests on. */
  evidence: z.array(EvidenceRef),
  /** A note for the item's log, one or two sentences. */
  note: z.string().min(1).max(2000),
});

/** Result of `verify`. */
export type AiVerifyResult = z.infer<typeof AiVerifyResultSchema>;

/** One row of an auto-triage plan. */
export const AiTriagePlanRowSchema = z.object({
  /** The Inbox item. */
  slug: z.string(),
  ...triageFields,
});

/** One row of an auto-triage plan. */
export type AiTriagePlanRow = z.infer<typeof AiTriagePlanRowSchema>;

/** Result of `auto-triage-plan`: a placement check for every Inbox item. */
export const AiAutoTriagePlanResultSchema = z.object({
  /** One row per Inbox item. */
  items: z.array(AiTriagePlanRowSchema),
});

/** Result of `auto-triage-plan`. */
export type AiAutoTriagePlanResult = z.infer<typeof AiAutoTriagePlanResultSchema>;

/** Result of `assess-issue`: the judgement of an imported GitHub issue. */
export const AiAssessIssueResultSchema = z.object({
  /** Legend type. */
  type: LegendWord,
  /** Severity 0-10. */
  severity: Severity,
  /** Legend area. */
  area: LegendWord,
  /** `agent`, `person` or `both`. */
  who: LegendWord,
  /** The problem in English, Markdown (becomes the item's Problem section). */
  summary: z.string().min(1),
  /** An existing item this issue duplicates. */
  duplicateOf: z.string().optional(),
  /** A reply to the reporter, Markdown - offered for copying, never posted. */
  reply: z.string().optional(),
});

/** Result of `assess-issue`. */
export type AiAssessIssueResult = z.infer<typeof AiAssessIssueResultSchema>;

/** The result schema of every kind. */
export const AI_RESULT_SCHEMAS = {
  ask: AiAskResultSchema,
  "draft-item": AiDraftItemResultSchema,
  "triage-check": AiTriageCheckResultSchema,
  verify: AiVerifyResultSchema,
  "auto-triage-plan": AiAutoTriagePlanResultSchema,
  "assess-issue": AiAssessIssueResultSchema,
} as const satisfies Record<AiJobKind, z.ZodType>;

/** Kinds whose result proposes a change of the backlog (refused while the write gate is closed). */
export const AI_PROPOSING_KINDS: ReadonlySet<AiJobKind> = new Set<AiJobKind>([
  "draft-item",
  "triage-check",
  "verify",
  "auto-triage-plan",
  "assess-issue",
]);

/**
 * The JSON Schema of a kind's result, for `claude --json-schema`. The `$schema` key is left out:
 * claude takes the schema as a tool input schema, which needs no dialect marker.
 *
 * @param kind - The job kind.
 * @returns The JSON Schema as a plain object.
 */
export function aiResultJsonSchema(kind: AiJobKind): Record<string, unknown> {
  const { $schema: _dialect, ...schema } = z.toJSONSchema(AI_RESULT_SCHEMAS[kind]) as Record<string, unknown>;
  return schema;
}

// --- requests and the stored job ---

/** `POST /api/ai/jobs`. */
export const AiJobCreateRequestSchema = z.object({
  /** The kind. */
  kind: AiJobKindSchema,
  /** The kind's input (validated with {@link AI_INPUT_SCHEMAS}). */
  input: z.record(z.string(), z.unknown()).default({}),
  /** A model alias or name for `--model` (default: claude's own). */
  model: z
    .string()
    .regex(/^[A-Za-z0-9][A-Za-z0-9.\-_[\]]{0,63}$/)
    .optional(),
});

/** A request to start a job. */
export type AiJobCreateRequest = z.infer<typeof AiJobCreateRequestSchema>;

/** `POST /api/ai/jobs/{id}/apply`: the proposal as the maintainer edited it. */
export const AiJobApplyRequestSchema = z.object({
  /** The edited proposal; validated with the kind's result schema. */
  proposal: z.unknown(),
  /** The revisions the preview was based on. */
  base: BaseSchema.default({}),
});

/** A request to apply a proposal. */
export type AiJobApplyRequest = z.infer<typeof AiJobApplyRequestSchema>;

/**
 * A stored job: the shared job shape plus what only the detail view needs - the raw output of a
 * failed job, the model, and the changes an applied proposal made.
 */
export const AiJobRecordSchema = AiJobSchema.extend({
  /** The raw result text (kept when the result did not match its schema, or the budget ended it). */
  raw: z.string().nullable().default(null),
  /** The model asked for, or null for claude's default. */
  model: z.string().nullable().default(null),
  /** The tray changes made when the maintainer applied the proposal, or null. */
  applied: z
    .object({ changeIds: z.array(z.string()), at: z.string() })
    .nullable()
    .default(null),
});

/** A stored job. */
export type AiJobRecord = z.infer<typeof AiJobRecordSchema>;
