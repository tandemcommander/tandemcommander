// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file End-to-end tests of feature 371, user stories 1 and 2 (quickstart Q1 - Q5): with the
 * real loop and the fake claude's `branch-hang` run (a run on a feature branch that returns to
 * main with the backlog recipe), the backlog is read-only only while the run is on main, a new
 * item placed at Next #1 lands on main at once while the run goes on, the running item is shown
 * in In progress and frozen, the run's return merges main (recipe) and keeps the maintainer's
 * order, and the loop's next run takes the new item.
 */

import { readFileSync } from "node:fs";
import { join } from "node:path";
import { expect, test, type Page } from "@playwright/test";
import {
  backlog,
  fixtureRepo,
  git,
  openApp,
  run,
  startApp,
  TOOLS_DIR,
  writePlan,
  type App,
  type Fixture,
} from "./harness.ts";

let fixture: Fixture;
let app: App;
let plan = "";

/** The item the loop takes first in the fixture (Next #2; #1 is blocked). */
const ITEM = "ftp-per-server-encoding-flag";

/**
 * The loop's status as JSON.
 *
 * @returns The status.
 */
function status(): {
  live: boolean;
  run: { slug: string; phase: string } | null;
  lock: Record<string, string> | null;
  edit_lock: { holder?: string; live: boolean } | null;
} {
  return JSON.parse(
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
}

/**
 * The slugs of a section of `main`'s overview (the working tree is the run's during a run).
 *
 * @param section - The section heading.
 * @returns The slugs in order.
 */
function mainSection(section: string): string[] {
  const text = git(fixture.root, ["show", "main:backlog/BACKLOG.md"]).replaceAll("\r\n", "\n");
  const part = text.split(`## ${section}\n`)[1]?.split("\n## ")[0] ?? "";
  return [...part.matchAll(/\]\(items\/([a-z0-9-]+)\/desc\.md\)/g)].map((m) => m[1]!);
}

/**
 * The fake claude's recorded calls.
 *
 * @returns The calls.
 */
function calls(): {
  slug: string;
  ff_first?: boolean;
  merges?: number;
  returning?: string;
  status_at_start?: string;
}[] {
  return (JSON.parse(readFileSync(plan, "utf8")) as { calls: never[] }).calls;
}

/**
 * The log part of an item's description on `main` (diagnostics of a failed placement).
 *
 * @param slug - The item.
 * @returns The log text, or a note that the item is not on main.
 */
function itemLogOnMain(slug: string): string {
  try {
    return git(fixture.root, ["show", `main:backlog/items/${slug}/desc.md`]).split("## Log")[1] ?? "(no log)";
  } catch {
    return "(no item on main)";
  }
}

/**
 * Starts the loop from the Loop page.
 *
 * @param page - The page.
 */
async function startFromApp(page: Page): Promise<void> {
  await page.goto(`${app.base}/loop`);
  await page.getByRole("button", { name: "Start the loop…" }).click();
  await page.getByLabel(/End when nothing is eligible/).check();
  await page.getByRole("dialog").getByRole("button", { name: "Start" }).click();
  await expect.poll(() => status().live, { timeout: 30_000 }).toBe(true);
}

test.beforeEach(async () => {
  fixture = fixtureRepo();
  plan = join(fixture.root, "..", `${fixture.root.split(/[\\/]/).pop()}-plan.json`);
  app = await startApp(fixture.root, { FAKE_CLAUDE_PLAN: plan });
});

test.afterEach(() => {
  try {
    if (status().live)
      run(fixture.root, process.env["PYTHON"] ?? "python", [
        "-X",
        "utf8",
        join(TOOLS_DIR, "loop.py"),
        "kill",
        "--root",
        fixture.root,
      ]);
  } catch {
    // Already gone.
  }
  app.stop();
  fixture.cleanup();
});

test("Q1-Q5: a change during a run lands on main, the running item is in progress, the run merges it", async ({
  page,
}) => {
  test.setTimeout(300_000);
  // A run that measures on main for 12 s, works on its branch for 45 s, then returns; the
  // second step is the next run (the new item), which closes at once.
  writePlan(plan, [{ do: "branch-hang", before_branch: 12, seconds: 45 }, "close"]);
  await openApp(page, app);
  await startFromApp(page);
  await expect.poll(() => status().run?.slug ?? null, { timeout: 30_000 }).toBe(ITEM);

  // W1: the run is on main (no branch yet): read-only for a moment, the loop holds the edit lock.
  await page.goto(`${app.base}/backlog/next`);
  await expect(page.getByRole("status").filter({ hasText: "Read-only for a moment" })).toContainText(
    "is on main",
    { timeout: 10_000 },
  );
  // W2: the run is on its branch: changes land on main; the note says so.
  await expect.poll(() => status().lock?.["branch"] ?? "-", { timeout: 30_000 }).not.toBe("-");
  await expect(page.getByRole("status").filter({ hasText: "Live:" })).toContainText("A run is in progress", {
    timeout: 15_000,
  });

  // US2: In progress shows the running item with its feature; Next does not list it.
  await expect(page.locator(`tr[data-slug="${ITEM}"]`)).toHaveCount(0);
  await page.goto(`${app.base}/backlog/progress`);
  await expect(page.locator(`tr[data-slug="${ITEM}"]`)).toBeVisible({ timeout: 15_000 });
  await expect(page.locator(`tr[data-slug="${ITEM}"]`)).toContainText(/\d{3}/);
  await page.goto(`${app.base}/`);
  // The fixture has one item in progress of its own; the running one makes two.
  await expect(page.getByRole("link", { name: /In progress\s*2/ })).toBeVisible({ timeout: 15_000 });
  await expect(page.getByText(/Next up:/)).not.toContainText(ITEM);

  // US1: a new item placed at Next #1 through the form, while the run goes on.
  await page.goto(`${app.base}/new`);
  await page.getByLabel("Title (one line)").fill("Live edit during a run");
  await page.getByLabel("Problem").fill("made while the loop implemented another item");
  await page.getByLabel("Evidence").fill("e2e of feature 371");
  await page.getByLabel("Expected").fill("on main at once, the run untouched");
  await page.getByLabel("Place it").selectOption("Next");
  await page.getByLabel("Position").fill("1");
  await expect(page.getByLabel("Position")).toHaveValue("1");
  const mainBefore = git(fixture.root, ["rev-parse", "main"]).trim();
  await page.getByRole("button", { name: "Create" }).click();
  await expect
    .poll(() => `${mainSection("Next").join(",")} | ${itemLogOnMain("live-edit-during-a-run")}`, {
      timeout: 15_000,
    })
    .toMatch(/^live-edit-during-a-run,/);
  expect(git(fixture.root, ["log", "-1", "--format=%s", "main"]).trim()).toMatch(/^backlog\(app\): /);
  expect(git(fixture.root, ["rev-parse", "main~1"]).trim()).toBe(mainBefore);
  // The run is untouched: still alive, on its branch, its tree clean.
  expect(status().run?.slug).toBe(ITEM);
  expect(status().live).toBe(true);
  expect(git(fixture.root, ["rev-parse", "--abbrev-ref", "HEAD"]).trim()).toMatch(/^\d{3}-ftp/);
  expect(git(fixture.root, ["status", "--porcelain"])).toBe("");

  // The running item is frozen: its page offers nothing.
  await page.goto(`${app.base}/items/${ITEM}`);
  await expect(page.getByText(/A run works on this item/)).toBeVisible({ timeout: 15_000 });
  // The item is in progress, so Block is not offered at all; Edit text is, disabled.
  await expect(page.getByRole("button", { name: "Edit text" })).toBeDisabled();
  // A second change: reorder Next by a typed position of the new item (to #2 and back to the top).
  await page.goto(`${app.base}/items/live-edit-during-a-run`);
  const field = page.getByLabel("Position of live-edit-during-a-run");
  await field.fill("2");
  await field.press("Enter");
  await expect.poll(() => mainSection("Next")[1], { timeout: 15_000 }).toBe("live-edit-during-a-run");
  await page.getByRole("button", { name: "Move live-edit-during-a-run to the top" }).click();
  await expect.poll(() => mainSection("Next")[0], { timeout: 15_000 }).toBe("live-edit-during-a-run");

  // The run returns: main had moved, so the recipe ran; main holds the close and the order.
  await expect.poll(() => calls()[0]?.merges, { timeout: 120_000 }).toBeGreaterThanOrEqual(1);
  await expect.poll(() => calls()[0]?.ff_first).toBe(false);
  expect(calls()[0]?.returning).toMatch(/^ok: main is yours \(the loop holds the edit lock/);
  // The merge commit of the run keeps the maintainer's order (the next run may close the new
  // item at once, so main's head is not the place to look).
  await expect.poll(() => mainSection("Next").includes(ITEM), { timeout: 60_000 }).toBe(false);
  const mergeCommit = git(fixture.root, ["log", "--format=%H", "--grep=merge main", "main"])
    .trim()
    .split(/\s+/)[0];
  expect(mergeCommit, git(fixture.root, ["log", "--oneline", "-8", "main"])).toMatch(/^[0-9a-f]{40}$/);
  const merged = git(fixture.root, ["show", `${mergeCommit}:backlog/BACKLOG.md`]).replaceAll("\r\n", "\n");
  const mergedNext = [
    ...(merged.split("## Next\n")[1]?.split("\n## ")[0] ?? "").matchAll(/\]\(items\/([a-z0-9-]+)\//g),
  ].map((m) => m[1]);
  expect(mergedNext[0]).toBe("live-edit-during-a-run");
  expect(mergedNext).not.toContain(ITEM);
  expect(git(fixture.root, ["show", "main:backlog/RUNS.md"])).toMatch(
    new RegExp(`\\| ${ITEM} \\| closed \\|`),
  );
  // The loop's next run takes the new item (the fake closes it), then the loop ends (until idle).
  await expect.poll(() => calls()[1]?.slug ?? null, { timeout: 90_000 }).toBe("live-edit-during-a-run");
  await expect.poll(() => status().live, { timeout: 90_000 }).toBe(false);
  expect(calls()[0]?.status_at_start ?? "").toBe("");
  expect(git(fixture.root, ["rev-parse", "--abbrev-ref", "HEAD"]).trim()).toBe("main");
  expect(Number(backlog(fixture.root, ["check"]).match(/TOTAL: (\d+)/)?.[1])).toBe(0);
  // In progress holds only the fixture's own in-progress item again.
  await page.goto(`${app.base}/backlog/progress`);
  await expect(page.locator("tbody tr")).toHaveCount(1, { timeout: 15_000 });
  await expect(page.locator(`tr[data-slug="${ITEM}"]`)).toHaveCount(0);
});
