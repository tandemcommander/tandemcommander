// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the running-item overlay (feature 371, research R6; FR-008 - FR-010): while a
 * run holds the run lock, the board read from `main` shows the item in *In progress* with the
 * run's feature, not in *Next*; the counts follow; "next up" names the next eligible item; the
 * item detail says *In progress*; once the lock is gone the board is `main`'s again. The pure
 * overlay is tested on its own with a hand-made board.
 */

import { rmSync } from "node:fs";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import type { Board, BoardView, Item, ItemRowView, NextUp } from "@backlog-app/shared";
import { overlayRunning } from "../src/backlog/read-model.ts";
import { fixtureRepo, gitIn, writeRunLock } from "./helpers/fixture-repo.ts";
import { testApp, type TestApp } from "./helpers/services.ts";

/** The fixture's open item of Next (#2; #1 is blocked). */
const FTP = "ftp-per-server-encoding-flag";

/** The fixture's blocked item (Next #1). */
const DISK = "disk-map-context-menu-crash";

/**
 * The item rows of a section.
 *
 * @param board - The board answer.
 * @param section - The section.
 * @returns The rows.
 */
function rowsOf(board: BoardView, section: string): ItemRowView[] {
  return (board.sections.find((s) => s.name === section)?.rows ?? []).filter(
    (r): r is ItemRowView => r.kind === "item",
  );
}

describe("running-item overlay", () => {
  let app: TestApp;
  let root = "";
  let cleanup = (): void => undefined;

  beforeEach(async () => {
    ({ root, cleanup } = await fixtureRepo());
    app = await testApp(root);
  });

  afterEach(async () => {
    await app.services.stopAndDrain();
    cleanup();
  });

  it("shows the running item in In progress with its feature, not in Next, and next up without it", async () => {
    const before = (await app.get("/api/board")).json as BoardView;
    expect(rowsOf(before, "Next").map((r) => r.slug)).toEqual([DISK, FTP]);
    expect(before.next.slug).toBe(FTP);
    expect(before.running).toBeNull();
    const inProgressBefore = rowsOf(before, "In progress").length;

    await gitIn(root, ["checkout", "-q", "-b", `372-${FTP}`]);
    writeRunLock(root, 0, FTP, `372-${FTP}`);
    await app.refresh();
    const board = (await app.get("/api/board")).json as BoardView;
    expect(board.ref).toBe("main");
    expect(board.running).toMatchObject({ slug: FTP, branch: `372-${FTP}`, feature: "372" });
    const progress = rowsOf(board, "In progress");
    expect(progress.length).toBe(inProgressBefore + 1);
    expect(progress[0]).toMatchObject({ slug: FTP, status: "in-progress", feature: "372", position: 1 });
    expect(progress.map((r) => r.position)).toEqual(progress.map((_, i) => i + 1));
    expect(board.sections.find((s) => s.name === "In progress")?.total).toBe(inProgressBefore + 1);
    const next = rowsOf(board, "Next");
    expect(next.map((r) => r.slug)).toEqual([DISK]);
    expect(next[0]?.position).toBe(1);
    // Next up: FTP is excluded; DISK is blocked; nothing else is eligible.
    expect(board.next.slug).toBeNull();
    expect(board.next.skipped.map((s) => s.slug)).toEqual([DISK]);
    expect(((await app.get("/api/next")).json as NextUp).slug).toBeNull();
    // The item detail says In progress.
    const item = (await app.get(`/api/items/${FTP}`)).json as Item;
    expect(item).toMatchObject({ section: "In progress", position: 1, status: "in-progress", feature: "372" });

    // The lock goes: main's board again, FTP open in Next.
    rmSync(join(root, ".git", "tandem-backlog-run.lock"));
    await app.refresh();
    const after = (await app.get("/api/board")).json as BoardView;
    expect(after.running).toBeNull();
    expect(rowsOf(after, "Next").map((r) => r.slug)).toEqual([DISK, FTP]);
    expect(after.next.slug).toBe(FTP);
    expect(((await app.get(`/api/items/${FTP}`)).json as Item).section).toBe("Next");
  });

  it("keeps a lock without a branch as running without a feature number", async () => {
    writeRunLock(root, 0, FTP, "-");
    await app.refresh();
    const board = (await app.get("/api/board")).json as BoardView;
    expect(board.running).toMatchObject({ slug: FTP, branch: "-", feature: null });
    expect(rowsOf(board, "In progress")[0]).toMatchObject({ slug: FTP, feature: null });
  });
});

describe("overlayRunning (pure)", () => {
  /**
   * An item row.
   *
   * @param slug - The slug.
   * @param position - Its position.
   * @returns The row.
   */
  const row = (slug: string, position: number | null) => ({
    kind: "item" as const,
    slug,
    title: slug,
    type: "bug",
    status: "open",
    severity: 3,
    area: "a",
    source: "manual",
    who: "agent",
    created: "2026-01-01",
    updated: "2026-01-01",
    verified: null,
    effort: "S",
    feature: null,
    related: [],
    dependsOn: [],
    reason: null,
    position,
  });
  const board: Board = {
    revision: "r",
    ref: "main",
    lastTriaged: null,
    unreadable: [],
    running: null,
    sections: [
      { name: "In progress", ordered: true, rows: [row("busy", 1)] },
      { name: "Next", ordered: true, rows: [{ kind: "note", note: "a note" }, row("a", 1), row("b", 2), row("c", 3)] },
      { name: "Inbox", ordered: false, rows: [row("d", null)] },
    ],
  };

  it("moves the row to the top of In progress and renumbers both sections", () => {
    const out = overlayRunning(board, { slug: "b", branch: "371-b", feature: "371", started: "x" });
    const progress = out.sections[0]!.rows;
    expect(progress.map((r) => (r.kind === "item" ? [r.slug, r.position, r.status, r.feature] : r))).toEqual([
      ["b", 1, "in-progress", "371"],
      ["busy", 2, "open", null],
    ]);
    expect(out.sections[1]!.rows.map((r) => (r.kind === "item" ? [r.slug, r.position] : "note"))).toEqual([
      "note",
      ["a", 1],
      ["c", 2],
    ]);
    expect(out.running?.slug).toBe("b");
    // The input is not changed.
    expect(board.sections[1]!.rows.length).toBe(4);
  });

  it("leaves the board as it is without a running item, or with one the board does not know", () => {
    expect(overlayRunning(board, null).sections).toBe(board.sections);
    const out = overlayRunning(board, { slug: "zzz", branch: "-", feature: null, started: "x" });
    expect(out.sections.map((s) => s.rows.length)).toEqual([1, 4, 1]);
    expect(out.running?.slug).toBe("zzz");
  });
});
