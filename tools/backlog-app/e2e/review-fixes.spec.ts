// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file End-to-end tests of the defects found by the code review after the merge (feature 344):
 * search values stay text (`344`, a quoted phrase), the section editor loads the chosen section,
 * keys inside an open menu do not move the backlog selection, and "Edit fields" changes one field.
 */

import { readFileSync } from "node:fs";
import { join } from "node:path";
import { expect, test } from "@playwright/test";
import { backlog, fixtureRepo, openApp, startApp, type App, type Fixture } from "./harness.ts";

let fixture: Fixture;
let app: App;

/** An item with distinct section texts, created through the tool. */
const SLUG = "review-fixes-item";

test.beforeEach(async () => {
  fixture = fixtureRepo();
  backlog(
    fixture.root,
    ["--input-json", "-", "new", "--type", "bug", "--severity", "5", "--area", "tooling", "--slug", SLUG],
    JSON.stringify({
      title: "Review fixes item",
      problem: "The problem text of the item.",
      evidence: "The evidence text of the item.",
      expected: "The expected text of the item.",
    }),
  );
  app = await startApp(fixture.root);
});

test.afterEach(() => {
  app.stop();
  fixture.cleanup();
});

test("search values stay text: a number and a quoted phrase", async ({ page }) => {
  await openApp(page, app, "/backlog/all?q=344");
  await expect(page.locator("#filter-box")).toHaveValue("344");
  await page.goto(`${app.base}/backlog/all?q=${encodeURIComponent('"code page"')}`);
  await expect(page.locator("#filter-box")).toHaveValue('"code page"');
});

test("the section editor loads the section chosen in its select", async ({ page }) => {
  await openApp(page, app, `/items/${SLUG}`);
  await page.getByRole("button", { name: "Edit text" }).click();
  const editor = page.getByRole("dialog").locator(".cm-content");
  await page.getByRole("dialog").getByLabel("Section").selectOption("Problem");
  await expect(editor).toContainText("The problem text of the item.");
  await page.getByRole("dialog").getByLabel("Section").selectOption("Evidence");
  await expect(editor).toContainText("The evidence text of the item.");
  await expect(editor).not.toContainText("The problem text");
});

test("arrow keys in an open menu stay in the menu", async ({ page }) => {
  await openApp(page, app, "/backlog/next?sel=ftp-per-server-encoding-flag");
  const pane = page.locator("aside");
  await pane.getByRole("button", { name: "More actions" }).click();
  await expect(page.getByRole("menu")).toBeVisible();
  await page.keyboard.press("ArrowDown");
  await page.keyboard.press("ArrowDown");
  await expect(page).toHaveURL(/sel=ftp-per-server-encoding-flag/);
  await page.keyboard.press("Escape");
  await expect(page).toHaveURL(/sel=ftp-per-server-encoding-flag/);
});

test("Edit fields changes one field", async ({ page }) => {
  await openApp(page, app, `/items/${SLUG}`);
  await page.getByRole("button", { name: "More actions" }).click();
  await page.getByRole("menuitem", { name: /Edit fields/ }).click();
  await page.getByRole("dialog").getByLabel("Severity").fill("2");
  await page.getByRole("dialog").getByRole("button", { name: "Save" }).click();
  await expect
    .poll(() => readFileSync(join(fixture.root, "backlog", "items", SLUG, "desc.md"), "utf8"), {
      timeout: 15_000,
    })
    .toMatch(/^severity: 2$/m);
});
