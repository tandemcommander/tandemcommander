// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file End-to-end tests of user story 2 (quickstart Q4 - Q7) with the real loop and the fake claude
 * of feature 247: the loop starts from the app in its own (hidden) console window, the live view
 * shows the running item, pause / resume / stop show their pending states, a hard stop records the
 * run as killed and the next start continues it, and closing the app during a run changes nothing
 * for the run.
 */

import { join } from "node:path";
import { expect, test, type Page } from "@playwright/test";
import {
  fixtureRepo,
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

/** The item the loop takes in the fixture (Next #2; #1 is blocked). */
const ITEM = "ftp-per-server-encoding-flag";

/**
 * Runs a loop command on the fixture.
 *
 * @param args - The command.
 * @returns Its output.
 */
function loop(...args: string[]): string {
  return run(fixture.root, process.env["PYTHON"] ?? "python", [
    "-X",
    "utf8",
    join(TOOLS_DIR, "loop.py"),
    ...args,
    "--root",
    fixture.root,
  ]);
}

/**
 * The loop's status as JSON.
 *
 * @returns The status.
 */
function status(): {
  live: boolean;
  run: { slug: string; phase: string } | null;
  loop: { state: string } | null;
} {
  return JSON.parse(loop("status", "--json")) as never;
}

/**
 * Starts the loop from the Loop page.
 *
 * @param page - The page.
 * @param untilIdle - End when nothing is eligible.
 */
async function startFromApp(page: Page, untilIdle: boolean): Promise<void> {
  await page.goto(`${app.base}/loop`);
  await page.getByRole("button", { name: "Start the loop…" }).click();
  if (untilIdle) await page.getByLabel(/End when nothing is eligible/).check();
  await page.getByRole("dialog").getByRole("button", { name: "Start" }).click();
  await expect.poll(() => status().live, { timeout: 30_000 }).toBe(true);
}

test.beforeEach(async () => {
  fixture = fixtureRepo();
  plan = join(fixture.root, "..", `${fixture.root.split(/[\\/]/).pop()}-plan.json`);
  app = await startApp(fixture.root, { FAKE_CLAUDE_PLAN: plan });
});

test.afterEach(() => {
  // Never leave a loop behind: stop it and wait (its deadline would end it anyway).
  try {
    if (status().live) loop("kill");
  } catch {
    // Already gone.
  }
  app.stop();
  fixture.cleanup();
});

test("Q4/Q5: start, see the run live, pause pending, resume, stop pending, the run closes", async ({
  page,
}) => {
  writePlan(plan, [{ do: "hang", seconds: 12, then: "close" }]);
  await openApp(page, app);
  await startFromApp(page, false);
  await expect.poll(() => status().run?.slug ?? null, { timeout: 30_000 }).toBe(ITEM);
  // The top bar of every page shows the item; the live page shows the run.
  await expect(page.getByRole("link", { name: new RegExp(`Running · ${ITEM}`) })).toBeVisible({
    timeout: 15_000,
  });
  await page.goto(`${app.base}/live`);
  await expect(page.getByRole("link", { name: ITEM }).first()).toBeVisible({ timeout: 15_000 });
  // Pause while the item runs: pending; resume clears it; stop: pending until the item finishes.
  await page.getByRole("button", { name: "Pause the loop", exact: true }).click();
  await expect(page.getByText(/Pause pending/)).toBeVisible({ timeout: 10_000 });
  await page.getByRole("button", { name: "Resume the loop", exact: true }).click();
  await expect(page.getByText(/Pause pending/)).toHaveCount(0, { timeout: 10_000 });
  await page.getByRole("button", { name: "Stop the loop", exact: true }).click();
  await expect(page.getByText(/Stop pending/)).toBeVisible({ timeout: 10_000 });
  // The fake closes the item, the loop ends (stop), the history shows the closed run.
  await expect.poll(() => status().live, { timeout: 60_000 }).toBe(false);
  await page.goto(`${app.base}/runs`);
  await expect(page.getByRole("row", { name: new RegExp(`closed.*${ITEM}`) })).toBeVisible({
    timeout: 20_000,
  });
});

test("Q7: a hard stop records the run as killed; the next start continues and closes it", async ({
  page,
}) => {
  writePlan(plan, [{ do: "hang", seconds: 60, then: "close" }, "close"]);
  await openApp(page, app);
  await startFromApp(page, true);
  await expect.poll(() => status().run?.slug ?? null, { timeout: 30_000 }).toBe(ITEM);
  await page.goto(`${app.base}/loop`);
  await page.getByRole("button", { name: "Hard stop…" }).click();
  await page.getByLabel(/to confirm/).fill(ITEM);
  await page.getByRole("dialog").getByRole("button", { name: "Hard stop" }).click();
  await expect.poll(() => status().live, { timeout: 30_000 }).toBe(false);
  expect(status().run?.phase).toBe("killed");
  await expect(page.getByText(/Interrupted run of/)).toBeVisible({ timeout: 15_000 });
  await expect(page.getByText(/next start continues it/)).toBeVisible();
  // The next start continues the run in the same session; the fake's next step closes it.
  await startFromApp(page, true);
  await expect.poll(() => status().live, { timeout: 60_000 }).toBe(false);
  expect(status().run).toBeNull();
  const journal = run(fixture.root, "git", ["log", "-5", "--format=%s"]);
  expect(journal).toMatch(new RegExp(ITEM.slice(0, 20)));
});

test("Q6: closing the app during a run leaves the run alone; a new app shows it", async ({
  page,
  browser,
}) => {
  writePlan(plan, [{ do: "hang", seconds: 15, then: "close" }]);
  await openApp(page, app);
  await startFromApp(page, true);
  await expect.poll(() => status().run?.slug ?? null, { timeout: 30_000 }).toBe(ITEM);
  app.stop();
  // The loop and its run go on without the app.
  expect(status().live).toBe(true);
  app = await startApp(fixture.root, { FAKE_CLAUDE_PLAN: plan });
  const fresh = await browser.newPage();
  await openApp(fresh, app);
  await expect(fresh.getByRole("link", { name: new RegExp(ITEM) }).first()).toBeVisible({ timeout: 15_000 });
  await expect.poll(() => status().live, { timeout: 60_000 }).toBe(false);
});
