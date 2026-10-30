// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the protections of the write path that the independent review found untested
 * (review M3, M1, M2, S2, S3), each with a fixture repository and the real backlog tool:
 * - the edit lock is held while the tool writes and released afterwards, also after a refusal;
 * - a change based on a stale item revision is refused and writes nothing;
 * - only the newest change can be undone, and an undo goes through the queue and the gate;
 * - an undo whose saved state is missing or names a path outside `backlog/` refuses and writes
 *   nothing outside `backlog/`;
 * - the commit refuses a tray file changed outside the app after the app's change, and never
 *   commits a path outside `backlog/` even from a damaged tray;
 * - a tool call that fails after writing leaves its files in the tray (undoable);
 * - item files are served only from the tool's listing (security rule 7);
 * - the loop monitor's fresh view comes from a poll started after the request;
 * - an answer of a change already shows the change (the read model is fresh).
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { z } from "zod";
import { ApiError, type BoardView, type Change, type ItemRowView, type Tray } from "@backlog-app/shared";
import { EDIT_LOCK_FILE } from "../src/backlog/edit-lock.ts";
import type { BacklogTool } from "../src/backlog/tool.ts";
import { isBacklogPath, toolChangeForTray } from "../src/backlog/tray.ts";
import { fixtureRepo, gitIn } from "./helpers/fixture-repo.ts";
import { testApp, type TestApp } from "./helpers/services.ts";

/** An Inbox item of the fixture (log lines can be added to it). */
const ITEM = "ship-network-plugin";

/** Another item of the fixture. */
const OTHER = "typed-path-with-a-pipe-brackets";

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

/** An API answer as the test app returns it. */
interface AnswerBody {
  /** The parsed body. */
  json: unknown;
}

/**
 * The error code of an answer.
 *
 * @param answer - The answer (its `json` body).
 * @returns The code, or undefined.
 */
function codeOf(answer: AnswerBody): string | undefined {
  return (answer.json as { error?: { code?: string } } | null)?.error?.code;
}

describe("write path protections", () => {
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

  /**
   * Adds a log line to an item through the API.
   *
   * @param slug - The item.
   * @param text - The line.
   * @returns The tray entry of the change.
   */
  const log = async (slug: string, text: string): Promise<Change> => {
    const answer = await app.post(`/api/items/${slug}/log`, { base: {}, text });
    expect(answer.status, JSON.stringify(answer.json)).toBe(200);
    return (answer.json as { change: Change }).change;
  };

  it("holds the edit lock while a change runs and releases it afterwards, also after a refusal", async () => {
    const lockPath = join(root, ".git", EDIT_LOCK_FILE);
    const seen = await app.services.queue.run("probe", null, null, () =>
      Promise.resolve(existsSync(lockPath) ? readFileSync(lockPath, "utf8") : null),
    );
    expect(seen).toContain(`pid: ${process.pid}`);
    expect(existsSync(lockPath)).toBe(false);
    // A refused change (closed gate) releases it as well.
    writeFileSync(
      join(root, ".git", "tandem-backlog-run.lock"),
      "started: 2026-10-30T10:00:00\nslug: x\nbranch: 345-x\nhost: test\n",
    );
    const refused = await app.post(`/api/items/${ITEM}/log`, { base: {}, text: "x" });
    expect(codeOf(refused)).toBe("gate-closed");
    expect(existsSync(lockPath)).toBe(false);
  });

  it("refuses a change based on a stale item revision and writes nothing", async () => {
    const desc = join(root, "backlog", "items", ITEM, "desc.md");
    const before = readFileSync(desc, "utf8");
    const answer = await app.post(`/api/items/${ITEM}/log`, { base: { item: "0".repeat(64) }, text: "x" });
    expect(answer.status).toBe(409);
    expect(codeOf(answer)).toBe("changed-underneath");
    expect(readFileSync(desc, "utf8")).toBe(before);
  });

  it("undoes only the newest change", async () => {
    const older = await log(ITEM, "first");
    await log(OTHER, "second");
    const desc = join(root, "backlog", "items", ITEM, "desc.md");
    const before = readFileSync(desc, "utf8");
    const answer = await app.post("/api/tray/undo", { changeId: older.id });
    expect(answer.status).toBe(422);
    expect(readFileSync(desc, "utf8")).toBe(before);
  });

  it("refuses an undo while the gate is closed and leaves the files", async () => {
    const change = await log(ITEM, "a note");
    const desc = join(root, "backlog", "items", ITEM, "desc.md");
    const before = readFileSync(desc, "utf8");
    writeFileSync(
      join(root, ".git", "tandem-backlog-run.lock"),
      "started: 2026-10-30T10:00:00\nslug: x\nbranch: 345-x\nhost: test\n",
    );
    const answer = await app.post("/api/tray/undo", { changeId: change.id });
    expect(codeOf(answer)).toBe("gate-closed");
    expect(readFileSync(desc, "utf8")).toBe(before);
  });

  it("refuses an undo whose saved state is missing, and keeps the change pending", async () => {
    const change = await log(ITEM, "a note");
    app.services.ctx.state.remove(`undo/${change.id}.json`);
    const answer = await app.post("/api/tray/undo", { changeId: change.id });
    expect(answer.status).toBe(422);
    const tray = (await app.get("/api/tray")).json as Tray;
    expect(tray.pending.map((c) => c.id)).toContain(change.id);
  });

  it("refuses an undo whose saved state names a path outside backlog/", async () => {
    const change = await log(ITEM, "a note");
    const path = change.files[0]!.path;
    // A damaged (or planted) undo file: the same path count, one path elsewhere.
    app.services.ctx.state.writeJson(`undo/${change.id}.json`, [
      { path: "planted.txt", before: Buffer.from("planted\n").toString("base64") },
      ...change.files.slice(1).map((f) => ({ path: f.path, before: null })),
    ]);
    const answer = await app.post("/api/tray/undo", { changeId: change.id });
    expect(answer.status).toBe(422);
    expect(existsSync(join(root, "planted.txt"))).toBe(false);
    expect(path.startsWith("backlog/")).toBe(true);
  });

  it("refuses to commit a tray file that was changed outside the app afterwards", async () => {
    await log(ITEM, "a note");
    const desc = join(root, "backlog", "items", ITEM, "desc.md");
    writeFileSync(desc, `${readFileSync(desc, "utf8")}an edit in the terminal\n`);
    const tray = (await app.get("/api/tray")).json as Tray;
    const answer = await app.post("/api/tray/commit", { message: tray.proposedMessage, includeOutside: [] });
    expect(answer.status).toBe(422);
    expect((await gitIn(root, ["log", "-1", "--format=%s"])).startsWith("backlog(app)")).toBe(false);
  });

  it("never commits a path outside backlog/, even from a damaged tray", async () => {
    await log(ITEM, "a note");
    writeFileSync(join(root, "planted.txt"), "planted\n");
    const entries = app.services.ctx.state.readJson("tray.json", z.array(z.unknown()), []) as Change[];
    entries[0]!.files.push({ path: "planted.txt", before: null, after: null });
    app.services.ctx.state.writeJson("tray.json", entries);
    const tray = (await app.get("/api/tray")).json as Tray;
    await app.post("/api/tray/commit", { message: tray.proposedMessage, includeOutside: ["planted.txt"] });
    const committed = await gitIn(root, ["show", "--name-only", "--format=", "HEAD"]);
    expect(committed).not.toContain("planted.txt");
  });

  it("records the files a failing tool call wrote, so they can be undone", async () => {
    const written = join(root, "backlog", "items", ITEM, "evidence", "partial.txt");
    const failing = {
      change: () => {
        mkdirSync(join(root, "backlog", "items", ITEM, "evidence"), { recursive: true });
        writeFileSync(written, "half\n");
        return Promise.reject(new ApiError("tool-failed", "killed by its time limit"));
      },
    } as unknown as BacklogTool;
    const tray = app.services.tray;
    await expect(
      app.services.queue.run("probe", null, null, () =>
        toolChangeForTray(
          tray,
          failing,
          ["log", ITEM],
          {},
          {
            operation: "log",
            slugs: [ITEM],
            summary: "log",
            reason: null,
          },
        ),
      ),
    ).rejects.toThrow("killed by its time limit");
    const pending = tray.pending();
    expect(pending).toHaveLength(1);
    expect(pending[0]!.summary).toContain("failed partway");
    expect(pending[0]!.files.map((f) => f.path)).toEqual([`backlog/items/${ITEM}/evidence/partial.txt`]);
    const undone = await app.post("/api/tray/undo", { changeId: pending[0]!.id });
    expect(undone.status, JSON.stringify(undone.json)).toBe(200);
    expect(existsSync(written)).toBe(false);
  });

  it("serves an item's files only from the tool's listing", async () => {
    const folder = join(root, "backlog", "items", ITEM);
    mkdirSync(join(folder, "evidence"), { recursive: true });
    writeFileSync(join(folder, "evidence", "trace.txt"), "evidence\n");
    writeFileSync(join(folder, "notes.txt"), "not listed\n");
    await app.services.read.fresh();
    expect((await app.get(`/api/items/${ITEM}/files/trace.txt`)).status).toBe(200);
    expect((await app.get(`/api/items/${ITEM}/files/notes.txt`)).status).toBe(404);
    expect((await app.get(`/api/items/${ITEM}/files/desc.md`)).status).toBe(404);
    expect((await app.get(`/api/items/${ITEM}/files/..%2F..%2FBACKLOG.md`)).status).toBe(404);
  });

  it("answers a change only once the board shows it", async () => {
    const board = (await app.get("/api/board")).json as BoardView;
    const item = firstOf(board, "Inbox");
    const moved = await app.post(`/api/items/${item.slug}/move`, {
      base: { board: board.revision },
      section: "Next",
      position: 1,
    });
    expect(moved.status, JSON.stringify(moved.json)).toBe(200);
    const after = (await app.get("/api/board")).json as BoardView;
    expect(after.revision).toBe((moved.json as { board: string }).board);
    expect(firstOf(after, "Next").slug).toBe(item.slug);
  });
});

describe("isBacklogPath", () => {
  it("accepts paths inside backlog/ only", () => {
    expect(isBacklogPath("backlog/BACKLOG.md")).toBe(true);
    expect(isBacklogPath("backlog/items/a/desc.md")).toBe(true);
    for (const bad of [
      "backlog",
      "backlog/",
      "backlog/../x",
      "backlog/./x",
      "backlog//x",
      "backlog/a\\..\\..\\x",
      "backlog/C:/x",
      "src/x",
      "/backlog/x",
    ]) {
      expect(isBacklogPath(bad), bad).toBe(false);
    }
  });
});

describe("LoopMonitor.fresh", () => {
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

  it("waits for a poll in flight and polls again", async () => {
    const monitor = app.services.loop as unknown as { poll: () => Promise<unknown> };
    const original = monitor.poll.bind(app.services.loop);
    const started: number[] = [];
    let release: () => void = () => undefined;
    monitor.poll = async () => {
      started.push(Date.now());
      if (started.length === 1) await new Promise<void>((r) => (release = r));
      return original();
    };
    const inFlight = app.services.loop.refresh();
    const fresh = app.services.loop.fresh();
    // refresh() while the slow poll runs returns at once with the old view and starts nothing.
    await app.services.loop.refresh();
    expect(started).toHaveLength(1);
    release();
    await Promise.all([inFlight, fresh]);
    // fresh() polled once more after the slow poll ended.
    expect(started).toHaveLength(2);
  });
});
