// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Builds temporary git repositories from the backlog tool's fixture `valid/` for tests that
 * run the real tools. The real repository's `backlog/` is never used by a test.
 */

import { cpSync, mkdtempSync, realpathSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { TOOLS_DIR } from "../../src/context.ts";
import { runProcess } from "../../src/proc/spawn.ts";

/** The complete, consistent backlog fixture of feature 242. */
export const VALID_FIXTURE = join(TOOLS_DIR, "fixtures", "valid");

/**
 * Runs git in a folder and fails the test on an error.
 *
 * @param cwd - The folder.
 * @param args - Git arguments.
 * @returns Git's stdout.
 */
export async function gitIn(cwd: string, args: string[]): Promise<string> {
  const result = await runProcess("git", args, { cwd });
  if (result.code !== 0) throw new Error(`git ${args.join(" ")}: ${result.stderr}`);
  return result.stdout;
}

/**
 * Creates a git repository on `main` holding a copy of the fixture, committed once.
 *
 * @param fixture - The folder to copy (default: `valid/`).
 * @returns The repository root and a cleanup function.
 */
export async function fixtureRepo(
  fixture: string = VALID_FIXTURE,
): Promise<{ root: string; cleanup: () => void }> {
  // realpath: the short 8.3 form of %TEMP% would differ from what git reports.
  const root = realpathSync(mkdtempSync(join(tmpdir(), "backlog-app-repo-")));
  cpSync(fixture, root, { recursive: true });
  await gitIn(root, ["init", "-q", "-b", "main"]);
  // Deterministic line ends and identity, whatever the machine's global settings are.
  await gitIn(root, ["config", "core.autocrlf", "false"]);
  await gitIn(root, ["config", "user.name", "Backlog App Test"]);
  await gitIn(root, ["config", "user.email", "backlog-app-test@example.invalid"]);
  await gitIn(root, ["config", "commit.gpgsign", "false"]);
  await gitIn(root, ["add", "-A"]);
  await gitIn(root, ["commit", "-q", "-m", "fixture"]);
  return { root, cleanup: () => rmSync(root, { recursive: true, force: true }) };
}
