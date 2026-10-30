// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the filter language (research R20, analysis A4 §2.4): parsing, validation against
 * the legend, evaluation on board rows, and serialisation back into the box and the address.
 */

import { describe, expect, it } from "vitest";
import { evaluateFilter, parseFilter, serializeFilter, type FilterRow } from "../src/query/filter-language.ts";
import type { Legend } from "../src/schemas/backlog.ts";

/** A small legend with the vocabulary the tests use. */
const legend: Legend = {
  types: ["bug", "feature", "improvement", "tech-debt", "decision", "person-step"].map((value) => ({ value, meaning: "" })),
  statuses: ["new", "open", "blocked", "in-progress", "parked", "rejected"].map((value) => ({ value, meaning: "" })),
  areas: ["encoding", "archives", "ftp", "tooling"].map((value) => ({ value, meaning: "" })),
  who: ["agent", "person", "both"].map((value) => ({ value, meaning: "" })),
  efforts: ["S", "M", "L", "?"].map((value) => ({ value, meaning: "" })),
  sources: ["manual", "github#N", "review:NNN"].map((value) => ({ value, meaning: "" })),
  severity: [],
};

/**
 * A board row with defaults.
 *
 * @param patch - Fields to override.
 * @returns The row.
 */
function row(patch: Partial<FilterRow> = {}): FilterRow {
  return {
    kind: "item",
    slug: "an-item",
    title: "An item",
    type: "bug",
    status: "open",
    severity: 5,
    area: "encoding",
    source: "review:300",
    who: "agent",
    created: "2026-10-20",
    updated: "2026-10-22",
    verified: null,
    effort: "S",
    feature: null,
    related: [],
    dependsOn: [],
    reason: null,
    position: 1,
    section: "Next",
    ...patch,
  };
}

describe("parseFilter", () => {
  it("splits keys, lists, comparisons, ranges, phrases, negations and free words", () => {
    const parsed = parseFilter('type:bug,improvement sev>=5 area:encoding -"not reproduced" code page', legend);
    expect(parsed.errors).toEqual([]);
    expect(parsed.terms).toEqual([
      { kind: "field", key: "type", op: "in", values: ["bug", "improvement"], negate: false },
      { kind: "field", key: "sev", op: ">=", values: ["5"], negate: false },
      { kind: "field", key: "area", op: "in", values: ["encoding"], negate: false },
      { kind: "text", text: "not reproduced", phrase: true, negate: true },
      { kind: "text", text: "code", phrase: false, negate: false },
      { kind: "text", text: "page", phrase: false, negate: false },
    ]);
  });

  it("parses a severity range", () => {
    const parsed = parseFilter("sev:4..6", legend);
    expect(parsed.terms).toEqual([{ kind: "field", key: "sev", op: "range", values: ["4", "6"], negate: false }]);
  });

  it("reports unknown keys and values outside the legend as errors, never ignoring them", () => {
    const parsed = parseFilter("colour:red area:nowhere type:bug sev>=eleven", legend);
    expect(parsed.errors.map((e) => e.token)).toEqual(["colour:red", "area:nowhere", "sev>=eleven"]);
    expect(parsed.terms).toHaveLength(1);
  });

  it("accepts an empty query", () => {
    expect(parseFilter("   ", legend)).toEqual({ terms: [], errors: [] });
  });

  it("keeps an unclosed quote as a phrase to the end", () => {
    expect(parseFilter('"code page', legend).terms).toEqual([{ kind: "text", text: "code page", phrase: true, negate: false }]);
  });
});

describe("evaluateFilter", () => {
  it("matches every field condition", () => {
    const q = parseFilter("type:bug sev>=5 area:encoding who:agent effort:S,M status:open section:next", legend);
    expect(evaluateFilter(q.terms, row())).toBe(true);
    expect(evaluateFilter(q.terms, row({ severity: 4 }))).toBe(false);
    expect(evaluateFilter(q.terms, row({ area: "ftp" }))).toBe(false);
    expect(evaluateFilter(q.terms, row({ effort: "L" }))).toBe(false);
    expect(evaluateFilter(q.terms, row({ section: "Inbox" }))).toBe(false);
  });

  it("evaluates ranges, negations and dates", () => {
    expect(evaluateFilter(parseFilter("sev:4..6", legend).terms, row({ severity: 6 }))).toBe(true);
    expect(evaluateFilter(parseFilter("sev:4..6", legend).terms, row({ severity: 7 }))).toBe(false);
    expect(evaluateFilter(parseFilter("-area:encoding", legend).terms, row())).toBe(false);
    expect(evaluateFilter(parseFilter("created>=2026-10-20", legend).terms, row())).toBe(true);
    expect(evaluateFilter(parseFilter("created>2026-10-20", legend).terms, row())).toBe(false);
  });

  it("evaluates source prefixes and the is:/has: words", () => {
    expect(evaluateFilter(parseFilter("source:review", legend).terms, row())).toBe(true);
    expect(evaluateFilter(parseFilter("source:review:*", legend).terms, row())).toBe(true);
    expect(evaluateFilter(parseFilter("source:github", legend).terms, row())).toBe(false);
    expect(evaluateFilter(parseFilter("is:github", legend).terms, row({ source: "github#12" }))).toBe(true);
    expect(evaluateFilter(parseFilter("is:blocked", legend).terms, row({ status: "blocked" }))).toBe(true);
    expect(evaluateFilter(parseFilter("has:deps", legend).terms, row({ dependsOn: ["x"] }))).toBe(true);
    expect(evaluateFilter(parseFilter("has:deps", legend).terms, row())).toBe(false);
  });

  it("evaluates verification and relations", () => {
    expect(evaluateFilter(parseFilter("verified:none", legend).terms, row())).toBe(true);
    const verified = row({ verified: { date: "2026-09-20", commit: "abc1234" } });
    expect(evaluateFilter(parseFilter("verified:none", legend).terms, verified)).toBe(false);
    expect(evaluateFilter(parseFilter("verified<2026-10-01", legend).terms, verified)).toBe(true);
    expect(evaluateFilter(parseFilter("related:other", legend).terms, row({ related: ["other"] }))).toBe(true);
    expect(evaluateFilter(parseFilter("needs:base-item", legend).terms, row({ dependsOn: ["base-item"] }))).toBe(true);
    expect(evaluateFilter(parseFilter("feature:341", legend).terms, row({ feature: "341" }))).toBe(true);
  });

  it("matches free words and phrases in the title, case- and accent-insensitively", () => {
    const czech = row({ title: "Žluťoučký kůň: code page names" });
    expect(evaluateFilter(parseFilter("zlutoucky", legend).terms, czech)).toBe(true);
    expect(evaluateFilter(parseFilter('"code page"', legend).terms, czech)).toBe(true);
    expect(evaluateFilter(parseFilter('"page code"', legend).terms, czech)).toBe(false);
    expect(evaluateFilter(parseFilter("-kun", legend).terms, czech)).toBe(false);
  });

  it("matches free words in the body when the row carries one", () => {
    const withBody = row({ body: "The panel shows question marks." });
    expect(evaluateFilter(parseFilter("question", legend).terms, withBody)).toBe(true);
  });
});

describe("serializeFilter", () => {
  it("round-trips a parsed query", () => {
    const text = 'type:bug,improvement sev>=5 sev:4..6 -area:ftp -"not reproduced" code';
    const parsed = parseFilter(text, legend);
    expect(serializeFilter(parsed.terms)).toBe(text);
    expect(parseFilter(serializeFilter(parsed.terms), legend)).toEqual(parsed);
  });
});
