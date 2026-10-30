// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Applies an AI job's proposal after the maintainer reviewed and possibly edited it
 * (contracts/ai-jobs.md, *Kinds*, column *Applied as*; FR-038).
 *
 * A proposal is never written by the job itself. Here it is validated again with the kind's schema
 * (the maintainer may have edited it), mapped to the same backlog-tool commands the changing routes
 * use (`new`, `set`, `move`, `verify`, `log`, `body`), and run through the write queue - edit lock,
 * fresh gate, revision check - with every command recorded in the change tray, exactly like
 * `api/backlog-write.ts` does. User texts travel on the tool's stdin only.
 */

import { join } from "node:path";
import {
  AI_RESULT_SCHEMAS,
  ApiError,
  type AiAssessIssueResult,
  type AiAutoTriagePlanResult,
  type AiDraftItemResult,
  type AiJobApplyRequest,
  type AiTriageCheckResult,
  type AiVerifyResult,
  type Change,
  type ChangeResult,
  type ItemRow,
  type SectionName,
} from "@backlog-app/shared";
import type { Services } from "../services.ts";
import { fileHash, type Base } from "../backlog/write-queue.ts";
import { toolChangeForTray } from "../backlog/tray.ts";
import { resolveRef } from "../repo/git.ts";
import { SECTION_ARG } from "../api/backlog-write.ts";
import { SLUG_PATTERN } from "../api/common.ts";
import type { AiJobRunner } from "./runner.ts";

/** One tool command of an application. */
export interface ApplyOperation {
  /** Tray operation kind. */
  operation: Change["operation"];
  /** The tool's arguments; a function receives the slug a previous `new` created. */
  args: string[] | ((created: string) => string[]);
  /** Texts for `--input-json -`. */
  texts?: Record<string, unknown>;
  /** One line for the tray; a function receives the created slug. */
  summary: string | ((created: string) => string);
  /** The maintainer's (or the proposal's) reason. */
  reason?: string | null;
}

/** The outcome of one item of an application (one row of an auto-triage plan). */
export interface ApplyRowResult {
  /** The item. */
  slug: string;
  /** True when its commands were written. */
  ok: boolean;
  /** The tool's refusal, when not. */
  refused?: string;
  /** Check findings after its commands. */
  findings?: ChangeResult["findings"];
}

/** The answer of `POST /api/ai/jobs/{id}/apply`. */
export interface ApplyAnswer {
  /** True when something was written. */
  ok: boolean;
  /** Check findings after the written commands (show as a warning; never retry). */
  findings: ChangeResult["findings"];
  /** Notices of the tool. */
  notices: string[];
  /** The tray entries, in order. */
  changes: Change[];
  /** Per item, for an auto-triage plan (empty for the other kinds). */
  results: ApplyRowResult[];
  /** The new board revision. */
  board: string;
  /** The new revision of the item concerned, if one. */
  item: string | null;
}

/**
 * Formats a header value for `set key=value`.
 *
 * @param value - The value.
 * @returns The text.
 */
function setValue(value: string | number): string {
  return String(value);
}

/**
 * The `set` pairs of the fields whose proposed value differs from the item's.
 *
 * @param row - The item as the board shows it.
 * @param proposed - Proposed values by header key.
 * @returns `key=value` pairs (empty when nothing changes).
 */
export function changedPairs(row: ItemRow, proposed: Record<string, string | number | undefined>): string[] {
  const current: Record<string, string | number> = {
    type: row.type,
    severity: row.severity,
    area: row.area,
    who: row.who,
    effort: row.effort,
  };
  return Object.entries(proposed)
    .filter(([key, value]) => value !== undefined && String(current[key]) !== String(value))
    .map(([key, value]) => `${key}=${setValue(value!)}`);
}

/**
 * The commands of a placement verdict (`triage-check`, one row of `auto-triage-plan`): first the
 * changed fields (`set`), then the move to the section the verdict leads to.
 *
 * @param row - The item.
 * @param verdict - The (edited) verdict.
 * @returns The commands.
 */
export function placementOperations(row: ItemRow, verdict: AiTriageCheckResult): ApplyOperation[] {
  const slug = row.slug;
  const operations: ApplyOperation[] = [];
  const proposed: Record<string, string | number | undefined> = {
    severity: verdict.severity,
    area: verdict.area,
    who: verdict.who,
    effort: verdict.effort,
  };
  let section: SectionName = verdict.section;
  let reason = verdict.reason;
  switch (verdict.verdict) {
    case "park":
      section = "Parked";
      break;
    case "reject":
      section = "Rejected";
      break;
    case "duplicate":
      section = "Rejected";
      reason = verdict.duplicateOf
        ? `duplicate of ${verdict.duplicateOf}: ${verdict.reason}`
        : verdict.reason;
      break;
    case "decision":
      section = "Decisions for the maintainer";
      proposed["type"] = "decision";
      break;
    case "person-step":
      section = "Person steps";
      proposed["type"] = "person-step";
      proposed["who"] = "person";
      break;
    case "place":
      break;
  }
  if (section === "In progress") throw new ApiError("refused", "only a run moves an item to In progress");
  const pairs = changedPairs(row, proposed);
  if (pairs.length > 0) {
    operations.push({
      operation: "set",
      args: ["set", slug, ...pairs],
      texts: { log: `triage (AI check): set ${pairs.join(", ")}` },
      summary: `${slug}: set ${pairs.join(", ")}`,
      reason: null,
    });
  }
  const position = verdict.position !== null && verdict.verdict === "place" ? verdict.position : null;
  operations.push({
    operation: section === "Parked" ? "park" : section === "Rejected" ? "reject" : "move",
    args: [
      "move",
      slug,
      "--section",
      SECTION_ARG[section],
      ...(position ? ["--position", String(position)] : []),
    ],
    texts: { reason },
    summary: `${slug}: -> ${section}${position ? ` #${position}` : ""}`,
    reason,
  });
  return operations;
}

/**
 * The commands of a draft: `new` with the texts on stdin, then a `move` when it is placed.
 *
 * @param draft - The (edited) draft.
 * @returns The commands.
 */
export function draftOperations(draft: AiDraftItemResult): ApplyOperation[] {
  const args = [
    "new",
    "--type",
    draft.type,
    "--severity",
    String(draft.severity),
    "--area",
    draft.area,
    "--who",
    draft.who,
    "--effort",
    draft.effort,
  ];
  const related = draft.related.filter((s) => SLUG_PATTERN.test(s));
  const dependsOn = draft.dependsOn.filter((s) => SLUG_PATTERN.test(s));
  if (related.length) args.push("--related", related.join(","));
  if (dependsOn.length) args.push("--depends-on", dependsOn.join(","));
  const texts: Record<string, unknown> = { title: draft.title };
  if (draft.problem) texts["problem"] = draft.problem;
  if (draft.evidence) texts["evidence"] = draft.evidence;
  if (draft.expected) texts["expected"] = draft.expected;
  const operations: ApplyOperation[] = [
    {
      operation: "new",
      args,
      texts,
      summary: (created) => `${created}: created in Inbox (AI draft)`,
      reason: null,
    },
  ];
  const place = draft.place;
  if (place && place.section !== "Inbox") {
    if (place.section === "In progress")
      throw new ApiError("refused", "only a run moves an item to In progress");
    operations.push({
      operation: "move",
      args: (created) => [
        "move",
        created,
        "--section",
        SECTION_ARG[place.section],
        ...(place.position ? ["--position", String(place.position)] : []),
      ],
      summary: (created) => `${created}: -> ${place.section}${place.position ? ` #${place.position}` : ""}`,
      reason: null,
    });
  }
  return operations;
}

/**
 * The commands of a verification: `verify` at `main` with the note for `still-true`, a log line for
 * `partly` and `unclear`; `fixed` is closed by the maintainer through the close dialog.
 *
 * @param slug - The item.
 * @param result - The (edited) verification.
 * @param mainCommit - The commit `main` points to.
 * @returns The commands.
 */
export function verifyOperations(slug: string, result: AiVerifyResult, mainCommit: string): ApplyOperation[] {
  if (result.verdict === "fixed") {
    throw new ApiError(
      "refused",
      "a fixed item is closed with a reason through the close dialog (POST /api/items/{slug}/close)",
    );
  }
  if (result.verdict === "still-true") {
    return [
      {
        operation: "verify",
        args: ["verify", slug, "--commit", mainCommit.slice(0, 12)],
        texts: { note: result.note },
        summary: `${slug}: verified at ${mainCommit.slice(0, 8)} (AI check)`,
        reason: result.note,
      },
    ];
  }
  const text = `AI verification (${result.verdict}): ${result.note}`;
  return [
    { operation: "log", args: ["log", slug], texts: { text }, summary: `${slug}: log line`, reason: text },
  ];
}

/**
 * The commands of an issue assessment: the changed fields, the summary as the *Problem* section,
 * and a log line naming a possible duplicate. The reply is only offered for copying.
 *
 * @param row - The item.
 * @param result - The (edited) assessment.
 * @returns The commands.
 */
export function assessOperations(row: ItemRow, result: AiAssessIssueResult): ApplyOperation[] {
  const slug = row.slug;
  const operations: ApplyOperation[] = [];
  const pairs = changedPairs(row, {
    type: result.type,
    severity: result.severity,
    area: result.area,
    who: result.who,
  });
  if (pairs.length > 0) {
    operations.push({
      operation: "set",
      args: ["set", slug, ...pairs],
      texts: { log: `issue assessed (AI): set ${pairs.join(", ")}` },
      summary: `${slug}: set ${pairs.join(", ")}`,
      reason: null,
    });
  }
  operations.push({
    operation: "body",
    args: ["body", slug, "--section", "Problem"],
    texts: { markdown: result.summary, log: "Problem written from the issue assessment (AI)" },
    summary: `${slug}: edited Problem`,
    reason: null,
  });
  if (result.duplicateOf) {
    const text = `possible duplicate of ${result.duplicateOf} (AI assessment)`;
    operations.push({
      operation: "log",
      args: ["log", slug],
      texts: { text },
      summary: `${slug}: log line`,
      reason: text,
    });
  }
  return operations;
}

/**
 * Runs commands in the write queue and records each in the tray (like the changing routes).
 *
 * @param services - The server's services.
 * @param purpose - For the edit lock.
 * @param base - The view's revisions.
 * @param slug - The item of `base.item` (null for a new item).
 * @param operations - The commands; a later one runs only when the earlier ones wrote cleanly.
 * @returns The answer (without per-row results).
 */
async function runOperations(
  services: Services,
  purpose: string,
  base: Base,
  slug: string | null,
  operations: ApplyOperation[],
): Promise<ApplyAnswer> {
  const { queue, tray, tool } = services;
  return queue.run(purpose, base, slug, async () => {
    const changes: Change[] = [];
    const findings: ChangeResult["findings"] = [];
    const notices: string[] = [];
    let created = slug ?? "";
    for (const op of operations) {
      const args = typeof op.args === "function" ? op.args(created) : op.args;
      /**
       * The summary of the operation (a new item's summary names the slug the tool chose).
       *
       * @returns The one-line summary.
       */
      const summaryNow = (): string => (typeof op.summary === "function" ? op.summary(created) : op.summary);
      const { result, before } = await toolChangeForTray(tray, tool, args, op.texts ?? {}, {
        operation: op.operation,
        slugs: created ? [created] : [],
        summary: summaryNow(),
        reason: op.reason ?? null,
      });
      if (op.operation === "new") created = result.slugs[0] ?? created;
      findings.push(...result.findings);
      notices.push(...result.notices);
      changes.push(
        tray.record({
          operation: op.operation,
          slugs: result.slugs.length ? result.slugs : created ? [created] : [],
          summary: summaryNow(),
          reason: op.reason ?? null,
          before,
          written: result.written,
        }),
      );
      // A written change with check findings stops the chain: never build on a broken state.
      if (result.findings.length > 0) break;
    }
    const root = services.ctx.repo.root;
    return {
      ok: changes.length > 0,
      findings,
      notices,
      changes,
      results: [],
      board: fileHash(join(root, "backlog", "BACKLOG.md")) ?? "",
      item: created ? fileHash(join(root, "backlog", "items", created, "desc.md")) : null,
    };
  });
}

/**
 * The board row of an item.
 *
 * @param services - The server's services.
 * @param slug - The item.
 * @returns The row.
 * @throws ApiError `not-found` when the board has no such item.
 */
async function rowOf(services: Services, slug: string): Promise<ItemRow> {
  if (!SLUG_PATTERN.test(slug)) throw new ApiError("not-found", "no such item");
  const snapshot = await services.read.snapshot();
  for (const section of snapshot.board.sections) {
    for (const row of section.rows) if (row.kind === "item" && row.slug === slug) return row;
  }
  throw new ApiError("not-found", `no such item: ${slug}`);
}

/**
 * Applies a job's (edited) proposal through the backlog tool.
 *
 * @param services - The server's services.
 * @param runner - The job runner (the job is marked applied).
 * @param id - The job id.
 * @param request - The edited proposal and the view's revisions.
 * @returns What was written.
 * @throws ApiError `not-found`, `refused` (no proposal, an answer, already applied), `invalid-request`
 *   (the edited proposal does not match the schema), or what the queue and the tool raise.
 */
export async function applyProposal(
  services: Services,
  runner: AiJobRunner,
  id: string,
  request: AiJobApplyRequest,
): Promise<ApplyAnswer> {
  const job = runner.get(id);
  if (!job) throw new ApiError("not-found", "no such job");
  if (job.kind === "ask") throw new ApiError("refused", "an answer is shown, not applied");
  if (job.state !== "done") throw new ApiError("refused", `the job is ${job.state} - it has no proposal`);
  if (job.applied) throw new ApiError("refused", "this proposal was already applied");
  const parsed = AI_RESULT_SCHEMAS[job.kind].safeParse(request.proposal);
  if (!parsed.success) {
    throw new ApiError(
      "invalid-request",
      "the edited proposal does not match its schema",
      parsed.error.issues,
    );
  }
  const base: Base = request.base;
  const jobSlug = typeof job.input["slug"] === "string" ? job.input["slug"] : null;
  let answer: ApplyAnswer;
  switch (job.kind) {
    case "draft-item": {
      const draft = parsed.data as AiDraftItemResult;
      answer = await runOperations(
        services,
        `new item ${draft.title.slice(0, 40)}`,
        base,
        null,
        draftOperations(draft),
      );
      break;
    }
    case "triage-check": {
      const row = await rowOf(services, jobSlug ?? "");
      answer = await runOperations(
        services,
        `triage ${row.slug}`,
        base,
        row.slug,
        placementOperations(row, parsed.data as AiTriageCheckResult),
      );
      break;
    }
    case "verify": {
      const slug = (await rowOf(services, jobSlug ?? "")).slug;
      const main = await resolveRef(services.ctx.repo.root, "main");
      if (!main) throw new ApiError("refused", "there is no main branch to verify against");
      answer = await runOperations(
        services,
        `verify ${slug}`,
        base,
        slug,
        verifyOperations(slug, parsed.data as AiVerifyResult, main),
      );
      break;
    }
    case "assess-issue": {
      const row = await rowOf(services, jobSlug ?? "");
      answer = await runOperations(
        services,
        `assess ${row.slug}`,
        base,
        row.slug,
        assessOperations(row, parsed.data as AiAssessIssueResult),
      );
      break;
    }
    case "auto-triage-plan": {
      // One queued application per accepted row; a refused row does not stop the others.
      const plan = parsed.data as AiAutoTriagePlanResult;
      answer = { ok: false, findings: [], notices: [], changes: [], results: [], board: "", item: null };
      let first = true;
      for (const entry of plan.items) {
        try {
          const row = await rowOf(services, entry.slug);
          const rowAnswer = await runOperations(
            services,
            `triage ${row.slug}`,
            first ? { board: base.board } : {},
            row.slug,
            placementOperations(row, entry),
          );
          answer.changes.push(...rowAnswer.changes);
          answer.findings.push(...rowAnswer.findings);
          answer.notices.push(...rowAnswer.notices);
          answer.board = rowAnswer.board;
          answer.results.push({ slug: entry.slug, ok: true, findings: rowAnswer.findings });
        } catch (error) {
          answer.results.push({
            slug: entry.slug,
            ok: false,
            refused: error instanceof Error ? error.message : String(error),
          });
          // A closed gate or a stale view refuses every further row too.
          if (
            error instanceof ApiError &&
            (error.code === "gate-closed" || error.code === "changed-underneath")
          ) {
            break;
          }
        }
        first = false;
      }
      answer.ok = answer.changes.length > 0;
      if (!answer.board) answer.board = fileHash(join(services.ctx.repo.root, "backlog", "BACKLOG.md")) ?? "";
      break;
    }
  }
  if (answer.changes.length > 0)
    runner.markApplied(
      id,
      answer.changes.map((c) => c.id),
    );
  return answer;
}
