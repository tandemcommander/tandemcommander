// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the write path (research R9, R11, R12; FR-022 - FR-024, FR-034, FR-035) against
 * fixture repositories with the real backlog tool:
 * - a change through the app leaves exactly the files the same tool command leaves (SC-003);
 * - a closed gate and a stale view refuse and write nothing;
 * - undo restores the files, and refuses when something else changed them since;
 * - the commit stages only the tray's backlog paths, with the `backlog(app):` prefix;
 * - the edit lock refuses a second live holder and replaces a dead one.
 */

import { readFileSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import type { BoardView, ChangeResult, ItemRowView, Tray } from "@backlog-app/shared";
import { BacklogTool } from "../src/backlog/tool.ts";
import { EditLock } from "../src/backlog/edit-lock.ts";
import { fixtureRepo, gitIn } from "./helpers/fixture-repo.ts";
import { testApp, type TestApp } from "./helpers/services.ts";

/**
 * All files under `backlog/` of a repository, by relative path.
 *
 * @param root - The repository root.
 * @returns Path to content.
 */
async function backlogFiles(root: string): Promise<Map<string, string>> {
  const out = await gitIn(root, ["ls-files", "--others", "--cached", "--exclude-standard", "--", "backlog"]);
  const files = new Map<string, string>();
  for (const path of out.split("\n").filter(Boolean)) {
    try {
      files.set(path, readFileSync(join(root, path), "utf8"));
    } catch {
      // Listed by the index but deleted in the tree.
    }
  }
  return files;
}

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

describe("write path", () => {
  let app: TestApp;
  let root = "";
  let cleanup = (): void => undefined;
  let twin = "";
  let cleanupTwin = (): void => undefined;

  beforeEach(async () => {
    ({ root, cleanup } = await fixtureRepo());
    ({ root: twin, cleanup: cleanupTwin } = await fixtureRepo());
    app = await testApp(root);
  });

  afterEach(async () => {
    await app.services.stopAndDrain();
    cleanup();
    cleanupTwin();
  });

  it("opens the gate on main with no loop and no lock", () => {
    expect(app.services.gate()).toMatchObject({ state: "free", writable: true, branch: "main" });
  });

  it("moves an Inbox item exactly like the tool does, records it in the tray, and undoes it", async () => {
    const board = (await app.get("/api/board")).json as BoardView;
    const item = firstOf(board, "Inbox");
    const original = await backlogFiles(root);
    const answer = await app.post(`/api/items/${item.slug}/move`, {
      base: { board: board.revision },
      section: "Next",
      position: 1,
    });
    expect(answer.status, JSON.stringify(answer.json)).toBe(200);
    const result = answer.json as ChangeResult;
    expect(result.ok).toBe(true);
    expect(result.change?.state).toBe("pending");

    // The same command run directly on an identical copy gives identical files (SC-003).
    await new BacklogTool(twin).change(["move", item.slug, "--section", "next", "--position", "1"]);
    const viaApp = await backlogFiles(root);
    const viaTool = await backlogFiles(twin);
    expect([...viaApp.keys()].sort()).toEqual([...viaTool.keys()].sort());
    for (const [path, text] of viaApp) expect(text, path).toBe(viaTool.get(path));
    expect((await app.services.tool.check()).total).toBe(0);

    const tray = (await app.get("/api/tray")).json as Tray;
    expect(tray.pending).toHaveLength(1);
    expect(tray.pending[0]!.files.map((f) => f.path)).toContain("backlog/BACKLOG.md");
    expect(tray.proposedMessage.startsWith("backlog(app): ")).toBe(true);

    const undone = await app.post("/api/tray/undo", { changeId: tray.pending[0]!.id });
    expect(undone.status).toBe(200);
    const restored = await backlogFiles(root);
    expect([...restored.keys()].sort()).toEqual([...original.keys()].sort());
    for (const [path, text] of restored) expect(text, path).toBe(original.get(path));
  });

  it("refuses a change based on a stale view and writes nothing", async () => {
    const board = (await app.get("/api/board")).json as BoardView;
    const item = firstOf(board, "Inbox");
    const before = await backlogFiles(root);
    const answer = await app.post(`/api/items/${item.slug}/move`, {
      base: { board: "0".repeat(64) },
      section: "Next",
    });
    expect(answer.status).toBe(409);
    expect((answer.json as { error: { code: string } }).error.code).toBe("changed-underneath");
    expect(await backlogFiles(root)).toEqual(before);
  });

  it("refuses a refused tool change with 422, the tool's reason, and writes nothing", async () => {
    const board = (await app.get("/api/board")).json as BoardView;
    const item = firstOf(board, "Inbox");
    const before = await backlogFiles(root);
    // Parking needs a reason; the schema lets it through, the tool refuses.
    const answer = await app.post(`/api/items/${item.slug}/move`, {
      base: { board: board.revision },
      section: "Parked",
    });
    expect(answer.status).toBe(422);
    expect((answer.json as { error: { message: string } }).error.message).toMatch(/reason/);
    expect(await backlogFiles(root)).toEqual(before);
    expect(((await app.get("/api/tray")).json as Tray).pending).toHaveLength(0);
  });

  it("closes the gate while a run holds the run lock, and refuses changes", async () => {
    writeFileSync(
      join(root, ".git", "tandem-backlog-run.lock"),
      "started: 2026-10-30T10:00:00\nslug: some-item\nbranch: 345-some-item\nhost: test\n",
    );
    await app.refresh();
    expect(app.services.gate().state).toBe("run-holds-lock");
    expect(app.services.source()).toBe("main");
    const board = (await app.get("/api/board")).json as BoardView;
    expect(board.ref).toBe("main");
    const item = firstOf(board, "Inbox");
    const before = await backlogFiles(root);
    const answer = await app.post(`/api/items/${item.slug}/block`, { base: {}, reason: "waits" });
    expect(answer.status).toBe(409);
    expect((answer.json as { error: { code: string } }).error.code).toBe("gate-closed");
    expect(await backlogFiles(root)).toEqual(before);
  });

  it("closes the gate when the working tree is not on main", async () => {
    await gitIn(root, ["checkout", "-q", "-b", "344-other"]);
    await app.refresh();
    expect(app.services.gate()).toMatchObject({ state: "not-on-main", writable: false });
  });

  it("refuses an undo when the file changed after the change", async () => {
    const board = (await app.get("/api/board")).json as BoardView;
    const item = firstOf(board, "Inbox");
    await app
      .post(`/api/items/${item.slug}/block`, { base: { board: board.revision }, reason: "waits for x" })
      .catch(() => undefined);
    // Inbox items cannot be blocked (only open ones); use a log line instead, which works anywhere.
    const logged = await app.post(`/api/items/${item.slug}/log`, { base: {}, text: "a note" });
    expect(logged.status, JSON.stringify(logged.json)).toBe(200);
    const tray = (await app.get("/api/tray")).json as Tray;
    const newest = tray.pending.at(-1)!;
    const desc = join(root, "backlog", "items", item.slug, "desc.md");
    writeFileSync(desc, `${readFileSync(desc, "utf8")}\n`);
    const undone = await app.post("/api/tray/undo", { changeId: newest.id });
    expect(undone.status).toBe(422);
  });

  it("commits only the tray's backlog paths with the backlog(app) prefix", async () => {
    const board = (await app.get("/api/board")).json as BoardView;
    const item = firstOf(board, "Inbox");
    await app.post(`/api/items/${item.slug}/move`, {
      base: { board: board.revision },
      section: "Next",
      position: 2,
    });
    // An unrelated dirty file must not be committed.
    writeFileSync(join(root, "unrelated.txt"), "not mine\n");
    const tray = (await app.get("/api/tray")).json as Tray;
    const committed = await app.post("/api/tray/commit", {
      message: tray.proposedMessage,
      includeOutside: [],
    });
    expect(committed.status, JSON.stringify(committed.json)).toBe(200);
    const subject = (await gitIn(root, ["log", "-1", "--format=%s"])).trim();
    expect(subject.startsWith("backlog(app): ")).toBe(true);
    const files = (await gitIn(root, ["show", "--name-only", "--format=", "HEAD"]))
      .split("\n")
      .filter(Boolean);
    expect(files.every((f) => f.startsWith("backlog/"))).toBe(true);
    const status = await gitIn(root, ["status", "--porcelain"]);
    expect(status).toContain("unrelated.txt");
    expect(status).not.toContain("backlog/");
    expect(((await app.get("/api/tray")).json as Tray).pending).toHaveLength(0);
  });

  it("refuses to commit when something else is already staged", async () => {
    const board = (await app.get("/api/board")).json as BoardView;
    const item = firstOf(board, "Inbox");
    await app.post(`/api/items/${item.slug}/log`, { base: { board: board.revision }, text: "x" });
    writeFileSync(join(root, "staged.txt"), "someone else's\n");
    await gitIn(root, ["add", "staged.txt"]);
    const tray = (await app.get("/api/tray")).json as Tray;
    const committed = await app.post("/api/tray/commit", {
      message: tray.proposedMessage,
      includeOutside: [],
    });
    expect(committed.status).toBe(422);
  });

  it("stores a new item's long text with shell characters byte-exact (SC-008)", async () => {
    const board = (await app.get("/api/board")).json as BoardView;
    const problem = `${"y".repeat(20_000)}\n\`ls\` $(whoami) & | > < "q" 'q' \\\\ Příliš žluťoučký kůň\n`;
    const answer = await app.post("/api/items", {
      base: { board: board.revision },
      title: "Byte exact text through the app",
      type: "bug",
      severity: 2,
      area: "tooling",
      problem,
      evidence: "e",
      expected: "x",
      place: { section: "Next", position: 1 },
    });
    expect(answer.status, JSON.stringify(answer.json)).toBe(200);
    const slug = (answer.json as ChangeResult).change!.slugs[0]!;
    const item = (await app.get(`/api/items/${slug}`)).json as {
      body: { name: string; markdown: string }[];
      section: string;
      position: number;
    };
    expect(item.body.find((b) => b.name === "Problem")!.markdown.trim()).toBe(problem.trim());
    expect(item.section).toBe("Next");
    expect(item.position).toBe(1);
  });
});

describe("edit lock", () => {
  let root = "";
  let cleanup = (): void => undefined;

  beforeEach(async () => {
    ({ root, cleanup } = await fixtureRepo());
  });
  afterEach(() => cleanup());

  it("refuses while another live process holds it, and replaces a dead holder", async () => {
    const lock = new EditLock(join(root, ".git"));
    // A live other process: a sleeping Node child.
    const other = spawn(process.execPath, ["-e", "setTimeout(() => {}, 20000)"], { stdio: "ignore" });
    try {
      writeFileSync(
        lock.path,
        `pid: ${other.pid}\nstarted_epoch: ${Date.now() / 1000}\nstarted: x\npurpose: other app\n`,
      );
      expect(() => lock.acquire("mine")).toThrow(/another backlog app/);
    } finally {
      other.kill();
    }
    await new Promise((resolve) => other.once("exit", resolve));
    lock.acquire("mine");
    expect(readFileSync(lock.path, "utf8")).toContain(`pid: ${process.pid}`);
    lock.release();
    expect(() => readFileSync(lock.path)).toThrow();
  });
});
