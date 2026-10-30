// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file End-to-end tests of user story 1 (quickstart Q1 - Q3): the board shows what the tool
 * lists, filters live in the address and survive a new tab, the item page shows its history, the
 * archive shows a closed item, and the list works with the keyboard.
 */

import { expect, test } from "@playwright/test";
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

test.beforeEach(async () => {
  fixture = fixtureRepo();
  // A closed item in the history (the archive reads removals from git).
  backlog(
    fixture.root,
    ["--input-json", "-", "remove", "b-2-systemic-comparison"],
    JSON.stringify({ reason: "obsolete after the e2e setup" }),
  );
  git(fixture.root, ["add", "-A"]);
  git(fixture.root, ["commit", "-q", "-m", "backlog: close b-2 for the archive test"]);
  app = await startApp(fixture.root);
});

test.afterEach(() => {
  app.stop();
  fixture.cleanup();
});

test("Q1: every section shows the tool's order and fields", async ({ page }) => {
  await openApp(page, app, "/backlog/all");
  for (const [arg, name] of [
    ["next", "Next"],
    ["decisions", "Decisions for the maintainer"],
    ["person", "Person steps"],
    ["inbox", "Inbox"],
    ["parked", "Parked"],
  ] as const) {
    const expected = sectionOrder(fixture.root, arg);
    const table = page.locator("table", {
      has: page.locator("caption", { hasText: new RegExp(`^${name}$`) }),
    });
    await expect(table.locator("tbody tr")).toHaveCount(expected.length);
    const shown = await table
      .locator("tbody tr")
      .evaluateAll((rows) => rows.map((r) => r.getAttribute("data-slug")));
    expect(shown, name).toEqual(expected);
  }
});

test("Q2: a filter lives in the address, matches exactly and survives a new tab", async ({
  page,
  context,
}) => {
  await openApp(page, app, "/backlog/all");
  await page.locator("#filter-box").fill("type:improvement");
  await page.locator("#filter-box").press("Enter");
  await expect(page).toHaveURL(/q=type%3Aimprovement/);
  await expect(page.locator("tbody tr")).toHaveCount(1);
  await expect(page.locator("tbody tr").first()).toHaveAttribute("data-slug", "ftp-per-server-encoding-flag");
  // The same address in another tab shows the same view (the token is shared per origin).
  const second = await context.newPage();
  await second.goto(page.url());
  await expect(second.locator("tbody tr")).toHaveCount(1);
  // An unknown key is an error, never silently ignored.
  await page.locator("#filter-box").fill("colour:red");
  await page.locator("#filter-box").press("Enter");
  await expect(page.locator("#filter-errors")).toContainText("unknown key");
});

test("Q3: the item page, its history, and a closed item in the archive", async ({ page }) => {
  await openApp(page, app, "/items/ftp-per-server-encoding-flag");
  await expect(page.getByRole("heading", { level: 1 })).toContainText(/encoding/i);
  await page.getByRole("tab", { name: "History" }).click();
  await expect(page.getByText("fixture")).toBeVisible();
  await page.goto(`${app.base}/closed`);
  await page
    .getByRole("link", { name: /systemic comparison|b-2/i })
    .first()
    .click();
  await expect(page.getByText(/close b-2 for the archive test/)).toBeVisible();
});

test("the tabs of the detail pane switch (the pane keeps its own tab)", async ({ page }) => {
  await openApp(page, app, "/backlog/next?sel=ftp-per-server-encoding-flag");
  const pane = page.locator("article", { has: page.getByRole("heading", { name: /encoding/i }) });
  await expect(pane.getByRole("tab", { name: "Description" })).toHaveAttribute("aria-selected", "true");
  for (const name of [/^Log/, /^Relations/, /^Files/, /^History/, /^Runs/, /^Description/]) {
    await pane.getByRole("tab", { name }).click();
    await expect(pane.getByRole("tab", { name })).toHaveAttribute("aria-selected", "true");
  }
  await pane.getByRole("tab", { name: /^Log/ }).click();
  await expect(pane.getByRole("tabpanel")).toContainText(/created/);
});

test("keyboard: j selects, Enter opens, g b goes back to the backlog", async ({ page }) => {
  await openApp(page, app, "/backlog/next");
  await expect(page.locator("tbody tr").first()).toBeVisible();
  await page.locator("body").press("j");
  await expect(page).toHaveURL(/sel=[a-z0-9]/);
  await page.locator("body").press("Enter");
  await expect(page).toHaveURL(/\/items\//);
  await page.locator("body").press("g");
  await page.locator("body").press("b");
  await expect(page).toHaveURL(/\/backlog\/all/);
});
