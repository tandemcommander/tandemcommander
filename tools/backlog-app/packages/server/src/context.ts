// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The server's context: where the repository is, where the Python tools are, and the
 * shared services every module uses.
 *
 * The Python tools are always taken from the repository the app itself lives in
 * (`tools/backlog/` next to `tools/backlog-app/`), and the repository they act on is passed with
 * `--root`. Normally both are the same repository; tests point `--root` at a temporary fixture
 * repository, which has a backlog but no tools.
 */

import { fileURLToPath } from "node:url";
import { join } from "node:path";
import type { RepoPaths } from "./repo/git.ts";
import type { StateDir } from "./settings/state-dir.ts";
import type { EventHub } from "./events/hub.ts";

/** Folder of the backlog tools of the app's own repository (`tools/backlog`). */
export const TOOLS_DIR = fileURLToPath(new URL("../../../../backlog/", import.meta.url));

/** The backlog tool (feature 242). */
export const BACKLOG_PY = join(TOOLS_DIR, "backlog.py");

/** The backlog loop (feature 247). */
export const LOOP_PY = join(TOOLS_DIR, "loop.py");

/** Shared services and settings of one server process. */
export interface ServerContext {
  /** The repository the app works on. */
  repo: RepoPaths;
  /** The app's state folder in the git common directory. */
  state: StateDir;
  /** The event hub of the per-tab streams. */
  hub: EventHub;
  /** Development mode. */
  dev: boolean;
  /**
   * Extra arguments for `loop.py start` - test hooks only (`--new-window-hidden`, `--claude-cmd`
   * with the fake claude), from the environment variable `BACKLOG_APP_LOOP_TEST_ARGS` (a JSON
   * array). Empty in normal use.
   */
  loopTestArgs: string[];
}

/**
 * Reads the test-only loop arguments from the environment.
 *
 * @returns The arguments, or an empty list.
 */
export function loopTestArgsFromEnv(): string[] {
  const raw = process.env["BACKLOG_APP_LOOP_TEST_ARGS"];
  if (!raw) return [];
  try {
    const parsed: unknown = JSON.parse(raw);
    return Array.isArray(parsed) && parsed.every((a) => typeof a === "string") ? parsed : [];
  } catch {
    return [];
  }
}
