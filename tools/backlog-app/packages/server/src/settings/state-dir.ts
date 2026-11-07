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

import { spawnSync } from "node:child_process";
import {
  chmodSync,
  type Dirent,
  mkdirSync,
  readdirSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
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
   * Makes the folder readable and writable only by the user running the app (and SYSTEM): it holds
   * the launcher secret, which hands out a session (security contract), and the undo files, which
   * the app writes back into `backlog/`. Inside `.git` the folder inherits the repository's
   * permissions, which on a data drive commonly give every signed-in user Modify (review M2).
   *
   * On Windows the folder gets a protected ACL of the user and SYSTEM, inheritable; then every
   * entry inside is reset to inherit only from it (feature 412: the former `/T` grant left every
   * file already there with an empty ACL; the reset also repairs those). A link inside is never
   * followed (`icacls /T` follows junctions): when the folder holds one, or a folder cannot be
   * listed, the reset goes folder by folder.
   *
   * @returns Whether the folder itself is private (false: no ACLs on the drive, `icacls` missing -
   *   the caller then must not store a secret there) and whether the contents were reset.
   */
  restrictToOwner(): StateAccess {
    if (process.platform !== "win32") {
      try {
        chmodSync(this.path, 0o700);
        return { private: true, contents: "reset" };
      } catch {
        return { private: false, contents: "failed" };
      }
    }
    // Full System32 paths: Git for Windows puts its own tools before them on PATH.
    const system32 = join(process.env["SystemRoot"] ?? "C:\\Windows", "System32");
    const who = spawnSync(join(system32, "whoami.exe"), ["/user", "/fo", "csv", "/nh"], {
      encoding: "utf8",
      windowsHide: true,
    });
    const sid = /"(S-1-[\d-]+)"/.exec(who.stdout ?? "")?.[1];
    if (who.status !== 0 || !sid) return { private: false, contents: "failed" };
    /**
     * Runs `icacls`. Never with `/C` alone: with it `icacls` exits 0 also when an entry failed
     * (review 2 of 412, measured).
     *
     * @param args - Its arguments.
     * @returns True on exit code 0.
     */
    const icacls = (args: string[]): boolean =>
      spawnSync(join(system32, "icacls.exe"), args, { encoding: "utf8", windowsHide: true }).status === 0;
    /**
     * Resets entries; when an entry fails (`icacls` stops there), once more with `/C` so the
     * other entries are still repaired - the result stays a failure.
     *
     * @param args - The `icacls` arguments without `/C`.
     * @returns True when the call without `/C` succeeded.
     */
    const reset = (args: string[]): boolean => {
      if (icacls(args)) return true;
      icacls([...args, "/C"]);
      return false;
    };
    // The folder alone (no /T): drop the inherited entries, grant only the owner and SYSTEM.
    if (
      !icacls([this.path, "/inheritance:r", "/grant:r", `*${sid}:(OI)(CI)F`, "*S-1-5-18:(OI)(CI)F", "/Q"])
    ) {
      return { private: false, contents: "failed" };
    }
    // The contents: inherit only. One call for the tree when it holds no link to follow.
    if (treeWithoutLinks(this.path)) {
      return {
        private: true,
        contents: reset([join(this.path, "*"), "/reset", "/T", "/Q"]) ? "reset" : "failed",
      };
    }
    return { private: true, contents: resetFolderByFolder(this.path, reset) ? "reset" : "failed" };
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

/** The result of {@link StateDir.restrictToOwner}. */
export interface StateAccess {
  /** The folder itself is readable and writable by the user (and SYSTEM) only. */
  private: boolean;
  /** Every entry inside inherits the folder's access (`reset`), or a reset failed. */
  contents: "reset" | "failed";
}

/**
 * Whether a folder tree can be reset in one `icacls /T` call: every folder of it can be listed
 * and none of its entries is a link (a junction or symbolic link, which `/T` would follow).
 *
 * @param root - The folder.
 * @returns True when the tree holds no link and every folder was listed.
 */
function treeWithoutLinks(root: string): boolean {
  const pending = [root];
  for (let folder = pending.pop(); folder !== undefined; folder = pending.pop()) {
    let entries: Dirent[];
    try {
      entries = readdirSync(folder, { withFileTypes: true });
    } catch {
      return false;
    }
    for (const entry of entries) {
      if (entry.isSymbolicLink()) return false;
      if (entry.isDirectory()) pending.push(join(folder, entry.name));
    }
  }
  return true;
}

/**
 * Resets the entries of a folder tree to inherited access one folder at a time, top-down, so a
 * folder that could not be listed is listable once its parent's reset reached it. Links are reset
 * as links (`/L`) and never descended into.
 *
 * @param root - The folder whose contents are reset (the folder itself is not).
 * @param reset - Runs an `icacls` reset (without `/C`); true on success.
 * @returns True when every reset succeeded and every folder could be listed.
 */
function resetFolderByFolder(root: string, reset: (args: string[]) => boolean): boolean {
  let ok = true;
  const pending = [root];
  for (let folder = pending.pop(); folder !== undefined; folder = pending.pop()) {
    if (!reset([join(folder, "*"), "/reset", "/L", "/Q"])) ok = false;
    let entries: Dirent[];
    try {
      entries = readdirSync(folder, { withFileTypes: true });
    } catch {
      ok = false;
      continue;
    }
    for (const entry of entries) {
      if (entry.isDirectory() && !entry.isSymbolicLink()) pending.push(join(folder, entry.name));
    }
  }
  return ok;
}
