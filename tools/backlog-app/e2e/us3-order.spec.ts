// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file End-to-end tests of user story 3 (quickstart Q8 - Q12): reordering by mouse and keyboard
 * gives exactly the order the tool's own `reorder` gives, triage places an Inbox item, block and
 * unblock go through their dialogs, the change tray commits only `backlog/` with the app's
 * prefix, Ctrl+Z undoes, the backlog is read-only while a run holds the lock, and bulk changes
 * report per item.
 */

import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { expect, test, type Page } from "@playwright/test";
import {
  backlog,
  fixtureRepo,
  git,
  openApp,
  sectionOrder,
  startApp,
  type App,
  type Fixture,
} from "./harness.ts";

let fixture: Fixture;
let app: App;

/** Slugs of the three items the setup adds to Next (so there is something to reorder). */
const EXTRA = ["e2e-alpha-item", "e2e-beta-item", "e2e-gamma-item"];

test.beforeEach(async () => {
  fixture = fixtureRepo();
  for (const slug of EXTRA) {
    backlog(
      fixture.root,
      ["--input-json", "-", "new", "--type", "bug", "--severity", "3", "--area", "tooling", "--slug", slug],
      JSON.stringify({ title: `E2E ${slug}`, problem: "p", evidence: "e", expected: "x" }),
    );
    backlog(fixture.root, ["move", slug, "--section", "next"]);
  }
  git(fixture.root, ["add", "-A"]);
  git(fixture.root, ["commit", "-q", "-m", "backlog: e2e items"]);
  app = await startApp(fixture.root);
});

test.afterEach(() => {
  app.stop();
  fixture.cleanup();
});

/**
 * The Next table's rows in order.
 *
 * @param page - The page.
 * @returns The slugs.
 */
async function shownNext(page: Page): Promise<string[]> {
  // The board loads after the page; wait for the five rows of the setup.
  await expect(page.locator("tbody tr")).toHaveCount(5, { timeout: 20_000 });
  return page.locator("tbody tr").evaluateAll((rows) => rows.map((r) => r.getAttribute("data-slug") ?? ""));
}

/**
 * Waits until the tool lists Next in the given order.
 *
 * @param expected - The order.
 */
async function expectNextOrder(expected: string[]): Promise<void> {
  await expect.poll(() => sectionOrder(fixture.root, "next"), { timeout: 15_000 }).toEqual(expected);
}

test("Q8: a drag with the mouse reorders exactly like the tool", async ({ page }) => {
  await openApp(page, app, "/backlog/next");
  const before = await shownNext(page);
  expect(before.length).toBe(5);
  // Drag the last row above the first one (dnd-kit needs a real pointer movement).
  const source = page.locator(`tr[data-slug="${before[4]}"]`);
  const target = page.locator(`tr[data-slug="${before[0]}"]`);
  const from = (await source.boundingBox())!;
  const to = (await target.boundingBox())!;
  await page.mouse.move(from.x + 60, from.y + from.height / 2);
  await page.mouse.down();
  await page.mouse.move(from.x + 60, from.y + from.height / 2 - 10, { steps: 4 });
  await page.mouse.move(to.x + 60, to.y + 3, { steps: 12 });
  await page.mouse.up();
  const expected = [before[4]!, ...before.slice(0, 4)];
  await expectNextOrder(expected);
  // The item logs got no line from the reorder (analysis A1: `move` per drag would flood them).
  const log = JSON.parse(backlog(fixture.root, ["show", before[4]!, "--json"])) as { log: unknown[] };
  expect(log.log.length).toBe(2);
});

test("Q8: Alt+Down moves the selected row, coalesced into one change", async ({ page }) => {
  await openApp(page, app, "/backlog/next");
  const before = await shownNext(page);
  await page.locator(`tr[data-slug="${before[0]}"]`).click();
  await page.locator("body").press("Alt+ArrowDown");
  await page.locator("body").press("Alt+ArrowDown");
  await expectNextOrder([before[1]!, before[2]!, before[0]!, ...before.slice(3)]);
  // One tray entry for both key presses.
  await expect(page.getByRole("button", { name: /1 uncommitted change/ })).toBeVisible();
});

test("Q8/triage: n places the Inbox item at the suggested position", async ({ page }) => {
  await openApp(page, app, "/triage");
  await expect(page.getByText(/Suggested: Next #/)).toBeVisible();
  // The item itself must be loaded (its revision is the change's base).
  await expect(page.getByRole("heading", { name: /pipe/ })).toBeVisible();
  await page.locator("body").press("n");
  await expect.poll(() => sectionOrder(fixture.root, "inbox")).toEqual([]);
  expect(sectionOrder(fixture.root, "next")).toContain("typed-path-with-a-pipe-brackets");
});

test("Q8: block and unblock through their dialogs; a refusal writes nothing", async ({ page }) => {
  await openApp(page, app, "/items/e2e-alpha-item");
  await page.getByRole("button", { name: "Block" }).click();
  await page.getByLabel("Reason (required)").fill("waits for the e2e check");
  await page.getByRole("dialog").getByRole("button", { name: "Block" }).click();
  await expect
    .poll(
      () =>
        (JSON.parse(backlog(fixture.root, ["show", "e2e-alpha-item", "--json"])) as { status: string })
          .status,
    )
    .toBe("blocked");
  await page.getByRole("button", { name: "Unblock" }).click();
  await page.getByRole("dialog").getByRole("button", { name: "Unblock" }).click();
  await expect
    .poll(
      () =>
        (JSON.parse(backlog(fixture.root, ["show", "e2e-alpha-item", "--json"])) as { status: string })
          .status,
    )
    .toBe("open");
  expect(Number(backlog(fixture.root, ["check"]).match(/TOTAL: (\d+)/)?.[1])).toBe(0);
});

test("Q11/Q12: the tray undoes with Ctrl+Z and commits only backlog/ with the app's prefix", async ({
  page,
}) => {
  await openApp(page, app, "/backlog/next");
  const before = sectionOrder(fixture.root, "next");
  await shownNext(page);
  await page.locator(`tr[data-slug="${before[1]}"]`).click();
  await page.locator("body").press("Alt+ArrowUp");
  await expectNextOrder([before[1]!, before[0]!, ...before.slice(2)]);
  await page.locator("body").press("Control+z");
  await expectNextOrder(before);
  // A new change, then the commit through the tray.
  await page.locator(`tr[data-slug="${before[2]}"]`).click();
  await page.locator("body").press("Alt+ArrowUp");
  await expectNextOrder([before[0]!, before[2]!, before[1]!, ...before.slice(3)]);
  writeFileSync(join(fixture.root, "unrelated.txt"), "not the app's\n");
  await page.getByRole("button", { name: /uncommitted change/ }).click();
  await page.getByRole("button", { name: "Commit on main" }).click();
  await expect
    .poll(() => git(fixture.root, ["log", "-1", "--format=%s"]).trim())
    .toMatch(/^backlog\(app\): /);
  const files = git(fixture.root, ["show", "--name-only", "--format=", "HEAD"]).split("\n").filter(Boolean);
  expect(files.every((f) => f.startsWith("backlog/"))).toBe(true);
  expect(git(fixture.root, ["status", "--porcelain"])).toContain("unrelated.txt");
});

test("Q9: while a run holds the lock the backlog is read-only and read from main", async ({ page }) => {
  writeFileSync(
    join(fixture.root, ".git", "tandem-backlog-run.lock"),
    "started: 2026-10-30T10:00:00\nslug: e2e-beta-item\nbranch: 345-e2e\nhost: test\n",
  );
  await openApp(page, app, "/items/e2e-alpha-item");
  await expect(page.getByRole("status").filter({ hasText: "Read-only" })).toContainText("holds the lock");
  await expect(page.getByRole("button", { name: "Block" })).toBeDisabled();
  await expect(page.getByText("read from main")).toBeVisible();
});

test("bulk: block two marked items, one result per item", async ({ page }) => {
  await openApp(page, app, "/backlog/next");
  await page.getByLabel("Mark E2E e2e-alpha-item for a bulk change").check();
  await page.getByLabel("Mark E2E e2e-beta-item for a bulk change").check();
  await expect(page.getByText("2 marked")).toBeVisible();
  await page
    .getByRole("region", { name: "Bulk actions" })
    .getByRole("button", { name: "Block…", exact: true })
    .click();
  await page.getByLabel("Reason (required)").fill("bulk e2e");
  await page.getByRole("button", { name: "Apply to 2" }).click();
  await expect(page.getByRole("dialog").getByText("✓ e2e-alpha-item")).toBeVisible();
  await expect(page.getByRole("dialog").getByText("✓ e2e-beta-item")).toBeVisible();
  for (const slug of ["e2e-alpha-item", "e2e-beta-item"]) {
    expect((JSON.parse(backlog(fixture.root, ["show", slug, "--json"])) as { status: string }).status).toBe(
      "blocked",
    );
  }
});
