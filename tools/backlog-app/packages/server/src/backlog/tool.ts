// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Adapter of the backlog tool `tools/backlog/backlog.py` (feature 242, additions of 344 in
 * `specs/344-backlog-web-app/contracts/backlog-cli-additions.md`).
 *
 * The tool is the single owner of the backlog format and its 18 check rules; the application never
 * writes a backlog file itself (FR-022). This adapter:
 * - runs the read commands (`board`, `show`, `legend`, `check`, `next`) and validates their JSON,
 *   so a format drift fails loudly instead of showing wrong data, and converts it to the shapes of
 *   `@backlog-app/shared` (camelCase, objects instead of `date commit` strings);
 * - runs the changing commands with `--json` and `--input-json -`: every text the user typed goes
 *   to the tool as a JSON object on stdin, never on the command line (research R7, R8);
 * - keeps apart the two meanings of exit code 1: *refused* (nothing written) and *written, but the
 *   check found problems* (never retried; analysis A1 §3).
 */

import { z } from "zod";
import {
  ApiError,
  BoardSchema,
  CheckResultSchema,
  ItemSchema,
  LegendSchema,
  NextUpSchema,
  type Board,
  type BoardRow,
  type CheckResult,
  type Finding,
  type Item,
  type Legend,
  type NextUp,
  type ReadRef,
} from "@backlog-app/shared";
import { BACKLOG_PY } from "../context.ts";
import { pythonExecutable, runProcess } from "../proc/spawn.ts";

/** A `-`-or-value header field. */
const Dashed = z.string().nullable().optional();

/** The header fields as the tool prints them (hyphenated keys, `-` already null). */
const RawHeaderSchema = z.looseObject({
  slug: z.string(),
  title: z.string(),
  type: z.string(),
  status: z.string(),
  severity: z.union([z.number(), z.string()]),
  area: z.string(),
  source: z.string(),
  who: z.string(),
  created: z.string(),
  updated: z.string(),
  verified: Dashed,
  effort: Dashed,
  feature: Dashed,
  related: z.array(z.string()).nullable().optional(),
  "depends-on": z.array(z.string()).nullable().optional(),
  reason: Dashed,
});

/** A row of `board --json`: an item row or a hand-written note row. */
const RawRowSchema = z.union([
  RawHeaderSchema.extend({
    position: z.number().nullable().optional(),
    body: z.string().optional(),
    issue: z.string().nullable().optional(),
  }),
  z.object({ note: z.string() }),
]);

/** `board --json`. */
const RawBoardSchema = z.object({
  revision: z.string(),
  last_triaged: z.string().nullable().optional(),
  sections: z.array(z.object({ name: z.string(), ordered: z.boolean(), rows: z.array(RawRowSchema) })),
  unreadable: z.array(z.object({ slug: z.string(), path: z.string(), finding: z.string() })),
});

/** `show <slug> --json`. */
const RawItemSchema = RawHeaderSchema.extend({
  revision: z.string(),
  section: z.string().nullable(),
  position: z.number().nullable().optional(),
  body: z.array(z.object({ name: z.string(), markdown: z.string() })),
  log: z.array(z.object({ date: z.string(), text: z.string() })),
  steps: z.array(z.object({ index: z.number(), done: z.boolean(), text: z.string() })),
  options: z.array(z.object({ key: z.string(), text: z.string() })),
  files: z.object({
    issue: z
      .object({ number: z.number().nullable().optional(), head: z.record(z.string(), z.string()) })
      .nullable(),
    reply: z.object({ state: z.string() }).nullable(),
    evidence: z.array(z.string()),
  }),
  dependents: z.array(z.string()),
  findings: z.array(z.object({ path: z.string(), line: z.number(), rule: z.string(), message: z.string() })),
  eligibility: z.object({ eligible: z.boolean(), reason: z.string().nullable().optional() }),
});

/** `legend --json`. */
const RawLegendSchema = z.object({
  types: z.array(z.object({ value: z.string(), meaning: z.string() })),
  statuses: z.array(z.object({ value: z.string(), meaning: z.string() })),
  areas: z.array(z.object({ value: z.string(), meaning: z.string() })),
  who: z.array(z.object({ value: z.string(), meaning: z.string() })),
  efforts: z.array(z.object({ value: z.string(), meaning: z.string() })),
  sources: z.array(z.object({ form: z.string(), meaning: z.string() })),
  severity: z.array(z.object({ range: z.string(), meaning: z.string() })),
});

/** The `--json` result of a changing command. */
const RawChangeSchema = z.object({
  ok: z.boolean(),
  refused: z.string().nullable(),
  slugs: z.array(z.string()),
  section: z.string().nullable().optional(),
  position: z.number().nullable().optional(),
  notices: z.array(z.string()),
  findings: z.array(z.object({ path: z.string(), line: z.number(), rule: z.string(), message: z.string() })),
  written: z.array(z.string()),
});

/** The result of a changing command, as the rest of the server uses it. */
export interface ToolChange {
  /** True when the tool wrote the change. */
  ok: boolean;
  /** The items the command concerned. */
  slugs: string[];
  /** The section the item is in afterwards, if the command reports it. */
  section: string | null;
  /** Its position there. */
  position: number | null;
  /** Notices of the tool. */
  notices: string[];
  /** Check findings after the change (written anyway; never retry). */
  findings: Finding[];
  /** Every file written or deleted, relative to the root, `/`-separated. */
  written: string[];
}

/**
 * Converts a `date commit` verification stamp into its parts.
 *
 * @param value - The stamp or null.
 * @returns The parts, or null.
 */
function verifiedOf(value: string | null | undefined): Item["verified"] {
  if (!value) return null;
  const [date = "", commit = ""] = value.split(/\s+/, 2);
  return { date, commit };
}

/**
 * Converts the raw header fields into the app's header shape.
 *
 * @param raw - The tool's fields.
 * @returns The header.
 */
function headerOf(raw: z.infer<typeof RawHeaderSchema>) {
  return {
    slug: raw.slug,
    title: raw.title,
    type: raw.type,
    status: raw.status,
    severity: Number(raw.severity),
    area: raw.area,
    source: raw.source,
    who: raw.who,
    created: raw.created,
    updated: raw.updated,
    verified: verifiedOf(raw.verified),
    // The tool prints an effort of `-` (not estimated) as null; the app shows it as `-`.
    effort: raw.effort ?? "-",
    feature: raw.feature ?? null,
    related: raw.related ?? [],
    dependsOn: raw["depends-on"] ?? [],
    reason: raw.reason ?? null,
  };
}

/** Access to the backlog tool for one repository. */
export class BacklogTool {
  /** The repository root the tool acts on (`--root`). */
  readonly root: string;

  /**
   * Creates the adapter.
   *
   * @param root - Repository root.
   */
  constructor(root: string) {
    this.root = root;
  }

  /**
   * Runs the tool.
   *
   * @param globalArgs - Global options before the command (`--json`, `--input-json -`, `--ref R`).
   * @param args - The command and its arguments (validated values only).
   * @param stdin - JSON text for `--input-json -`.
   * @returns Exit code and output.
   */
  private async run(globalArgs: string[], args: string[], stdin?: string) {
    const result = await runProcess(
      pythonExecutable(),
      ["-X", "utf8", BACKLOG_PY, "--root", this.root, ...globalArgs, ...args],
      { cwd: this.root, timeoutMs: 120_000, ...(stdin === undefined ? {} : { stdin }) },
    );
    return result;
  }

  /**
   * Runs a read command and parses its JSON output.
   *
   * @param args - Command and options.
   * @param ref - `main` to read git objects, else the working tree.
   * @param allowExit1 - Exit 1 still carries valid JSON (`check` with findings).
   * @returns The parsed JSON.
   * @throws ApiError `tool-failed` when the tool fails or prints no JSON.
   */
  private async readJson(args: string[], ref: ReadRef, allowExit1 = false): Promise<unknown> {
    const globalArgs = ["--json", ...(ref === "main" ? ["--ref", "main"] : [])];
    const result = await this.run(globalArgs, args);
    if (result.code !== 0 && !(allowExit1 && result.code === 1)) {
      if (result.stdout.trim().startsWith("refused:") || result.stderr.includes("refused:")) {
        throw new ApiError("not-found", (result.stdout + result.stderr).trim());
      }
      throw new ApiError("tool-failed", `backlog.py ${args[0] ?? ""} failed`, result.stderr || result.stdout);
    }
    try {
      return JSON.parse(result.stdout);
    } catch {
      throw new ApiError(
        "tool-failed",
        `backlog.py ${args[0] ?? ""} printed no JSON`,
        result.stdout.slice(0, 2000),
      );
    }
  }

  /**
   * Reads the whole overview.
   *
   * @param ref - Where to read from.
   * @param withBody - Include item bodies and `issue.md` texts (for the search index).
   * @returns The board.
   */
  async board(ref: ReadRef, withBody = false): Promise<Board> {
    const raw = RawBoardSchema.parse(
      await this.readJson(["board", ...(withBody ? ["--with-body"] : [])], ref),
    );
    const sections = raw.sections.map((section) => ({
      name: section.name,
      ordered: section.ordered,
      rows: section.rows.map((row): BoardRow => {
        if ("note" in row && !("slug" in row)) return { kind: "note", note: row.note };
        const item = row as z.infer<typeof RawHeaderSchema> & {
          position?: number | null;
          body?: string;
          issue?: string | null;
        };
        return {
          kind: "item",
          ...headerOf(item),
          position: item.position ?? null,
          ...(item.body === undefined ? {} : { body: item.body }),
          ...(item.issue ? { issue: item.issue } : {}),
        };
      }),
    }));
    return BoardSchema.parse({
      revision: raw.revision,
      ref,
      lastTriaged: raw.last_triaged ?? null,
      sections,
      unreadable: raw.unreadable,
    });
  }

  /**
   * Reads one item.
   *
   * @param slug - The item (validated by the caller).
   * @param ref - Where to read from.
   * @returns The item.
   * @throws ApiError `not-found` for an unknown slug.
   */
  async show(slug: string, ref: ReadRef): Promise<Item> {
    const raw = RawItemSchema.parse(await this.readJson(["show", slug], ref));
    return ItemSchema.parse({
      ...headerOf(raw),
      revision: raw.revision,
      ref,
      section: raw.section,
      position: raw.position ?? null,
      body: raw.body,
      log: raw.log,
      steps: raw.steps,
      options: raw.options,
      files: {
        issue: raw.files.issue
          ? { number: raw.files.issue.number ?? null, head: raw.files.issue.head }
          : null,
        reply: raw.files.reply,
        evidence: raw.files.evidence,
      },
      dependents: raw.dependents,
      findings: raw.findings,
      eligibility: { eligible: raw.eligibility.eligible, reason: raw.eligibility.reason ?? null },
    });
  }

  /**
   * Reads the legend.
   *
   * @param ref - Where to read from.
   * @returns The legend.
   */
  async legend(ref: ReadRef): Promise<Legend> {
    const raw = RawLegendSchema.parse(await this.readJson(["legend"], ref));
    return LegendSchema.parse({
      ...raw,
      sources: raw.sources.map((s) => ({ value: s.form, meaning: s.meaning })),
      severity: raw.severity.map((s) => ({ value: s.range, meaning: s.meaning })),
    });
  }

  /**
   * Runs the consistency check (working tree only; the tool refuses `--ref` for it).
   *
   * @returns The findings.
   */
  async check(): Promise<CheckResult> {
    return CheckResultSchema.parse(await this.readJson(["check"], "worktree", true));
  }

  /**
   * What the next autonomous run would take.
   *
   * @param ref - Where to read from.
   * @returns The next-up answer.
   */
  async next(ref: ReadRef): Promise<NextUp> {
    const raw = z
      .object({
        slug: z.string().nullable(),
        skipped: z.array(z.object({ slug: z.string(), reason: z.string() })).optional(),
      })
      .parse(await this.readJson(["next"], ref, true));
    return NextUpSchema.parse({ slug: raw.slug, skipped: raw.skipped ?? [] });
  }

  /**
   * Runs a changing command with `--json` and the user's texts on stdin.
   *
   * @param args - The command, the slug and validated non-text options.
   * @param texts - Text fields for `--input-json -` (omitted when empty).
   * @returns The change.
   * @throws ApiError `refused` (nothing written; the tool's text verbatim) or `tool-failed`.
   */
  async change(args: string[], texts: Record<string, unknown> = {}): Promise<ToolChange> {
    const hasTexts = Object.keys(texts).length > 0;
    const result = await this.run(
      ["--json", ...(hasTexts ? ["--input-json", "-"] : [])],
      args,
      hasTexts ? JSON.stringify(texts) : undefined,
    );
    let parsed: z.infer<typeof RawChangeSchema> | null;
    try {
      parsed = RawChangeSchema.parse(JSON.parse(result.stdout));
    } catch {
      parsed = null;
    }
    if (!parsed) {
      // Usage errors (exit 2) and crashes print text, not the result object.
      const text = `${result.stdout}${result.stderr}`.trim();
      if (result.code === 2) throw new ApiError("invalid-request", text || "usage error of backlog.py");
      throw new ApiError("tool-failed", `backlog.py ${args[0] ?? ""} failed`, text.slice(0, 4000));
    }
    if (!parsed.ok) throw new ApiError("refused", parsed.refused ?? "refused", { written: parsed.written });
    return {
      ok: true,
      slugs: parsed.slugs,
      section: parsed.section ?? null,
      position: parsed.position ?? null,
      notices: parsed.notices,
      findings: parsed.findings,
      written: parsed.written.map((p) => p.replaceAll("\\", "/")),
    };
  }
}
