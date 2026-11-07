// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the write channels of feature 371 (research R1-R5; FR-001 - FR-005) against
 * fixture repositories with the real backlog tool and, for the `commit` channel, a real loop
 * (idle, with the fake claude):
 * - `main-ref`: while a run holds the run lock on its branch, a change lands on `main` at once,
 *   the primary tree is untouched, the tray entry is committed;
 * - the frozen item: its own change and an indirect one (closing an item it depends on) are
 *   refused and nothing is changed on `main` or in the side worktree;
 * - `run-on-main`: with the lock held and HEAD on `main` the gate is read-only;
 * - `changed-underneath` when `main` moves between the change's base and its landing;
 * - undo and commit of the tray are refused while a run holds the primary tree;
 * - `commit`: while a loop lives, a change is committed at once and the tray stays empty;
 * - the edit lock held by the loop is never replaced as stale.
 */

import { spawn, type ChildProcess } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import type { BoardView, ChangeResult, ItemRowView, Tray } from "@backlog-app/shared";
import { EditLock } from "../src/backlog/edit-lock.ts";
import { LOOP_PY, TOOLS_DIR } from "../src/context.ts";
import { pythonExecutable } from "../src/proc/spawn.ts";
import { fixtureRepo, gitIn, writeRunLock } from "./helpers/fixture-repo.ts";
import { testApp, type TestApp } from "./helpers/services.ts";

/** The fixture's open item of Next (the loop would take it). */
const FTP = "ftp-per-server-encoding-flag";

/** The fixture's blocked item, which depends on FTP. */
const DISK = "disk-map-context-menu-crash";

/**
 * The first item row of a section.
 *
 * @param board - The board answer.
 * @param section - The section name.
 * @returns The row.
 */
function firstOf(board: BoardView, section: string): ItemRowView {
  const row = board.sections
    .find((s) => s.name === section)
    ?.rows.find((r): r is ItemRowView => r.kind === "item");
  if (!row) throw new Error(`no item in ${section}`);
  return row;
}

/**
 * The item slugs of a section of a board answer.
 *
 * @param board - The board.
 * @param section - The section.
 * @returns The slugs in order.
 */
function rowsOf(board: BoardView, section: string): string[] {
  return (board.sections.find((s) => s.name === section)?.rows ?? [])
    .filter((r): r is ItemRowView => r.kind === "item")
    .map((r) => r.slug);
}

/**
 * The slugs of a section of the board as `main` has it, read through git.
 *
 * @param root - The repository.
 * @param section - The section heading.
 * @returns The slugs in order.
 */
async function mainSection(root: string, section: string): Promise<string[]> {
  // The fixture's copy may carry CRLF (git's text=auto on Windows); the tool writes LF.
  const text = (await gitIn(root, ["show", "main:backlog/BACKLOG.md"])).replaceAll("\r\n", "\n");
  const part = text.split(`## ${section}\n`)[1]?.split("\n## ")[0] ?? "";
  return [...part.matchAll(/\]\(items\/([a-z0-9-]+)\/desc\.md\)/g)].map((m) => m[1]!);
}

describe("write channels (371)", () => {
  let app: TestApp;
  let root = "";
  let cleanup = (): void => undefined;
  let loop: ChildProcess | null = null;

  beforeEach(async () => {
    ({ root, cleanup } = await fixtureRepo());
    app = await testApp(root);
  });

  afterEach(async () => {
    if (loop && loop.exitCode === null) {
      loop.kill();
      await new Promise((resolve) => loop!.once("exit", resolve));
    }
    loop = null;
    await app.services.stopAndDrain();
    cleanup();
  });

  /**
   * Simulates a run of `slug` that is on its branch: the run lock and the primary tree checked
   * out at the branch (as the skill's step 4.5 leaves it).
   *
   * @param slug - The item.
   */
  async function runOnBranch(slug: string): Promise<void> {
    await gitIn(root, ["checkout", "-q", "-b", `345-${slug}`]);
    writeRunLock(root, 0, slug, `345-${slug}`);
    await app.refresh();
  }

  it("lands a change on main while a run holds the lock on its branch, untouched primary tree", async () => {
    await runOnBranch(DISK);
    expect(app.services.gate()).toMatchObject({ state: "free", channel: "main-ref", frozenSlug: DISK });
    const mainBefore = (await gitIn(root, ["rev-parse", "main"])).trim();
    const board = (await app.get("/api/board")).json as BoardView;
    expect(board.ref).toBe("main");
    const item = firstOf(board, "Inbox");
    const answer = await app.post(`/api/items/${item.slug}/move`, {
      base: { board: board.revision },
      section: "Next",
      position: 1,
    });
    expect(answer.status, JSON.stringify(answer.json)).toBe(200);
    const result = answer.json as ChangeResult;
    expect(result.channel).toBe("main-ref");
    expect(result.change).toMatchObject({ state: "committed", channel: "main-ref" });
    expect(result.commit).toMatch(/^[0-9a-f]{40}$/);
    // main moved by exactly one commit of the app's form; the primary tree is untouched.
    const mainAfter = (await gitIn(root, ["rev-parse", "main"])).trim();
    expect(mainAfter).toBe(result.commit);
    expect((await gitIn(root, ["rev-parse", "main~1"])).trim()).toBe(mainBefore);
    expect((await gitIn(root, ["log", "-1", "--format=%s", "main"])).trim()).toMatch(/^backlog\(app\): /);
    expect((await mainSection(root, "Next"))[0]).toBe(item.slug);
    expect(await gitIn(root, ["status", "--porcelain"])).toBe("");
    expect((await gitIn(root, ["rev-parse", "--abbrev-ref", "HEAD"])).trim()).toBe(`345-${DISK}`);
    expect(readFileSync(join(root, "backlog", "BACKLOG.md"), "utf8")).not.toMatch(
      new RegExp(`\\| 1 \\| \\[[^\\]]*\\]\\(items/${item.slug}/`),
    );
    // The board shows the new state of main at once, and the tray lists the commit.
    const after = (await app.get("/api/board")).json as BoardView;
    expect(firstOf(after, "Next").slug).toBe(item.slug);
    expect(after.revision).toBe(result.board);
    const tray = (await app.get("/api/tray")).json as Tray;
    expect(tray.pending).toHaveLength(0);
    expect(tray.committedRecently[0]).toMatchObject({ commit: result.commit, channel: "main-ref" });
    // A second change builds on the first (the revision the answer gave is current).
    const again = await app.post(`/api/items/${item.slug}/log`, {
      base: { board: result.board, item: result.item },
      text: "a note during the run",
    });
    expect(again.status, JSON.stringify(again.json)).toBe(200);
    expect((await gitIn(root, ["rev-parse", "main~2"])).trim()).toBe(mainBefore);
  });

  it("lands a change on main with a CRLF checkout (core.autocrlf true, as on the maintainer's machine)", async () => {
    // The client's revisions are blob hashes (LF); the side worktree checks files out as CRLF.
    await gitIn(root, ["config", "core.autocrlf", "true"]);
    await gitIn(root, ["rm", "-rq", "--cached", "."]);
    await gitIn(root, ["reset", "-q", "--hard"]);
    expect(readFileSync(join(root, "backlog", "BACKLOG.md"), "utf8")).toContain("\r\n");
    await runOnBranch(DISK);
    const board = (await app.get("/api/board")).json as BoardView;
    const item = firstOf(board, "Inbox");
    const answer = await app.post(`/api/items/${item.slug}/move`, {
      base: { board: board.revision },
      section: "Next",
      position: 1,
    });
    expect(answer.status, JSON.stringify(answer.json)).toBe(200);
    const result = answer.json as ChangeResult;
    expect((await mainSection(root, "Next"))[0]).toBe(item.slug);
    // The revisions the answer gives are the ones the next read of main gives.
    const after = (await app.get("/api/board")).json as BoardView;
    expect(after.revision).toBe(result.board);
    const again = await app.post(`/api/items/${item.slug}/log`, {
      base: { board: result.board, item: result.item },
      text: "a second change on CRLF",
    });
    expect(again.status, JSON.stringify(again.json)).toBe(200);
  });

  it("refuses the frozen item's own change and an indirect one, changing nothing", async () => {
    await runOnBranch(DISK);
    const mainBefore = (await gitIn(root, ["rev-parse", "main"])).trim();
    const own = await app.post(`/api/items/${DISK}/unblock`, { base: {}, note: "x" });
    expect(own.status).toBe(409);
    expect((own.json as { error: { code: string } }).error.code).toBe("frozen-item");
    // Closing FTP would drop it from DISK's depends-on list: DISK's file would change.
    const board = (await app.get("/api/board")).json as BoardView;
    const indirect = await app.post(`/api/items/${FTP}/close`, {
      base: { board: board.revision },
      reason: "fixed elsewhere",
    });
    expect(indirect.status).toBe(409);
    expect((indirect.json as { error: { code: string; message: string } }).error).toMatchObject({
      code: "frozen-item",
    });
    expect((indirect.json as { error: { message: string } }).error.message).toContain(DISK);
    expect((await gitIn(root, ["rev-parse", "main"])).trim()).toBe(mainBefore);
    expect(await mainSection(root, "Next")).toContain(FTP);
    // The side worktree is clean again.
    const worktree = app.services.queue.worktree;
    expect(await worktree.changedPaths()).toEqual([]);
    // A reorder naming the frozen item and a bulk change on it are refused too.
    const order = await app.post("/api/sections/next/order", {
      base: { board: board.revision },
      order: [DISK, FTP],
    });
    expect(order.status).toBe(409);
    const bulk = await app.post("/api/bulk", {
      base: {},
      slugs: [DISK],
      operation: { kind: "unblock" },
    });
    expect(bulk.status).toBe(200);
    expect((bulk.json as { results: { ok: boolean; refused?: string }[] }).results[0]).toMatchObject({
      ok: false,
    });
  });

  it("puts the hidden running item back into a reorder of its section", async () => {
    await runOnBranch(DISK);
    const board = (await app.get("/api/board")).json as BoardView;
    const inbox = firstOf(board, "Inbox");
    const placed = await app.post(`/api/items/${inbox.slug}/move`, {
      base: { board: board.revision },
      section: "Next",
      position: 1,
    });
    expect(placed.status, JSON.stringify(placed.json)).toBe(200);
    expect(await mainSection(root, "Next")).toEqual([inbox.slug, DISK, FTP]);
    // The page shows Next without DISK (it is in In progress): [inbox, FTP]; the maintainer puts FTP first.
    const after = (await app.get("/api/board")).json as BoardView;
    expect(rowsOf(after, "Next")).toEqual([inbox.slug, FTP]);
    const ordered = await app.post("/api/sections/next/order", {
      base: { board: after.revision },
      order: [FTP, inbox.slug],
    });
    expect(ordered.status, JSON.stringify(ordered.json)).toBe(200);
    expect(await mainSection(root, "Next")).toEqual([FTP, DISK, inbox.slug]);
  });

  it("counts a moved or new item's position as the page does, without the hidden running item (414)", async () => {
    await runOnBranch(DISK);
    // main's Next is [DISK, FTP]; the page shows [FTP] (DISK is in In progress).
    const board = (await app.get("/api/board")).json as BoardView;
    expect(rowsOf(board, "Next")).toEqual([FTP]);
    const inbox = firstOf(board, "Inbox");
    // Visible position 2 = after FTP. Counted on the files it would be between DISK and FTP.
    const moved = await app.post(`/api/items/${inbox.slug}/move`, {
      base: { board: board.revision },
      section: "Next",
      position: 2,
    });
    expect(moved.status, JSON.stringify(moved.json)).toBe(200);
    expect(await mainSection(root, "Next")).toEqual([DISK, FTP, inbox.slug]);
    let after = (await app.get("/api/board")).json as BoardView;
    expect(rowsOf(after, "Next")).toEqual([FTP, inbox.slug]);
    // A new item at visible position 2: between FTP and the moved item.
    const created = await app.post("/api/items", {
      base: { board: after.revision },
      title: "Placed during a run",
      type: "bug",
      severity: 2,
      area: "tooling",
      problem: "p",
      evidence: "e",
      expected: "x",
      place: { section: "Next", position: 2 },
    });
    expect(created.status, JSON.stringify(created.json)).toBe(200);
    const slug = (created.json as ChangeResult).change!.slugs[0]!;
    after = (await app.get("/api/board")).json as BoardView;
    expect(rowsOf(after, "Next")).toEqual([FTP, slug, inbox.slug]);
    expect(await mainSection(root, "Next")).toEqual([DISK, FTP, slug, inbox.slug]);
  });

  it("is read-only while a run holds the lock with the primary tree on main", async () => {
    writeRunLock(root, 0, DISK, "-");
    await app.refresh();
    expect(app.services.gate()).toMatchObject({ state: "run-on-main", writable: false, frozenSlug: DISK });
    const board = (await app.get("/api/board")).json as BoardView;
    const item = firstOf(board, "Inbox");
    const answer = await app.post(`/api/items/${item.slug}/log`, { base: {}, text: "x" });
    expect(answer.status).toBe(409);
    expect((answer.json as { error: { code: string } }).error.code).toBe("gate-closed");
  });

  it("refuses with changed-underneath when main moves before the change lands, and reverts", async () => {
    await runOnBranch(DISK);
    const worktree = app.services.queue.worktree;
    const realCommit = worktree.commit.bind(worktree);
    // Between the worktree's commit and the swap, main moves (the run's return): the run commits
    // on its branch and fast-forwards main to it.
    worktree.commit = async (paths, message) => {
      const hash = await realCommit(paths, message);
      await gitIn(root, ["commit", "-q", "--allow-empty", "-m", "[345] the run's commit"]);
      await gitIn(root, ["update-ref", "refs/heads/main", (await gitIn(root, ["rev-parse", "HEAD"])).trim()]);
      return hash;
    };
    const board = (await app.get("/api/board")).json as BoardView;
    const item = firstOf(board, "Inbox");
    const answer = await app.post(`/api/items/${item.slug}/log`, {
      base: { board: board.revision },
      text: "x",
    });
    expect(answer.status).toBe(409);
    expect((answer.json as { error: { code: string } }).error.code).toBe("changed-underneath");
    expect((await gitIn(root, ["log", "-1", "--format=%s", "main"])).trim()).not.toMatch(/^backlog\(app\)/);
    expect(await worktree.changedPaths()).toEqual([]);
  });

  it("refuses undo and commit of the tray while a run holds the primary tree", async () => {
    await runOnBranch(DISK);
    const commit = await app.post("/api/tray/commit", { message: "x", includeOutside: [] });
    expect(commit.status).toBe(409);
    const undo = await app.post("/api/tray/undo", { changeId: "none" });
    expect(undo.status).toBe(409);
  });

  it("commits at once while a loop lives (the commit channel)", async () => {
    // Nothing eligible: the loop idles between runs. The fake claude is never called.
    await gitIn(root, ["commit", "-q", "--allow-empty", "-m", "base"]);
    const tool = app.services.tool;
    await tool.change(["block", FTP], { reason: "the test keeps the loop idle" });
    await gitIn(root, ["add", "-A"]);
    await gitIn(root, ["commit", "-q", "-m", "backlog: ftp blocked (test)"]);
    const plan = join(root, "..", `${root.split(/[\\/]/).pop()}-plan.json`);
    writeFileSync(plan, JSON.stringify({ steps: [], calls: [] }));
    loop = spawn(
      pythonExecutable(),
      [
        "-X",
        "utf8",
        LOOP_PY,
        "start",
        "--root",
        root,
        "--claude-cmd",
        JSON.stringify([pythonExecutable(), join(TOOLS_DIR, "fixtures", "fake_claude.py")]),
        "--poll",
        "0.3",
        "--tick",
        "0.05",
        "--deadline",
        "120",
      ],
      {
        stdio: "ignore",
        windowsHide: true,
        env: { ...process.env, FAKE_CLAUDE_PLAN: plan, PYTHONUTF8: "1" },
      },
    );
    const until = Date.now() + 30_000;
    for (;;) {
      await app.refresh();
      if (app.services.loop.view?.live && app.services.loop.view.shown === "idle") break;
      if (Date.now() > until)
        throw new Error(`the loop did not idle: ${JSON.stringify(app.services.loop.view)}`);
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
    expect(app.services.gate()).toMatchObject({ state: "free", channel: "commit", frozenSlug: null });
    const board = (await app.get("/api/board")).json as BoardView;
    const item = firstOf(board, "Inbox");
    const answer = await app.post(`/api/items/${item.slug}/log`, {
      base: { board: board.revision },
      text: "live",
    });
    expect(answer.status, JSON.stringify(answer.json)).toBe(200);
    const result = answer.json as ChangeResult;
    expect(result.channel).toBe("commit");
    expect(result.change).toMatchObject({ state: "committed", channel: "commit" });
    expect((await gitIn(root, ["log", "-1", "--format=%s"])).trim()).toMatch(/^backlog\(app\): /);
    expect(await gitIn(root, ["status", "--porcelain"])).toBe("");
    const tray = (await app.get("/api/tray")).json as Tray;
    expect(tray.pending).toHaveLength(0);
    expect(tray.committedRecently[0]?.commit).toBe(result.commit);
  });
});

describe("edit lock held by the loop (371)", () => {
  let root = "";
  let cleanup = (): void => undefined;

  beforeEach(async () => {
    ({ root, cleanup } = await fixtureRepo());
  });
  afterEach(() => cleanup());

  it("is never replaced as stale while its holder is the live loop", async () => {
    const lock = new EditLock(join(root, ".git"));
    // The loop: a live other process (a sleeping Node child).
    const other = spawn(process.execPath, ["-e", "setTimeout(() => {}, 20000)"], { stdio: "ignore" });
    try {
      const old = Date.now() / 1000 - 3600; // an hour: stale by age for any other holder
      writeFileSync(
        lock.path,
        `pid: ${other.pid}\nstarted_epoch: ${old}\nstarted: x\npurpose: loop: starting a run\n`,
      );
      expect(() => lock.acquire("mine", other.pid ?? null)).toThrow(/the loop is starting a run/);
      expect(lock.holder()?.purpose).toBe("loop: starting a run");
      // Another holder of that age is stale and replaced.
      lock.acquire("mine", null);
      expect(lock.holds()).toBe(true);
      lock.release();
      expect(lock.holds()).toBe(false);
    } finally {
      other.kill();
    }
    await new Promise((resolve) => other.once("exit", resolve));
  });
});
