// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file End-to-end tests of user story 4 (quickstart Q13 - Q14): a new item with a long text full
 * of shell characters is stored byte-exact and nothing of it runs; a decision is recorded with its
 * date; a person-step line is ticked with its result; a body section is edited; a closed item can
 * be undone before the commit.
 */

import { existsSync } from "node:fs";
import { join } from "node:path";
import { expect, test } from "@playwright/test";
import { backlog, fixtureRepo, openApp, startApp, type App, type Fixture } from "./harness.ts";

let fixture: Fixture;
let app: App;

test.beforeEach(async () => {
  fixture = fixtureRepo();
  app = await startApp(fixture.root);
});

test.afterEach(() => {
  app.stop();
  fixture.cleanup();
});

/**
 * One item as the tool shows it.
 *
 * @param slug - The item.
 * @returns The parsed `show --json`.
 */
function show(slug: string): {
  body: { name: string; markdown: string }[];
  log: { text: string }[];
  steps: { done: boolean }[];
  section: string;
  position: number | null;
} {
  return JSON.parse(backlog(fixture.root, ["show", slug, "--json"])) as never;
}

test("Q13: a 20,000-character text with shell characters is stored byte-exact and never runs", async ({
  page,
}) => {
  const canary = join(fixture.root, "canary-must-not-exist");
  const problem = `${"z".repeat(20_000)}\n\`touch ${canary}\` $(touch ${canary}) & echo x > ${canary} | "q" 'q' \\\\ Příliš žluťoučký kůň úpěl ďábelské ódy\n`;
  await openApp(page, app, "/new");
  await page.getByLabel("Title (one line)").fill("Byte exact through the browser");
  await page.getByLabel("Problem").fill(problem);
  await page.getByLabel("Evidence").fill("seen in the e2e test");
  await page.getByLabel("Expected").fill("kept exactly");
  await page.getByLabel("Place it").selectOption("Next");
  await page.getByLabel("Position").fill("1");
  await page.getByRole("button", { name: "Create" }).click();
  await expect(page).toHaveURL(/\/items\/byte-exact-through-the-browser/, { timeout: 20_000 });
  const item = show("byte-exact-through-the-browser");
  expect(item.body.find((b) => b.name === "Problem")!.markdown.trim()).toBe(problem.trim());
  expect(item.section).toBe("Next");
  expect(item.position).toBe(1);
  expect(existsSync(canary)).toBe(false);
});

test("Q14: a decision is recorded with its date, a person step is ticked with its result", async ({
  page,
}) => {
  await openApp(page, app, "/items/ship-network-plugin");
  await page.getByRole("button", { name: "Decide" }).click();
  await page.getByLabel("The decision (one sentence)").fill("ship it in the next release");
  await page.getByLabel("Then").selectOption("keep");
  await page.getByRole("button", { name: "Record the decision" }).click();
  await expect
    .poll(() => show("ship-network-plugin").log.at(-1)?.text ?? "")
    .toMatch(/maintainer decision \d{4}-\d{2}-\d{2}: option \w+ - ship it in the next release/);

  await page.goto(`${app.base}/items/release-0-1-10-person-checks`);
  await page.getByRole("button", { name: "Record steps" }).click();
  await page.getByLabel("Result of step 1").fill("works on the test machine");
  await page.getByRole("dialog").getByRole("button", { name: "Done" }).first().click();
  await expect.poll(() => show("release-0-1-10-person-checks").steps[0]?.done).toBe(true);
  expect(show("release-0-1-10-person-checks").log.at(-1)?.text).toMatch(
    /step 1 done: works on the test machine/,
  );
});

test("a body section is edited, and a closed item comes back with undo before the commit", async ({
  page,
}) => {
  await openApp(page, app, "/items/ftp-per-server-encoding-flag");
  await page.getByRole("button", { name: "Edit text" }).click();
  await page.getByLabel("Section").selectOption("Notes");
  await page.locator(".cm-content").click();
  await page.keyboard.press("Control+a");
  await page.keyboard.type("A note typed in the editor.");
  await page.getByRole("button", { name: "Save" }).click();
  await expect
    .poll(() =>
      show("ftp-per-server-encoding-flag")
        .body.find((b) => b.name === "Notes")
        ?.markdown.trim(),
    )
    .toBe("A note typed in the editor.");

  await page.getByRole("button", { name: "More actions" }).click();
  await page.getByRole("menuitem", { name: /Close \(fixed elsewhere/ }).click();
  await page.getByLabel("Reason (required)").fill("fixed by the e2e test");
  await page.getByRole("dialog").getByRole("button", { name: "Close the item" }).click();
  const folder = join(fixture.root, "backlog", "items", "ftp-per-server-encoding-flag");
  await expect.poll(() => existsSync(folder)).toBe(false);
  await page.locator("body").press("Control+z");
  await expect.poll(() => existsSync(join(folder, "desc.md"))).toBe(true);
  expect(Number(backlog(fixture.root, ["check"]).match(/TOTAL: (\d+)/)?.[1])).toBe(0);
});
