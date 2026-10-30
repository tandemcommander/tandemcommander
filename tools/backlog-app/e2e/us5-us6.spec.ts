// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file End-to-end tests of user stories 5 and 6 (quickstart Q15 - Q16): an AI draft from a Czech
 * sentence fills the form and writes nothing before *Create*; a running AI job is cancelled; one
 * chosen item is run by the loop without changing the order; the release page offers no publish
 * action.
 */

import { join } from "node:path";
import { expect, test } from "@playwright/test";
import {
  fixtureRepo,
  git,
  openApp,
  run,
  sectionOrder,
  startApp,
  TOOLS_DIR,
  writePlan,
  type Fixture,
} from "./harness.ts";

let fixture: Fixture;

test.beforeEach(() => {
  fixture = fixtureRepo();
});

test.afterEach(() => {
  fixture.cleanup();
});

test("Q15: an AI draft from a Czech sentence fills the form and writes nothing before Create", async ({
  page,
}) => {
  const draft = {
    title: "Copying into an archive loses the file's time stamp",
    type: "bug",
    severity: 5,
    area: "tooling",
    who: "agent",
    effort: "S",
    problem: "The copied file gets the current time.",
    evidence: "Reported by the maintainer.",
    expected: "The original time is kept.",
    related: [],
    dependsOn: [],
    place: null,
    why: "a data bug",
  };
  const app = await startApp(fixture.root, { FAKE_CLAUDE_OUTPUT: JSON.stringify(draft) });
  try {
    await openApp(page, app, "/new");
    await page.getByLabel(/Draft with AI/).fill("Při kopírování do archivu se ztrácí čas souboru");
    await page.getByRole("button", { name: "Draft" }).click();
    await expect(page.getByLabel("Title (one line)")).toHaveValue(draft.title, { timeout: 30_000 });
    await expect(page.getByLabel("Problem")).toHaveValue(draft.problem);
    // Nothing written yet.
    expect(git(fixture.root, ["status", "--porcelain", "--", "backlog"])).toBe("");
  } finally {
    app.stop();
  }
});

test("Q15: a running AI job is cancelled and nothing is written", async ({ page }) => {
  const app = await startApp(fixture.root, { FAKE_CLAUDE_MODE: "slow" });
  try {
    await openApp(page, app, "/ask");
    await page.getByLabel("Your question").fill("what did the loop do last night?");
    await page.getByRole("button", { name: "Ask Claude" }).click();
    await expect(page.getByText(/AI ask: running/)).toBeVisible({ timeout: 20_000 });
    await page.getByRole("button", { name: "Cancel" }).click();
    await expect(page.getByText(/AI ask: cancelled/)).toBeVisible({ timeout: 20_000 });
    expect(git(fixture.root, ["status", "--porcelain", "--", "backlog"])).toBe("");
  } finally {
    app.stop();
  }
});

test("Q16: one chosen item is run by the loop; the order of Next is unchanged; the release page has no publish action", async ({
  page,
}) => {
  const plan = join(fixture.root, "..", `${fixture.root.split(/[\\/]/).pop()}-plan.json`);
  writePlan(plan, ["close"]);
  const app = await startApp(fixture.root, { FAKE_CLAUDE_PLAN: plan });
  try {
    await openApp(page, app, "/loop");
    const before = sectionOrder(fixture.root, "next");
    await page.getByRole("button", { name: "Run one item…" }).click();
    await page.getByLabel("Item of Next").selectOption("ftp-per-server-encoding-flag");
    await page.getByRole("dialog").getByRole("button", { name: "Run it" }).click();
    // The fake closes the item; afterwards the loop ends by itself (one item).
    await expect
      .poll(() => sectionOrder(fixture.root, "next"), { timeout: 60_000 })
      .toEqual(before.filter((s) => s !== "ftp-per-server-encoding-flag"));
    await expect
      .poll(
        () =>
          (
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
            ) as { live: boolean }
          ).live,
        { timeout: 30_000 },
      )
      .toBe(false);
    await page.goto(`${app.base}/release`);
    await expect(page.getByRole("heading", { name: "Release readiness" })).toBeVisible();
    await expect(page.getByRole("button", { name: /publish|push|tag|release/i })).toHaveCount(0);
  } finally {
    app.stop();
  }
});
