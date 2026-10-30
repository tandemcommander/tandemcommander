// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The application's own state folder `<git-common-dir>/tandem-backlog-app/` (research R1).
 *
 * The folder lies inside the git common directory, so nothing the application keeps (settings,
 * saved views, the change tray, caches, the event log) can ever make the working tree dirty - the
 * loop's precheck waits on a dirty tree and a run's `git add -A` would commit such files
 * (analysis A2 §5.2). Files are JSON (UTF-8, no BOM), written by temporary file + rename so a
 * reader never sees half a file.
 */

import { mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { randomBytes } from "node:crypto";
import type { ZodType } from "zod";

/** Name of the folder inside the git common directory. */
export const STATE_FOLDER = "tandem-backlog-app";

/** Access to the files of the state folder. */
export class StateDir {
  /** Absolute path of the folder. */
  readonly path: string;

  /**
   * Opens (and creates) the state folder of a repository.
   *
   * @param commonDir - The git common directory.
   */
  constructor(commonDir: string) {
    this.path = join(commonDir, STATE_FOLDER);
    mkdirSync(this.path, { recursive: true });
  }

  /**
   * The absolute path of a file in the folder.
   *
   * @param name - Relative name (`settings.json`, `cache/runs/x.json`).
   * @returns The absolute path.
   */
  file(name: string): string {
    return join(this.path, name);
  }

  /**
   * Reads and validates a JSON file.
   *
   * @param name - Relative name.
   * @param schema - The schema the content must satisfy.
   * @param fallback - Returned when the file is missing, unreadable or invalid.
   * @returns The parsed value or the fallback.
   */
  readJson<T>(name: string, schema: ZodType<T>, fallback: T): T {
    let text: string;
    try {
      text = readFileSync(this.file(name), "utf8");
    } catch {
      return fallback;
    }
    try {
      const parsed = schema.safeParse(JSON.parse(text));
      return parsed.success ? parsed.data : fallback;
    } catch {
      return fallback;
    }
  }

  /**
   * Writes a JSON file atomically (temporary file in the same folder, then rename).
   *
   * @param name - Relative name; missing folders are created.
   * @param value - The value to store.
   */
  writeJson(name: string, value: unknown): void {
    this.writeText(name, `${JSON.stringify(value, null, 2)}\n`);
  }

  /**
   * Writes a text file atomically.
   *
   * @param name - Relative name; missing folders are created.
   * @param text - UTF-8 text.
   */
  writeText(name: string, text: string): void {
    const target = this.file(name);
    mkdirSync(dirname(target), { recursive: true });
    const temp = `${target}.${randomBytes(6).toString("hex")}.tmp`;
    writeFileSync(temp, text, "utf8");
    try {
      renameSync(temp, target);
    } catch (error) {
      rmSync(temp, { force: true });
      throw error;
    }
  }

  /**
   * Removes a file or folder of the state folder, if present.
   *
   * @param name - Relative name.
   */
  remove(name: string): void {
    rmSync(this.file(name), { recursive: true, force: true });
  }
}
