// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file End-to-end test of the live run's layout: the page never scrolls, and each view has at
 * most one vertical scroll area. The real loop runs the fake claude, which replays the recorded
 * trace of feature 415 (`e2e/fixtures/live-run-trace.jsonl`) while holding the item, so the
 * story, the transcript and the figures are as long as a real run's. Every view of the run is
 * measured at several window sizes: the document and the frame's `main` must have nothing to
 * scroll, and the visible elements that scroll vertically are counted. A chat message must not
 * scroll anything outside the conversation. `BACKLOG_APP_E2E_MEASURE=<file>` writes the
 * measurements as JSON; `BACKLOG_APP_E2E_SHOTS=<folder>` saves screenshots.
 */

import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { expect, test, type Page } from "@playwright/test";
import {
  APP_DIR,
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

/** The window sizes measured: a large screen, a laptop, a small window, a narrow one. */
const SIZES = [
  { width: 1920, height: 1200 },
  { width: 1280, height: 800 },
  { width: 1024, height: 700 },
  { width: 820, height: 640 },
] as const;

/** One element that scrolls vertically. */
interface Scroller {
  /** Its tag. */
  tag: string;
  /** Its accessible name or the nearest one around it. */
  label: string;
  /** Its classes (shortened). */
  cls: string;
  /** How far it scrolls. */
  over: number;
  /** Its visible height. */
  height: number;
  /** It sits inside another element that scrolls vertically. */
  nested: boolean;
}

/** One measurement. */
interface Measure {
  /** The view (the tab's name, or "page"). */
  view: string;
  /** The window size. */
  size: string;
  /** How far the document scrolls. */
  documentOver: number;
  /** How far the frame's `main` scrolls. */
  mainOver: number;
  /** The elements that scroll vertically, the sidebar left out. */
  scrollers: Scroller[];
  /** The view's tab could not be clicked: something covers it. */
  covered?: boolean;
}

/**
 * Measures what scrolls on the page now.
 *
 * @param page - The page.
 * @param view - The view's name.
 * @param size - The window size.
 * @returns The measurement.
 */
async function measure(page: Page, view: string, size: string): Promise<Measure> {
  const found = await page.evaluate(() => {
    const scrolls = (el: Element): boolean => {
      const style = getComputedStyle(el);
      return (
        (style.overflowY === "auto" || style.overflowY === "scroll") &&
        el.scrollHeight > el.clientHeight + 1 &&
        el.clientHeight > 0 &&
        el.getClientRects().length > 0
      );
    };
    const doc = document.scrollingElement ?? document.documentElement;
    const main = document.querySelector("main");
    const list = [...document.querySelectorAll("body *")].filter(
      (el) => el.tagName !== "MAIN" && !el.closest("nav") && scrolls(el),
    );
    return {
      documentOver: doc.scrollHeight - doc.clientHeight,
      mainOver: main ? main.scrollHeight - main.clientHeight : 0,
      scrollers: list.map((el) => {
        let parent = el.parentElement;
        let nested = false;
        while (parent) {
          if (parent.tagName !== "MAIN" && scrolls(parent)) nested = true;
          parent = parent.parentElement;
        }
        return {
          tag: el.tagName,
          label:
            el.getAttribute("aria-label") ??
            el.closest("[aria-label]")?.getAttribute("aria-label") ??
            el.closest("[role=tabpanel]")?.getAttribute("aria-labelledby") ??
            "",
          cls: String(el.className).slice(0, 90),
          over: el.scrollHeight - el.clientHeight,
          height: el.clientHeight,
          nested,
        };
      }),
    };
  });
  return { view, size, ...found };
}

/**
 * The loop's status as JSON.
 *
 * @returns The status.
 */
function status(): { live: boolean } {
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
  ) as { live: boolean };
}

/**
 * The text of the live run's trace so far.
 *
 * @returns The text, or empty.
 */
function traceText(): string {
  const folder = join(fixture.root, ".agent-traces");
  if (!existsSync(folder)) return "";
  const last = readdirSync(folder)
    .filter((d) => /^\d{8}-\d{6}-claude-/.test(d))
    .sort()
    .at(-1);
  if (!last) return "";
  try {
    return readFileSync(join(folder, last, "trace.jsonl"), "utf8");
  } catch {
    return "";
  }
}

test.beforeEach(async () => {
  fixture = fixtureRepo();
  const base = fixture.root.split(/[\\/]/).pop();
  plan = join(fixture.root, "..", `${base}-plan.json`);
  app = await startApp(fixture.root, {
    FAKE_CLAUDE_PLAN: plan,
    BACKLOG_APP_CLAUDE: join(APP_DIR, "packages", "server", "test", "fixtures", "fake-claude-chat.mjs"),
    FAKE_CHAT_STDIN_FILE: join(fixture.root, "..", `${base}-chat.txt`),
  });
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

test("the live run page never scrolls; each view has at most one scroll area", async ({ page }) => {
  test.setTimeout(300_000);
  writePlan(plan, [
    {
      do: "replay",
      trace: join(APP_DIR, "e2e", "fixtures", "live-run-trace.jsonl"),
      feature: join(APP_DIR, "e2e", "fixtures", "live-feature"),
      branch: "415-live-dash",
      pace: 0.2,
      hold: 240,
      then: "close",
    },
  ]);
  await page.setViewportSize(SIZES[0]);
  await openApp(page, app, "/loop");
  await page.getByRole("button", { name: "Start the loop…" }).click();
  await page.getByRole("dialog").getByRole("button", { name: "Start" }).click();
  await expect.poll(() => status().live, { timeout: 30_000 }).toBe(true);
  await page.goto(`${app.base}/live`);
  await expect(page.getByRole("tablist", { name: "Views of the run" })).toBeVisible({ timeout: 20_000 });
  // The whole trace is in, so every view is as long as it gets.
  await expect
    .poll(() => traceText().includes("Final marker line"), { timeout: 90_000, intervals: [200] })
    .toBe(true);
  await page.waitForTimeout(1500);

  const results: Measure[] = [];
  const tabs = page.getByRole("tablist", { name: "Views of the run" }).getByRole("tab");
  const names = (await tabs.allInnerTexts()).map((t) => t.replace(/\s*\d+$/, "").trim());
  for (const size of SIZES) {
    await page.setViewportSize(size);
    for (const name of names) {
      const where = `${size.width}x${size.height}`;
      try {
        await tabs.filter({ hasText: name }).first().click({ timeout: 3000 });
      } catch {
        // Something covers the tab (the chat overlay of 415 below 1280 px): not reachable.
        results.push({ view: name, size: where, documentOver: 0, mainOver: 0, scrollers: [], covered: true });
        continue;
      }
      await page.waitForTimeout(400);
      results.push(await measure(page, name, where));
    }
  }

  // A chat message scrolls only the conversation (the page stays where it is).
  await page.setViewportSize(SIZES[0]);
  const chatTab = tabs.filter({ hasText: "Chat" });
  if ((await chatTab.count()) > 0) await chatTab.first().click();
  else await tabs.filter({ hasText: "Story" }).first().click();
  const main = page.locator("main");
  await main.evaluate((el) => {
    el.scrollTop = 0;
    document.scrollingElement!.scrollTop = 0;
  });
  await page.getByRole("button", { name: "What is it doing right now?" }).click();
  await expect(page.getByLabel("Claude").first()).toContainText("You asked: What is it doing right now?", {
    timeout: 20_000,
  });
  await page.waitForTimeout(500);
  const afterChat = await main.evaluate((el) => ({
    main: el.scrollTop,
    document: document.scrollingElement!.scrollTop,
  }));
  results.push({
    ...(await measure(page, "after a chat answer", "1920x1200")),
    documentOver: afterChat.document,
    mainOver: afterChat.main,
  });
  const shots = process.env["BACKLOG_APP_E2E_SHOTS"];
  if (shots) await page.screenshot({ path: join(shots, "live-layout-chat.png") });

  const out = process.env["BACKLOG_APP_E2E_MEASURE"];
  if (out) writeFileSync(out, JSON.stringify(results, null, 2));
  for (const r of results) {
    const where = `${r.view} at ${r.size}`;
    expect.soft(r.covered ?? false, `${where}: the view's tab is covered`).toBe(false);
    expect.soft(r.documentOver, `${where}: the document scrolls`).toBeLessThanOrEqual(0);
    expect.soft(r.mainOver, `${where}: the page (main) scrolls`).toBeLessThanOrEqual(0);
    expect
      .soft(
        r.scrollers.length,
        `${where}: more than one scroll area: ${r.scrollers.map((s) => `${s.label}|${s.cls}`).join(" ; ")}`,
      )
      .toBeLessThanOrEqual(1);
  }
});
