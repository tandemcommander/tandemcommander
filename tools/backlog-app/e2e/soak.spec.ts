// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The soak test of quickstart Q18 (SC-006): twenty loop runs with the app open on the live
 * page and the home page (both polling and streaming the whole time). The app must cause no loop
 * wait, no failed atomic replace of the loop's files and no change of the run lock or the loop's
 * state: the loop's own log and the journal show it.
 */

import { readFileSync } from "node:fs";
import { join } from "node:path";
import { expect, test } from "@playwright/test";
import { backlog, fixtureRepo, git, openApp, run, startApp, TOOLS_DIR, writePlan } from "./harness.ts";

/** Number of runs. */
const RUNS = 20;

test("Q18: twenty runs with the app open; the app never disturbs the loop", async ({ browser }) => {
  test.setTimeout(15 * 60_000);
  const fixture = fixtureRepo();
  const plan = join(fixture.root, "..", `${fixture.root.split(/[\\/]/).pop()}-plan.json`);
  // Twenty eligible items at the top of Next, created through the tool.
  for (let i = 1; i <= RUNS; i++) {
    const slug = `soak-item-${String(i).padStart(2, "0")}`;
    backlog(
      fixture.root,
      ["--input-json", "-", "new", "--type", "bug", "--severity", "5", "--area", "tooling", "--slug", slug],
      JSON.stringify({ title: `Soak item ${i}`, problem: "p", evidence: "e", expected: "x" }),
    );
    backlog(fixture.root, ["move", slug, "--section", "next", "--position", String(i)]);
  }
  git(fixture.root, ["add", "-A"]);
  git(fixture.root, ["commit", "-q", "-m", "backlog: soak items"]);
  writePlan(
    plan,
    Array.from({ length: RUNS }, () => "close"),
  );
  const app = await startApp(fixture.root, {
    FAKE_CLAUDE_PLAN: plan,
    BACKLOG_APP_LOOP_TEST_ARGS: JSON.stringify([
      "--new-window-hidden",
      "--claude-cmd",
      JSON.stringify([process.env["PYTHON"] ?? "python", join(TOOLS_DIR, "fixtures", "fake_claude.py")]),
      "--tick",
      "0.05",
      "--poll",
      "0.3",
      "--deadline",
      "800",
    ]),
  });
  try {
    const live = await browser.newPage();
    await openApp(live, app, "/live");
    const home = await browser.newPage();
    await openApp(home, app, "/");
    // Start through the API the page uses.
    const started = await fetch(`${app.base}/api/loop/start`, {
      method: "POST",
      headers: { Authorization: `Bearer ${app.token}`, "Content-Type": "application/json", Origin: app.base },
      body: JSON.stringify({ maxItems: RUNS, untilIdle: true }),
    });
    expect(started.status).toBe(200);
    const status = (): { live: boolean; lock: unknown; orphan: boolean } =>
      JSON.parse(
        run(fixture.root, process.env["PYTHON"] ?? "python", [
          "-X",
          "utf8",
          join(TOOLS_DIR, "loop.py"),
          "status",
          "--json",
          "--root",
          fixture.root,
        ]),
      ) as never;
    await expect.poll(() => status().live, { timeout: 30_000 }).toBe(true);
    await expect.poll(() => status().live, { timeout: 12 * 60_000, intervals: [2000] }).toBe(false);

    const journal = readFileSync(join(fixture.root, "backlog", "RUNS.md"), "utf8");
    expect((journal.match(/\| soak-item-\d\d \| closed \|/g) ?? []).length).toBe(RUNS);
    const log = readFileSync(join(fixture.root, ".git", "tandem-backlog-loop", "loop.log"), "utf8");
    // No failed replace, no wait caused by the app, no stop for a person.
    expect(log).not.toMatch(/PermissionError|WinError|cannot be written/);
    expect(log).not.toMatch(/backlog app is changing/);
    expect(log).not.toMatch(/working tree is not clean/);
    const final = status();
    expect(final.lock).toBeNull();
    expect(final.orphan).toBe(false);
    // The app made no change of its own (its tray stayed empty, nothing uncommitted).
    const tray = (await (
      await fetch(`${app.base}/api/tray`, { headers: { Authorization: `Bearer ${app.token}` } })
    ).json()) as { pending: unknown[] };
    expect(tray.pending).toHaveLength(0);
    expect(git(fixture.root, ["status", "--porcelain"])).toBe("");
  } finally {
    app.stop();
    fixture.cleanup();
  }
});
