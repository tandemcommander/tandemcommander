// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file End-to-end test of the live run's layout: the page never scrolls, and each view has at
 * most one vertical scroll area. The real loop runs the fake claude, which replays the recorded
 * trace of feature 415 (`e2e/fixtures/live-run-trace.jsonl`) while holding the item, so the
 * story, the transcript and the figures are as long as a real run's. Every view of the run is
 * measured at several window sizes: the document and the frame's `main` must have nothing to
 * scroll, and the visible elements that scroll vertically are counted (feature 419). Then the chat:
 * a message must not scroll anything outside the conversation, the chat spans the page, a draft
 * survives a view switch, an answer arriving while another view is shown marks the Chat tab; the run
 * in one line stays above the views; the chosen view is kept in the address. `BACKLOG_APP_E2E_MEASURE=<file>` writes the
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
    // Answers end about 3 s after the message, so one can arrive while another view is shown.
    FAKE_CHAT_MODE: "slow",
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
      pace: 0.35,
      hold: 240,
      then: "close",
    },
  ]);
  const shots = process.env["BACKLOG_APP_E2E_SHOTS"];
  await page.setViewportSize(SIZES[0]);
  await openApp(page, app, "/loop");
  await page.getByRole("button", { name: "Start the loop…" }).click();
  await page.getByRole("dialog").getByRole("button", { name: "Start" }).click();
  await expect.poll(() => status().live, { timeout: 30_000 }).toBe(true);
  await page.goto(`${app.base}/live?view=story`);
  await expect(page.getByRole("tablist", { name: "Views of the run" })).toBeVisible({ timeout: 20_000 });

  // While lines arrive, the story keeps to its end; scrolled up by the reader it stays where the
  // reader put it ("Latest" shows), and "Latest" brings it back (FR-014). The list moves its own
  // position as it measures taller lines - that never counts as the reader's scroll.
  const storyLog = page.getByRole("log", { name: "The story of the run" });
  /**
   * Where the story's scroll area stands.
   *
   * @returns How far from its end it is, and its position.
   */
  const story = async (): Promise<{ gap: number; top: number }> =>
    storyLog.evaluate((log) => {
      const all = [log, ...log.querySelectorAll("*")];
      const el = all.find((e) => ["auto", "scroll"].includes(getComputedStyle(e).overflowY));
      return el
        ? { gap: el.scrollHeight - el.scrollTop - el.clientHeight, top: el.scrollTop }
        : { gap: 0, top: 0 };
    });
  const overflow = async (): Promise<number> =>
    storyLog.evaluate((log) => {
      const all = [log, ...log.querySelectorAll("*")];
      const el = all.find((e) => ["auto", "scroll"].includes(getComputedStyle(e).overflowY));
      return el ? el.scrollHeight - el.clientHeight : 0;
    });
  await expect.poll(overflow, { timeout: 60_000, intervals: [100] }).toBeGreaterThan(150);
  await page.waitForTimeout(600);
  // At its real end (a margin that left the measured height kept it 60 px short in 415).
  await expect
    .soft(
      async () => expect((await story()).gap).toBeLessThanOrEqual(2),
      "the live story at its end while it grows",
    )
    .toPass({ timeout: 3000 });
  if (!traceText().includes("Final marker line")) {
    await storyLog.hover();
    await page.mouse.wheel(0, -200);
    await page.waitForTimeout(300);
    const scrolled = await story();
    await page.waitForTimeout(1500);
    expect
      .soft((await story()).top, "the story stays where the reader scrolled")
      .toBeLessThanOrEqual(scrolled.top + 2);
    await expect
      .soft(storyLog.getByRole("button", { name: "Latest" }), "Latest after scrolling up")
      .toBeVisible();
    await storyLog.getByRole("button", { name: "Latest" }).click();
    console.log("419 follow: the reader's scroll up was checked while lines arrived");
  } else console.log("419 follow: the run's lines ended before the reader's scroll could be checked");
  // The whole trace is in, so every view is as long as it gets; the story ends with its last line.
  await expect
    .poll(() => traceText().includes("Final marker line"), { timeout: 90_000, intervals: [200] })
    .toBe(true);
  await expect.soft(storyLog, "the last line in the live story").toContainText("Final marker line", {
    timeout: 3000,
  });
  await expect
    .soft(async () => expect((await story()).gap).toBeLessThanOrEqual(2), "the story at its real end")
    .toPass({ timeout: 3000 });
  await page.waitForTimeout(1500);

  const results: Measure[] = [];
  const tabs = page.getByRole("tablist", { name: "Views of the run" }).getByRole("tab");
  const names = (await tabs.allInnerTexts()).map((t) => t.replace(/\s*\d+$/, "").trim());
  // Every part of the dashboard is a view of the one row (FR-002).
  expect
    .soft(names, "the views of the row")
    .toEqual([
      "Overview",
      "Story",
      "Critical",
      "Decisions",
      "Gallery",
      "Architecture",
      "Files",
      "Documents",
      "Raw trace",
      "Chat",
    ]);
  for (const size of SIZES) {
    await page.setViewportSize(size);
    for (const [index, name] of names.entries()) {
      const where = `${size.width}x${size.height}`;
      try {
        await tabs.nth(index).click({ timeout: 3000 });
      } catch {
        // Something covers the tab (the chat overlay of 415 below 1280 px): not reachable.
        results.push({ view: name, size: where, documentOver: 0, mainOver: 0, scrollers: [], covered: true });
        continue;
      }
      await page.waitForTimeout(400);
      results.push(await measure(page, name, where));
      if (shots && (size === SIZES[0] || size === SIZES[3]))
        await page.screenshot({
          path: join(shots, `419-${where}-${name.replace(/\s+/g, "-").toLowerCase()}.png`),
        });
    }
  }

  // A chat message scrolls only the conversation (the page stays where it is); the chat spans the
  // page's width.
  await page.setViewportSize(SIZES[0]);
  const chatTab = tabs.filter({ hasText: "Chat" });
  // Before feature 419 the chat was a column beside the views (the negative control runs on).
  const hasChat = (await chatTab.count()) > 0;
  expect.soft(hasChat, "a Chat view in the row").toBe(true);
  if (hasChat) await chatTab.first().click();
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
  await expect(page.getByLabel("Claude").first()).not.toContainText("writing…", { timeout: 20_000 });
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
  const chatRegion = page.getByRole("region", { name: "Chat about the run" });
  const widths = {
    chat: (await chatRegion.count()) > 0 ? ((await chatRegion.boundingBox())?.width ?? 0) : 0,
    main: await main.evaluate((el) => el.clientWidth),
  };
  expect
    .soft(widths.chat / widths.main, `the chat spans the page (${widths.chat} of ${widths.main} px)`)
    .toBeGreaterThan(0.9);
  if (shots) await page.screenshot({ path: join(shots, "419-chat-answered.png") });

  // The run in one line stays above the story and the chat (FR-010).
  const summary = page.getByRole("region", { name: "Run in short" });
  for (const view of hasChat ? ["Story", "Chat"] : ["Story"]) {
    await tabs.filter({ hasText: view }).first().click();
    await expect
      .soft(summary, `the run in one line on ${view}`)
      .toContainText("FTP per-server encoding flag");
    await expect.soft(summary, `the percentage on ${view}`).toContainText(/\d+ %/);
  }

  // A draft survives a switch to another view and back (FR-008).
  if (hasChat) await tabs.filter({ hasText: "Chat" }).first().click();
  const composer = page.getByRole("textbox", { name: "Your message" });
  await composer.fill("A draft of feature 419");
  await tabs.filter({ hasText: "Story" }).first().click();
  if (hasChat) await tabs.filter({ hasText: "Chat" }).first().click();
  await expect.soft(composer, "the draft after a view switch").toHaveValue("A draft of feature 419");
  await composer.fill("");

  // An answer that arrives while another view is shown marks the Chat tab; opening Chat clears it
  // (FR-009). The fake claude of this test ends an answer about 3 s after the message.
  await page.getByRole("button", { name: "What are the risks or problems?" }).click();
  await tabs.filter({ hasText: "Story" }).first().click();
  const chatNamed = page.getByRole("tab", { name: /^Chat/ });
  await expect
    .soft(chatNamed, "the mark of a new answer")
    .toHaveAccessibleName(/new answer/, { timeout: 20_000 });
  // The story shown meanwhile is whole (it mounted while the chat stayed mounted, hidden).
  await expect
    .soft(page.getByRole("log", { name: "The story of the run" }), "the story beside a hidden chat")
    .toContainText("Final marker line", { timeout: 10_000 });
  if (shots) await page.screenshot({ path: join(shots, "419-chat-mark.png") });
  if (hasChat) {
    await chatNamed.click();
    await expect.soft(chatNamed, "the mark after opening Chat").toHaveAccessibleName("Chat");
  }
  // The answer of the second turn (the fake echoes the first line after its marker; from the second
  // message on that is the live snapshot's heading, so the maintainer's text is checked on its own).
  await expect.soft(page.getByLabel("You").nth(1)).toContainText("What are the risks or problems?");
  await expect.soft(page.getByLabel("Claude").nth(1)).toContainText("You asked:", { timeout: 20_000 });

  // The chosen view is in the address: a reload keeps it; an unknown view opens the overview (FR-011).
  await tabs.filter({ hasText: "Documents" }).first().click();
  await expect.soft(page, "the view in the address").toHaveURL(/[?&]view=documents/);
  await page.reload();
  await expect
    .soft(page.getByRole("tab", { name: /^Documents/ }), "Documents after a reload")
    .toHaveAttribute("aria-selected", "true", { timeout: 20_000 });
  await page.goto(`${app.base}/live?view=nonsense`);
  await expect
    .soft(page.getByRole("tab", { name: "Overview" }), "an unknown view opens the overview")
    .toHaveAttribute("aria-selected", "true", { timeout: 20_000 });

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
    expect
      .soft(
        r.scrollers.filter((s) => s.nested).length,
        `${where}: a scroll area inside another: ${r.scrollers.map((s) => s.label).join(" ; ")}`,
      )
      .toBe(0);
  }
});
