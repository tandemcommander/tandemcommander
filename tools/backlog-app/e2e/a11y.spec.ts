// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Accessibility of every main screen in both themes (FR-042, SC-009): axe finds no WCAG 2.2
 * AA violation (contrast, names, roles), and the layout has no horizontal page scroll at 900 px.
 */

import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import { fixtureRepo, openApp, startApp, type App, type Fixture } from "./harness.ts";

let fixture: Fixture;
let app: App;

test.beforeAll(async () => {
  fixture = fixtureRepo();
  app = await startApp(fixture.root);
});

test.afterAll(() => {
  app.stop();
  fixture.cleanup();
});

/** The screens checked. */
const SCREENS = [
  "/",
  "/backlog/all",
  "/backlog/next?sel=ftp-per-server-encoding-flag",
  "/items/ship-network-plugin",
  "/triage",
  "/new",
  "/loop",
  "/live",
  "/runs",
  "/closed",
  "/check",
  "/features",
  "/release",
  "/ask",
  "/settings",
];

for (const scheme of ["light", "dark"] as const) {
  test(`axe: no WCAG AA violations in the ${scheme} theme`, async ({ browser }) => {
    const context = await browser.newContext({ colorScheme: scheme, viewport: { width: 1440, height: 900 } });
    const page = await context.newPage();
    await openApp(page, app);
    const problems: string[] = [];
    for (const path of SCREENS) {
      await page.goto(app.base + path);
      // The event stream keeps a connection open, so "network idle" never comes: wait for the
      // page's heading or main content instead.
      await page.locator("main h1, main h2").first().waitFor({ timeout: 15_000 });
      await page.waitForTimeout(600);
      const result = await new AxeBuilder({ page })
        .withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
        .analyze();
      for (const violation of result.violations) {
        problems.push(
          `${path}: ${violation.id} (${violation.impact ?? "?"}) - ${violation.nodes
            .slice(0, 3)
            .map((n) => n.target.join(" "))
            .join(" | ")}`,
        );
      }
    }
    expect(problems, problems.join("\n")).toEqual([]);
    await context.close();
  });
}

test("no horizontal page scroll at 900 px", async ({ browser }) => {
  const context = await browser.newContext({ viewport: { width: 900, height: 800 } });
  const page = await context.newPage();
  await openApp(page, app);
  for (const path of ["/", "/backlog/all", "/items/ship-network-plugin", "/loop", "/runs"]) {
    await page.goto(app.base + path);
    await page.waitForTimeout(800);
    const overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    expect(overflow, path).toBeLessThanOrEqual(1);
  }
  await context.close();
});
