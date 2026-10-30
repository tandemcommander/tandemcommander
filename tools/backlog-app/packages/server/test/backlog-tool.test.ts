// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the backlog tool adapter against a fixture repository: the read commands give the
 * shapes of `@backlog-app/shared`, `--ref main` reads git objects, user text travels byte-exact on
 * stdin, a refusal writes nothing and is reported as `refused`.
 */

import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { ApiError, type ItemRow } from "@backlog-app/shared";
import { BacklogTool } from "../src/backlog/tool.ts";
import { fixtureRepo } from "./helpers/fixture-repo.ts";

describe("BacklogTool", () => {
  let root = "";
  let cleanup = (): void => undefined;
  let tool: BacklogTool;

  beforeAll(async () => {
    ({ root, cleanup } = await fixtureRepo());
    tool = new BacklogTool(root);
  });

  afterAll(() => cleanup());

  it("reads the board with all seven sections in order", async () => {
    const board = await tool.board("worktree");
    expect(board.sections.map((s) => s.name)).toEqual([
      "In progress",
      "Next",
      "Decisions for the maintainer",
      "Person steps",
      "Inbox",
      "Parked",
      "Rejected",
    ]);
    expect(board.revision).toMatch(/^[0-9a-f]{64}$/);
    const items = board.sections.flatMap((s) => s.rows).filter((r): r is ItemRow => r.kind === "item");
    expect(items.length).toBeGreaterThan(5);
    for (const item of items) expect(Number.isInteger(item.severity)).toBe(true);
  });

  it("reads one item with its body, log and eligibility", async () => {
    const board = await tool.board("worktree");
    const first = board.sections.flatMap((s) => s.rows).find((r): r is ItemRow => r.kind === "item");
    expect(first).toBeDefined();
    const item = await tool.show(first!.slug, "worktree");
    expect(item.slug).toBe(first!.slug);
    expect(item.revision).toMatch(/^[0-9a-f]{64}$/);
    expect(item.body.length).toBeGreaterThan(0);
    expect(item.log.length).toBeGreaterThan(0);
  });

  it("reads the issue head and reply state of a GitHub-imported item", async () => {
    const board = await tool.board("worktree");
    const github = board.sections
      .flatMap((s) => s.rows)
      .find((r): r is ItemRow => r.kind === "item" && r.source.startsWith("github#"));
    expect(github, "the fixture has a github#N item").toBeDefined();
    const item = await tool.show(github!.slug, "worktree");
    expect(item.files.issue).not.toBeNull();
    expect(typeof item.files.issue?.head).toBe("object");
    expect(item.files.reply?.state).toMatch(/sent/);
  });

  it("reports an unknown item as not found", async () => {
    await expect(tool.show("no-such-item-here", "worktree")).rejects.toMatchObject({ code: "not-found" });
  });

  it("reads the legend with the vocabulary of every field", async () => {
    const legend = await tool.legend("worktree");
    expect(legend.types.map((t) => t.value)).toContain("bug");
    expect(legend.areas.length).toBeGreaterThan(5);
    expect(legend.sources.map((s) => s.value)).toContain("manual");
  });

  it("checks the fixture clean and answers next-up", async () => {
    expect((await tool.check()).total).toBe(0);
    const next = await tool.next("worktree");
    expect(next).toHaveProperty("skipped");
  });

  it("reads main's git objects with ref main, not the working tree", async () => {
    const overview = join(root, "backlog", "BACKLOG.md");
    const before = readFileSync(overview);
    // Damage the working copy: a worktree read changes, a main read must not.
    writeFileSync(overview, `${before.toString("utf8")}\n<!-- uncommitted -->\n`);
    try {
      const fromMain = await tool.board("main");
      const fromTree = await tool.board("worktree");
      expect(fromMain.ref).toBe("main");
      expect(fromMain.revision).not.toBe(fromTree.revision);
    } finally {
      writeFileSync(overview, before);
    }
  });

  it("creates an item with shell characters and 20,000 characters byte-exact (stdin, not argv)", async () => {
    const problem = `${"x".repeat(19_000)}\n\`backticks\` $(rm -rf x) "quotes" 'single' \\\\back\\slash\nČeský text — žluťoučký kůň\n`;
    const change = await tool.change(["new", "--type", "bug", "--severity", "3", "--area", "tooling"], {
      title: "A test item with a long problem text",
      problem,
      evidence: "none",
      expected: "kept exactly",
    });
    expect(change.ok).toBe(true);
    const slug = change.slugs[0]!;
    expect(change.written.some((p) => p.endsWith(`${slug}/desc.md`))).toBe(true);
    const item = await tool.show(slug, "worktree");
    const stored = item.body.find((b) => b.name === "Problem")?.markdown ?? "";
    expect(stored.trim()).toBe(problem.trim());
  });

  it("reports a refusal as refused and writes nothing", async () => {
    const overview = join(root, "backlog", "BACKLOG.md");
    const before = readFileSync(overview, "utf8");
    const board = await tool.board("worktree");
    const inbox = board.sections
      .find((s) => s.name === "Inbox")!
      .rows.find((r): r is ItemRow => r.kind === "item");
    expect(inbox).toBeDefined();
    // Parking without a reason is refused by the tool.
    const error = await tool.change(["move", inbox!.slug, "--section", "parked"]).catch((e: unknown) => e);
    expect(error).toBeInstanceOf(ApiError);
    expect((error as ApiError).code).toMatch(/refused|invalid-request/);
    expect(readFileSync(overview, "utf8")).toBe(before);
  });
});
