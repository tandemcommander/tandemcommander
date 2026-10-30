// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The filter language of the backlog views (research R20, analysis A4 §2.4).
 *
 * One text box, the same syntax in the page address and the command palette:
 *
 * ```text
 * type:bug,improvement  sev>=5  sev:4..6  area:encoding  who:agent  effort:S,M  status:blocked
 * section:next  source:review  source:github  is:github  has:deps  verified:none  verified<2026-10-01
 * created>=2026-10-20  related:<slug>  needs:<slug>  feature:341  slug:ftp-
 * "code page"  -"not reproduced"  -area:ftp   (free words = text in title, body and issue)
 * ```
 *
 * Unknown keys and values outside the legend are errors shown under the box - never silently
 * ignored, so a typo cannot quietly widen a view. The module is pure: the server evaluates it on
 * board rows, the client parses it for hints and chips.
 */

import type { ItemRow, Legend, SectionName } from "../schemas/backlog.ts";

/** A board row as the filter sees it: the item row plus the section it is in. */
export type FilterRow = Omit<ItemRow, "kind"> & {
  /** Always `item` (notes are never filtered). */
  kind: "item";
  /** The section the row is in. */
  section: SectionName;
};

/** Comparison of a field term. */
export type FilterOp = "in" | ">=" | "<=" | ">" | "<" | "range";

/** A condition on one field (`sev>=5`, `area:encoding,ftp`). */
export interface FieldTerm {
  /** Discriminator. */
  kind: "field";
  /** The key as typed (`sev`, `area`, ...). */
  key: string;
  /** The comparison. */
  op: FilterOp;
  /** One value for comparisons, two for a range, one or more for `in`. */
  values: string[];
  /** True when prefixed with `-`. */
  negate: boolean;
}

/** A free word or a quoted phrase. */
export interface TextTerm {
  /** Discriminator. */
  kind: "text";
  /** The word or phrase. */
  text: string;
  /** True for a quoted phrase. */
  phrase: boolean;
  /** True when prefixed with `-`. */
  negate: boolean;
}

/** One term of a query. */
export type FilterTerm = FieldTerm | TextTerm;

/** A part of the query that could not be understood. */
export interface FilterError {
  /** The token as typed. */
  token: string;
  /** Why it is wrong. */
  message: string;
}

/** The result of parsing. */
export interface ParsedFilter {
  /** The understood terms (all must match). */
  terms: FilterTerm[];
  /** The parts that were not understood. */
  errors: FilterError[];
}

/** Section names by the short names the language uses. */
const SECTION_ALIASES: Record<string, SectionName> = {
  progress: "In progress",
  "in-progress": "In progress",
  next: "Next",
  decisions: "Decisions for the maintainer",
  person: "Person steps",
  "person-steps": "Person steps",
  inbox: "Inbox",
  parked: "Parked",
  rejected: "Rejected",
};

/** Keys whose values must be legend values, with the legend table they come from. */
const LEGEND_KEYS: Record<string, keyof Legend> = {
  type: "types",
  area: "areas",
  who: "who",
  effort: "efforts",
  status: "statuses",
};

/** Keys whose values are dates and allow comparisons. */
const DATE_KEYS = new Set(["created", "updated", "verified"]);

/** Every key the language knows. */
const KNOWN_KEYS = new Set([
  ...Object.keys(LEGEND_KEYS),
  "sev",
  "severity",
  "section",
  "source",
  "is",
  "has",
  ...DATE_KEYS,
  "related",
  "needs",
  "feature",
  "slug",
]);

/** Values of `is:`. */
const IS_VALUES = new Set(["github", "blocked", "unverified", "verified", "eligible-type"]);

/** Values of `has:`. */
const HAS_VALUES = new Set(["deps", "related", "reason", "issue", "feature"]);

/** A token and whether it was a quoted phrase. */
interface RawToken {
  /** The token text without quotes and without a leading `-`. */
  text: string;
  /** The token as typed, for error messages. */
  original: string;
  /** Quoted. */
  quoted: boolean;
  /** Prefixed with `-`. */
  negate: boolean;
}

/**
 * Splits a query into tokens: whitespace separates, double quotes group, a leading `-` negates.
 *
 * @param input - The query text.
 * @returns The tokens.
 */
function tokenize(input: string): RawToken[] {
  const tokens: RawToken[] = [];
  let i = 0;
  while (i < input.length) {
    while (i < input.length && /\s/.test(input[i]!)) i++;
    if (i >= input.length) break;
    const start = i;
    let negate = false;
    if (input[i] === "-" && i + 1 < input.length && !/\s/.test(input[i + 1]!)) {
      negate = true;
      i++;
    }
    if (input[i] === '"') {
      // A quoted phrase runs to the next quote, or to the end when it is not closed.
      const close = input.indexOf('"', i + 1);
      const end = close < 0 ? input.length : close;
      tokens.push({
        text: input.slice(i + 1, end),
        original: input.slice(start, close < 0 ? end : end + 1),
        quoted: true,
        negate,
      });
      i = close < 0 ? input.length : close + 1;
      continue;
    }
    while (i < input.length && !/\s/.test(input[i]!)) i++;
    tokens.push({
      text: input.slice(negate ? start + 1 : start, i),
      original: input.slice(start, i),
      quoted: false,
      negate,
    });
  }
  return tokens.filter((t) => t.text.length > 0);
}

/**
 * Validates the values of a field term.
 *
 * @param key - The key.
 * @param op - The comparison.
 * @param values - The values.
 * @param legend - The legend.
 * @returns An error message, or null when valid.
 */
function validateField(key: string, op: FilterOp, values: string[], legend: Legend): string | null {
  const table = LEGEND_KEYS[key];
  if (table) {
    if (op !== "in") return `${key} takes a list (${key}:a,b), not a comparison`;
    const allowed = new Set(legend[table].map((v) => v.value));
    const bad = values.filter((v) => !allowed.has(v));
    return bad.length ? `${bad.join(", ")} is not a legend value of ${key}` : null;
  }
  if (key === "sev" || key === "severity") {
    const numeric = values.every((v) => /^(10|[0-9])$/.test(v));
    return numeric ? null : "severity is a number 0-10";
  }
  if (DATE_KEYS.has(key)) {
    if (
      key === "verified" &&
      op === "in" &&
      values.length === 1 &&
      (values[0] === "none" || values[0] === "any")
    ) {
      return null;
    }
    return values.every((v) => /^\d{4}-\d{2}-\d{2}$/.test(v)) ? null : `${key} takes a date YYYY-MM-DD`;
  }
  if (op !== "in") return `${key} takes values, not a comparison`;
  if (key === "section") {
    const bad = values.filter((v) => !SECTION_ALIASES[v.toLowerCase()]);
    return bad.length
      ? `unknown section ${bad.join(", ")} (next, inbox, decisions, person, parked, rejected, progress)`
      : null;
  }
  if (key === "is")
    return values.every((v) => IS_VALUES.has(v)) ? null : `is: takes ${[...IS_VALUES].join(", ")}`;
  if (key === "has")
    return values.every((v) => HAS_VALUES.has(v)) ? null : `has: takes ${[...HAS_VALUES].join(", ")}`;
  if (key === "feature")
    return values.every((v) => /^\d{3}$/.test(v)) ? null : "feature takes a three-digit number";
  return null;
}

/**
 * Parses a query.
 *
 * @param input - The query text.
 * @param legend - The legend (values of legend-backed keys are checked against it).
 * @returns Terms and errors.
 */
export function parseFilter(input: string, legend: Legend): ParsedFilter {
  const terms: FilterTerm[] = [];
  const errors: FilterError[] = [];
  for (const token of tokenize(input)) {
    if (token.quoted) {
      terms.push({ kind: "text", text: token.text, phrase: true, negate: token.negate });
      continue;
    }
    // key, then the first operator: >=, <=, >, <, or ':'.
    const match = /^([a-z-]+)(>=|<=|>|<|:)(.*)$/i.exec(token.text);
    if (!match) {
      terms.push({ kind: "text", text: token.text, phrase: false, negate: token.negate });
      continue;
    }
    const key = match[1]!.toLowerCase();
    const operator = match[2]!;
    const rest = match[3]!;
    if (!KNOWN_KEYS.has(key)) {
      errors.push({ token: token.original, message: `unknown key '${key}'` });
      continue;
    }
    let op: FilterOp;
    let values: string[];
    if (operator === ":") {
      if (/^[^,]+\.\.[^,]+$/.test(rest)) {
        op = "range";
        values = rest.split("..");
      } else {
        op = "in";
        values = rest.split(",").filter((v) => v.length > 0);
      }
    } else {
      op = operator as FilterOp;
      values = [rest];
    }
    if (values.length === 0 || values.some((v) => v.length === 0)) {
      errors.push({ token: token.original, message: `${key} needs a value` });
      continue;
    }
    const problem = validateField(key, op, values, legend);
    if (problem) {
      errors.push({ token: token.original, message: problem });
      continue;
    }
    terms.push({ kind: "field", key, op, values, negate: token.negate });
  }
  return { terms, errors };
}

/**
 * Folds text for matching: lower case, accents removed (`Žluťoučký` matches `zlutoucky`).
 *
 * @param text - Any text.
 * @returns The folded text.
 */
export function foldText(text: string): string {
  return text.normalize("NFD").replace(/\p{M}/gu, "").toLowerCase();
}

/**
 * Compares two values with an operator.
 *
 * @param actual - The row's value.
 * @param op - The comparison.
 * @param values - The term's values.
 * @returns Whether the comparison holds.
 */
function compare(actual: number | string, op: FilterOp, values: string[]): boolean {
  const numeric = typeof actual === "number";
  /**
   * Converts a term value to the row value's kind.
   *
   * @param v - The value as typed.
   * @returns A number for numeric fields, else the text.
   */
  const as = (v: string): number | string => (numeric ? Number(v) : v);
  const [first = "", second = ""] = values;
  switch (op) {
    case "in":
      return values.some((v) => as(v) === actual);
    case ">=":
      return actual >= as(first);
    case "<=":
      return actual <= as(first);
    case ">":
      return actual > as(first);
    case "<":
      return actual < as(first);
    case "range":
      return actual >= as(first) && actual <= as(second);
  }
}

/**
 * Evaluates one field term (without its negation).
 *
 * @param term - The term.
 * @param row - The row.
 * @returns Whether the row matches.
 */
function matchField(term: FieldTerm, row: FilterRow): boolean {
  const { key, op, values } = term;
  switch (key) {
    case "type":
      return values.includes(row.type);
    case "area":
      return values.includes(row.area);
    case "who":
      return values.includes(row.who);
    case "effort":
      return values.includes(row.effort);
    case "status":
      return values.includes(row.status);
    case "sev":
    case "severity":
      return compare(row.severity, op, values);
    case "section":
      return values.some((v) => SECTION_ALIASES[v.toLowerCase()] === row.section);
    case "source":
      // A prefix: `review` and `review:*` match `review:300`; `github` matches `github#12`.
      return values.some((v) => row.source.startsWith(v.replace(/\*$/, "")));
    case "is":
      return values.some((v) => {
        if (v === "github") return row.source.startsWith("github#");
        if (v === "blocked") return row.status === "blocked";
        if (v === "unverified") return row.verified === null;
        if (v === "verified") return row.verified !== null;
        return row.type !== "decision" && row.type !== "person-step";
      });
    case "has":
      return values.some((v) => {
        if (v === "deps") return row.dependsOn.length > 0;
        if (v === "related") return row.related.length > 0;
        if (v === "reason") return row.reason !== null;
        if (v === "feature") return row.feature !== null;
        return typeof row.issue === "string" && row.issue.length > 0;
      });
    case "created":
      return compare(row.created, op, values);
    case "updated":
      return compare(row.updated, op, values);
    case "verified":
      if (op === "in" && values[0] === "none") return row.verified === null;
      if (op === "in" && values[0] === "any") return row.verified !== null;
      return row.verified !== null && compare(row.verified.date, op, values);
    case "related":
      return values.some((v) => row.related.includes(v));
    case "needs":
      return values.some((v) => row.dependsOn.includes(v));
    case "feature":
      return row.feature !== null && values.includes(row.feature);
    case "slug":
      return values.some((v) => row.slug.startsWith(v));
    default:
      return false;
  }
}

/**
 * The text a free word is searched in: title, slug, body and the GitHub issue (folded).
 *
 * @param row - The row.
 * @returns The folded text.
 */
function haystackOf(row: FilterRow): string {
  return foldText(`${row.title}\n${row.slug}\n${row.body ?? ""}\n${row.issue ?? ""}`);
}

/**
 * Evaluates a query on a row: every term must match.
 *
 * @param terms - The parsed terms.
 * @param row - The row.
 * @returns Whether the row matches.
 */
export function evaluateFilter(terms: readonly FilterTerm[], row: FilterRow): boolean {
  let haystack: string | null = null;
  for (const term of terms) {
    let matched: boolean;
    if (term.kind === "field") {
      matched = matchField(term, row);
    } else {
      haystack ??= haystackOf(row);
      matched = haystack.includes(foldText(term.text));
    }
    if (matched === term.negate) return false;
  }
  return true;
}

/**
 * Writes terms back as query text (the inverse of {@link parseFilter} for valid queries).
 *
 * @param terms - The terms.
 * @returns The query text.
 */
export function serializeFilter(terms: readonly FilterTerm[]): string {
  return terms
    .map((term) => {
      const prefix = term.negate ? "-" : "";
      if (term.kind === "text") return `${prefix}${term.phrase ? `"${term.text}"` : term.text}`;
      if (term.op === "in") return `${prefix}${term.key}:${term.values.join(",")}`;
      if (term.op === "range") return `${prefix}${term.key}:${term.values[0]}..${term.values[1]}`;
      return `${prefix}${term.key}${term.op}${term.values[0]}`;
    })
    .join(" ");
}

/**
 * The free words and phrases of a query (for highlighting hits).
 *
 * @param terms - The terms.
 * @returns The positive texts.
 */
export function highlightTexts(terms: readonly FilterTerm[]): string[] {
  return terms.filter((t): t is TextTerm => t.kind === "text" && !t.negate).map((t) => t.text);
}
