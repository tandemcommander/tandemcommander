// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The harness of the end-to-end tests (quickstart.md; research R23).
 *
 * Every test gets its own temporary git repository built from the backlog tool's fixture
 * `valid/` (never the real `backlog/`), and its own server on a free port, started exactly like
 * the launcher does (`node packages/server/src/main.ts`, the built client). The loop runs with the
 * fake claude of feature 247 in a hidden console window (`--new-window-hidden`), the AI jobs with
 * the fake of feature 344; no window opens on the maintainer's desktop and nothing reaches the
 * network.
 */

import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { cpSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import type { Page } from "@playwright/test";

/** The app folder (`tools/backlog-app`). */
export const APP_DIR = fileURLToPath(new URL("..", import.meta.url));

/** The backlog tools of this repository. */
export const TOOLS_DIR = join(APP_DIR, "..", "backlog");

/** The Python the tools run with. */
const PYTHON = process.env["PYTHON"] ?? "python";

/**
 * Runs a command and fails loudly.
 *
 * @param cwd - Working folder.
 * @param file - Executable.
 * @param args - Arguments.
 * @param input - Text for stdin.
 * @returns Its stdout.
 */
export function run(cwd: string, file: string, args: string[], input?: string): string {
  const result = spawnSync(file, args, {
    cwd,
    encoding: "utf8",
    input,
    windowsHide: true,
    env: { ...process.env, PYTHONUTF8: "1" },
  });
  if (result.status !== 0)
    throw new Error(`${file} ${args.join(" ")} failed: ${result.stderr}${result.stdout}`);
  return result.stdout;
}

/**
 * Runs git in a repository.
 *
 * @param root - The repository.
 * @param args - Git arguments.
 * @returns Its stdout.
 */
export function git(root: string, args: string[]): string {
  return run(root, "git", args);
}

/**
 * Runs the backlog tool on a repository.
 *
 * @param root - The repository.
 * @param args - Tool arguments.
 * @param input - JSON for `--input-json -`.
 * @returns Its stdout.
 */
export function backlog(root: string, args: string[], input?: string): string {
  return run(root, PYTHON, ["-X", "utf8", join(TOOLS_DIR, "backlog.py"), "--root", root, ...args], input);
}

/** A fixture repository. */
export interface Fixture {
  /** Its root. */
  root: string;
  /** Removes it. */
  cleanup: () => void;
}

/**
 * Creates a fixture repository on `main` with one commit.
 *
 * @returns The repository.
 */
export function fixtureRepo(): Fixture {
  const root = realpathSync(mkdtempSync(join(tmpdir(), "backlog-app-e2e-")));
  cpSync(join(TOOLS_DIR, "fixtures", "valid"), root, { recursive: true });
  git(root, ["init", "-q", "-b", "main"]);
  for (const [key, value] of [
    ["core.autocrlf", "false"],
    ["user.name", "Backlog App E2E"],
    ["user.email", "backlog-app-e2e@example.invalid"],
    ["commit.gpgsign", "false"],
  ] as const) {
    git(root, ["config", key, value]);
  }
  git(root, ["add", "-A"]);
  git(root, ["commit", "-q", "-m", "fixture"]);
  return {
    root,
    cleanup: () => {
      try {
        rmSync(root, { recursive: true, force: true });
      } catch {
        // A process of the test may still hold a file for a moment; the folder is in %TEMP%.
      }
    },
  };
}

/** A running app server. */
export interface App {
  /** `http://127.0.0.1:<port>`. */
  base: string;
  /** The start address with its one-time code. */
  startUrl: string;
  /** Stops the server (and nothing else). */
  stop: () => void;
  /** The session token (claimed once by the harness; pages get fresh start codes). */
  token: string;
  /** The server process. */
  process: ChildProcess;
}

/**
 * Starts the app server on a free port for a repository.
 *
 * @param root - The repository.
 * @param env - Extra environment (fake claude plans).
 * @returns The running app.
 */
export async function startApp(root: string, env: Record<string, string> = {}): Promise<App> {
  const fakeLoop = JSON.stringify([PYTHON, join(TOOLS_DIR, "fixtures", "fake_claude.py")]);
  const child = spawn(
    process.execPath,
    ["packages/server/src/main.ts", "--root", root, "--port", "0", "--no-open"],
    {
      cwd: APP_DIR,
      windowsHide: true,
      env: {
        ...process.env,
        BACKLOG_APP_LOOP_TEST_ARGS: JSON.stringify([
          "--new-window-hidden",
          "--claude-cmd",
          fakeLoop,
          "--tick",
          "0.05",
          "--poll",
          "0.3",
          "--backoff",
          "0.1,0.2",
          "--deadline",
          "150",
        ]),
        BACKLOG_APP_CLAUDE: join(APP_DIR, "packages", "server", "test", "fixtures", "fake-claude-job.mjs"),
        ...env,
      },
    },
  );
  const startUrl = await new Promise<string>((resolve, reject) => {
    let output = "";
    const timer = setTimeout(() => reject(new Error(`the app did not start: ${output}`)), 30_000);
    child.stdout?.on("data", (chunk: Buffer) => {
      output += chunk.toString("utf8");
      const match = /Backlog app: (http:\/\/127\.0\.0\.1:\d+\/\?boot=[\w-]+)/.exec(output);
      if (match) {
        clearTimeout(timer);
        resolve(match[1]!);
      }
    });
    child.stderr?.on("data", (chunk: Buffer) => (output += chunk.toString("utf8")));
    child.on("exit", (code) => {
      clearTimeout(timer);
      reject(new Error(`the app exited with ${String(code)}: ${output}`));
    });
  });
  const base = new URL(startUrl).origin;
  // Claim the start code once; every page then gets a fresh single-use code (openApp).
  const claim = await fetch(`${base}/api/session/claim`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Origin: base },
    body: JSON.stringify({ boot: new URL(startUrl).searchParams.get("boot") }),
  });
  const { token } = (await claim.json()) as { token: string };
  return {
    base,
    startUrl,
    token,
    process: child,
    stop: () => {
      if (child.pid !== undefined) {
        spawnSync(
          join(process.env["SystemRoot"] ?? "C:\\Windows", "System32", "taskkill.exe"),
          ["/PID", String(child.pid), "/T", "/F"],
          { windowsHide: true },
        );
      }
    },
  };
}

/**
 * Opens the app in a page (claims the one-time code) and waits for the first state.
 *
 * @param page - The Playwright page.
 * @param app - The running app.
 * @param path - Page to open after the start.
 */
export async function openApp(page: Page, app: App, path = "/"): Promise<void> {
  const link = await fetch(`${app.base}/api/session/link`, {
    method: "POST",
    headers: { Authorization: `Bearer ${app.token}`, "Content-Type": "application/json", Origin: app.base },
    body: "{}",
  });
  const { url } = (await link.json()) as { url: string };
  await page.goto(url);
  // The layout shows the loop's state once the event stream delivered the first state.
  await page
    .getByRole("link", { name: /loop|running|waiting|idle|paused/i })
    .first()
    .waitFor({ timeout: 20_000 });
  if (path !== "/") await page.goto(app.base + path);
}

/**
 * The slugs of a section in the order of `BACKLOG.md`, read through the tool.
 *
 * @param root - The repository.
 * @param section - The tool's section name (`next`, `inbox`, ...).
 * @returns The slugs.
 */
export function sectionOrder(root: string, section: string): string[] {
  const items = JSON.parse(backlog(root, ["list", "--section", section, "--json"])) as { slug: string }[];
  return items.map((i) => i.slug);
}

/**
 * Writes the fake claude's plan for the loop.
 *
 * @param path - The plan file.
 * @param steps - The steps (see `tools/backlog/fixtures/fake_claude.py`).
 */
export function writePlan(path: string, steps: unknown[]): void {
  writeFileSync(path, JSON.stringify({ steps, calls: [] }));
}

/**
 * Reads a file as text.
 *
 * @param path - The file.
 * @returns Its content.
 */
export function text(path: string): string {
  return readFileSync(path, "utf8");
}
