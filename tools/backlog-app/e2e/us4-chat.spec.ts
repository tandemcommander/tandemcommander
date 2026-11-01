// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file End-to-end tests of feature 371, user story 4 (quickstart Q7): the conversation window
 * opens from the item page without the app's frame, shows the item's essentials within a 1080p
 * viewport, streams a reply from the fake claude, keeps the transcript over a reload, starts an
 * empty conversation on request, and has no WCAG AA violations.
 */

import { join } from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import { APP_DIR, fixtureRepo, openApp, startApp, type App, type Fixture } from "./harness.ts";

let fixture: Fixture;
let app: App;

/** The fixture's open item of Next. */
const ITEM = "ftp-per-server-encoding-flag";

test.use({ viewport: { width: 1920, height: 1080 } });

test.beforeEach(async () => {
  fixture = fixtureRepo();
  app = await startApp(fixture.root, {
    BACKLOG_APP_CLAUDE: join(APP_DIR, "packages", "server", "test", "fixtures", "fake-claude-chat.mjs"),
  });
});

test.afterEach(() => {
  app.stop();
  fixture.cleanup();
});

test("Q7: the conversation window shows the essentials, streams a reply, keeps it, and starts anew", async ({
  page,
  context,
}) => {
  await openApp(page, app, `/items/${ITEM}`);
  const opened = context.waitForEvent("page");
  await page.getByRole("link", { name: "Chat about this item" }).click();
  const chat = await opened;
  await chat.setViewportSize({ width: 1920, height: 1080 });
  // No frame: no main navigation; the essentials are at the top and fit the viewport.
  await expect(chat.getByRole("heading", { level: 1 })).toContainText("FTP per-server encoding flag", {
    timeout: 20_000,
  });
  await expect(chat.getByRole("navigation", { name: "Main" })).toHaveCount(0);
  const header = chat.getByRole("banner", { name: "The item" });
  await expect(header).toContainText("Who / effort");
  await expect(header).toContainText("Claude reads");
  const box = (await header.boundingBox())!;
  expect(box.y + box.height).toBeLessThan(1080);
  // A message: the reply streams in and ends; the tool use is listed.
  await chat.getByLabel("Your message").fill("What is this about?");
  await chat.getByLabel("Your message").press("Enter");
  await expect(chat.getByLabel("You").first()).toContainText("What is this about?");
  await expect(chat.getByLabel("Claude").first()).toContainText("You asked: What is this about?", {
    timeout: 20_000,
  });
  await expect(chat.getByRole("button", { name: /1 tool use/ })).toBeVisible();
  await expect(chat.getByText(/Cost so far/)).toBeVisible({ timeout: 10_000 });
  // The transcript survives a reload.
  await chat.reload();
  await expect(chat.getByLabel("Claude").first()).toContainText("You asked: What is this about?", {
    timeout: 20_000,
  });
  // A second message continues; the input is free again after the reply.
  await chat.getByLabel("Your message").fill("And then?");
  await chat.getByLabel("Your message").press("Enter");
  await expect(chat.getByLabel("Claude").nth(1)).toContainText("You asked: And then?", { timeout: 20_000 });
  await expect(chat.getByRole("button", { name: "Send" })).toBeVisible();
  // Accessibility of the page.
  const result = await new AxeBuilder({ page: chat })
    .withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
    .analyze();
  expect(
    result.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(" ")).join(" | ")}`),
  ).toEqual([]);
  // A new conversation is empty.
  await chat.getByRole("button", { name: "New conversation" }).click();
  await expect(chat.getByLabel("Claude")).toHaveCount(0, { timeout: 10_000 });
  await expect(chat.getByText(/Ask about this item/)).toBeVisible();
  // The item page says nothing changed in the backlog: the item is still open in Next.
  await page.reload();
  await expect(page.getByText("Next #2")).toBeVisible({ timeout: 15_000 });
});
