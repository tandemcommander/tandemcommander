// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The soak of feature 371 (SC-002, SC-007; research R11), opt-in with `BACKLOG_APP_SOAK=1`
 * because it takes minutes: a real loop at a 50 ms tick with the fake claude while the test app
 * makes changes.
 * - SC-007: 200 changes while the loop runs 20 short runs - every change lands on main,
 *   and no run saw a dirty tree at its start (the fake records `git status` when it starts).
 * - SC-002: 20 `branch-hang` runs with 3 changes made during each run's branch phase - every
 *   change is on main at the end, every run closed, the check is clean.
 */

import { spawn, type ChildProcess } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import type { BoardView, ChangeResult } from "@backlog-app/shared";
import { LOOP_PY, TOOLS_DIR } from "../src/context.ts";
import { pythonExecutable } from "../src/proc/spawn.ts";
import { fixtureRepo, gitIn } from "./helpers/fixture-repo.ts";
import { testApp, type TestApp } from "./helpers/services.ts";

/** The fixture's decision item: never taken by a run, so a log line on it is a safe change. */
const DECISION = "ship-network-plugin";

/** The fixture's blocked item of Next (it stays; the extra items run). */
const DISK = "disk-map-context-menu-crash";

/** The fixture's open item of Next (blocked by the soak, so the runs take the soak items). */
const FTP = "ftp-per-server-encoding-flag";

const soak = process.env["BACKLOG_APP_SOAK"] === "1" ? describe : describe.skip;

soak("write race soak (371)", () => {
  let app: TestApp;
  let root = "";
  let cleanup = (): void => undefined;
  let loop: ChildProcess | null = null;
  let plan = "";

  beforeEach(async () => {
    ({ root, cleanup } = await fixtureRepo());
    app = await testApp(root);
    plan = join(root, "..", `${root.split(/[\\/]/).pop()}-plan.json`);
  });

  afterEach(async () => {
    if (loop && loop.exitCode === null) {
      loop.kill();
      await new Promise((resolve) => loop!.once("exit", resolve));
    }
    loop = null;
    await app.services.stopAndDrain();
    // `BACKLOG_APP_KEEP=1` keeps the fixture (its loop log is the evidence of a failed soak).
    if (process.env["BACKLOG_APP_KEEP"] === "1") console.log(`fixture kept: ${root}`);
    else cleanup();
  });

  /**
   * Adds eligible items to Next (the runs take them one by one) and commits.
   *
   * @param n - How many.
   */
  async function addItems(n: number): Promise<void> {
    const tool = app.services.tool;
    // The fixture's own eligible item would be the first run: blocked, so the runs are the soak items.
    await tool.change(["block", FTP], { reason: "the soak runs its own items" });
    for (let i = 1; i <= n; i++) {
      const slug = `soak-item-${i}`;
      await tool.change(["new", "--type", "bug", "--severity", "3", "--area", "tooling", "--slug", slug], {
        title: `Soak item ${i}`,
        problem: "p",
        evidence: "e",
        expected: "x",
      });
      await tool.change(["move", slug, "--section", "next"]);
    }
    // The blocked fixture item stays first; the loop skips it.
    await gitIn(root, ["add", "-A"]);
    await gitIn(root, ["commit", "-q", "-m", "backlog: soak items"]);
  }

  /**
   * Starts the loop (foreground process, fast ticks) with a plan.
   *
   * @param steps - The fake claude's steps.
   * @param untilIdle - End the loop when nothing is eligible (else it idles).
   */
  function startLoop(steps: unknown[], untilIdle = true): void {
    writeFileSync(plan, JSON.stringify({ steps, calls: [] }));
    loop = spawn(
      pythonExecutable(),
      [
        "-X",
        "utf8",
        LOOP_PY,
        "start",
        "--root",
        root,
        ...(untilIdle ? ["--until-idle"] : []),
        "--claude-cmd",
        JSON.stringify([pythonExecutable(), join(TOOLS_DIR, "fixtures", "fake_claude.py")]),
        "--poll",
        "0.2",
        "--tick",
        "0.05",
        "--deadline",
        "900",
      ],
      {
        stdio: "ignore",
        windowsHide: true,
        env: { ...process.env, FAKE_CLAUDE_PLAN: plan, PYTHONUTF8: "1" },
      },
    );
  }

  /**
   * The fake's recorded calls.
   *
   * @returns The calls.
   */
  function calls(): { slug: string; status_at_start?: string; ff_first?: boolean; merges?: number }[] {
    try {
      return (JSON.parse(readFileSync(plan, "utf8")) as { calls: never[] }).calls;
    } catch {
      return [];
    }
  }

  /**
   * One change: a log line on the decision item, retried while the gate is closed for a moment.
   *
   * @param n - The change's number (in the text).
   * @returns The change's commit, or null when the tray channel kept it pending.
   */
  async function change(n: number): Promise<string | null> {
    for (let attempt = 0; attempt < 200; attempt++) {
      const board = (await app.get("/api/board")).json as BoardView;
      const answer = await app.post(`/api/items/${DECISION}/log`, {
        base: { board: board.revision },
        text: `soak ${n}`,
      });
      if (answer.status === 200) return (answer.json as ChangeResult).commit;
      const code = (answer.json as { error: { code: string } }).error.code;
      if (!["gate-closed", "busy", "changed-underneath"].includes(code)) {
        throw new Error(`change ${n}: ${answer.status} ${JSON.stringify(answer.json)}`);
      }
      await app.refresh();
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    throw new Error(`change ${n} never landed`);
  }

  /**
   * Waits for the loop process to end.
   *
   * @param timeoutMs - The limit.
   */
  async function loopEnded(timeoutMs: number): Promise<void> {
    if (!loop || loop.exitCode !== null) return;
    await Promise.race([
      new Promise<void>((resolve) => loop!.once("exit", () => resolve())),
      new Promise<void>((_, reject) =>
        setTimeout(() => reject(new Error("the loop did not end")), timeoutMs),
      ),
    ]);
  }

  it("SC-007: 200 changes against a loop of 20 runs - none lost, no run on a dirty tree", async () => {
    await addItems(20);
    // Runs on a branch of 10 s each (the real shape: the loop holds the edit lock only until the
    // run is on its branch, then changes land on main through the side worktree; a run that
    // never takes a branch - the fake's `hang` - keeps the lock for its whole length and the
    // changes queue up behind it). 200 changes take about 9 minutes; the loop stays alive (idle)
    // after its 20 runs, so the later changes meet a live loop and are committed at once.
    startLoop(Array<unknown>(20).fill({ do: "branch-hang", seconds: 10 }), false);
    const commits: (string | null)[] = [];
    for (let n = 1; n <= 200; n++) commits.push(await change(n));
    const until = Date.now() + 300_000;
    while (calls().length < 20 || app.services.loop.view?.shown !== "idle") {
      if (Date.now() > until) {
        throw new Error(
          `the loop did not finish its runs: ${calls().length}, ${app.services.loop.view?.shown}`,
        );
      }
      await new Promise((resolve) => setTimeout(resolve, 500));
      await app.refresh();
    }
    const log = await gitIn(root, ["log", "--format=%s", "main"]);
    const appCommits = log.split("\n").filter((s) => s.startsWith("backlog(app): ")).length;
    expect(appCommits).toBe(200);
    expect(commits.filter((c) => c === null)).toEqual([]);
    const seen = calls();
    expect(seen.length).toBe(20);
    expect(seen.filter((c) => c.status_at_start !== "").map((c) => c.slug)).toEqual([]);
    const desc = await gitIn(root, ["show", `main:backlog/items/${DECISION}/desc.md`]);
    expect(desc.match(/soak \d+/g)?.length).toBe(200);
    // No run's commit swept an app change in (every change was its own commit).
    const fakeFiles = await gitIn(root, ["log", "--format=", "--name-only", "--grep=fake", "main"]);
    expect(fakeFiles).not.toContain(DECISION);
    expect(await gitIn(root, ["status", "--porcelain"])).toBe("");
    expect((await app.services.tool.check()).total).toBe(0);
    console.log(`SC-007: 200 changes, 0 lost, ${seen.length} runs, 0 on a dirty tree`);
  }, 1_200_000);

  it("SC-002: 20 branch runs with 3 changes during each - none lost, every run closed", async () => {
    await addItems(20);
    startLoop(Array<unknown>(20).fill({ do: "branch-hang", seconds: 12 }));
    let made = 0;
    for (let run = 1; run <= 20; run++) {
      // Wait for this run to be on its branch, then change three times.
      const until = Date.now() + 120_000;
      for (;;) {
        await app.refresh();
        const lock = app.services.loop.view?.lock;
        if (lock && lock.slug === `soak-item-${run}` && lock.branch !== "-") break;
        if (Date.now() > until) throw new Error(`run ${run} did not reach its branch`);
        await new Promise((resolve) => setTimeout(resolve, 50));
      }
      for (let k = 0; k < 3; k++) await change(++made);
      // Let the run finish before the next one (its branch phase is short).
      const done = Date.now() + 120_000;
      while (app.services.loop.view?.lock?.slug === `soak-item-${run}`) {
        if (Date.now() > done) throw new Error(`run ${run} did not end`);
        await new Promise((resolve) => setTimeout(resolve, 100));
        await app.refresh();
      }
    }
    await loopEnded(300_000);
    expect(loop?.exitCode).toBe(0);
    const desc = await gitIn(root, ["show", `main:backlog/items/${DECISION}/desc.md`]);
    expect(desc.match(/soak \d+/g)?.length).toBe(60);
    const seen = calls();
    expect(seen.length).toBe(20);
    expect(seen.filter((c) => c.ff_first !== false).map((c) => c.slug)).toEqual([]);
    expect(seen.filter((c) => c.status_at_start !== "").map((c) => c.slug)).toEqual([]);
    const runs = await gitIn(root, ["show", "main:backlog/RUNS.md"]);
    expect(runs.match(/\| soak-item-\d+ \| closed \|/g)?.length).toBe(20);
    expect(await gitIn(root, ["status", "--porcelain"])).toBe("");
    expect((await app.services.tool.check()).total).toBe(0);
    const board = (await app.get("/api/board")).json as BoardView;
    expect(
      board.sections.find((s) => s.name === "Next")?.rows.map((r) => (r.kind === "item" ? r.slug : "")),
    ).toEqual([DISK, FTP]);
    console.log("SC-002: 20 runs x 3 changes, 0 lost, every run merged main and closed");
  }, 900_000);
});
