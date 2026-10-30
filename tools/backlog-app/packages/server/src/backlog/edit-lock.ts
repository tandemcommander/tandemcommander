// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The edit lock `<git-common-dir>/tandem-backlog-edit.lock` (research R9;
 * contracts/loop-cli-additions.md, *Precheck: the edit lock*).
 *
 * The app holds it for the duration of one change or one commit. The loop's precheck waits while a
 * live edit lock exists, so a loop resumed from a terminal in the middle of a change waits for the
 * change instead of starting a run on a half-changed backlog. Four lines: `pid`, `started_epoch`,
 * `started`, `purpose`; the loop judges liveness by the pid and the process creation time.
 *
 * Node cannot read another process's creation time, so on the app's side a lock is considered
 * dead when its process is gone, or when it is older than {@link STALE_AFTER_MS} (no change takes
 * that long; a reused pid of a crashed app must not block forever).
 */

import { closeSync, openSync, readFileSync, rmSync, writeSync } from "node:fs";
import { join } from "node:path";
import { ApiError } from "@backlog-app/shared";

/** File name in the git common directory (the loop reads it there). */
export const EDIT_LOCK_FILE = "tandem-backlog-edit.lock";

/** Age after which the app treats a lock of another process as stale. */
const STALE_AFTER_MS = 10 * 60_000;

/**
 * Whether a process exists.
 *
 * @param pid - The process id.
 * @returns True when it runs (or exists but cannot be signalled).
 */
function processExists(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    // EPERM: it exists but belongs to someone else.
    return (error as NodeJS.ErrnoException).code === "EPERM";
  }
}

/**
 * Reads the fields of a lock file.
 *
 * @param path - The file.
 * @returns The fields, or null when it is missing or unreadable.
 */
function readLock(path: string): { pid: number; startedEpoch: number; purpose: string } | null {
  try {
    const fields = new Map<string, string>();
    for (const line of readFileSync(path, "utf8").split("\n")) {
      const at = line.indexOf(": ");
      if (at > 0) fields.set(line.slice(0, at), line.slice(at + 2).trim());
    }
    return {
      pid: Number(fields.get("pid") ?? "0"),
      startedEpoch: Number(fields.get("started_epoch") ?? "0"),
      purpose: fields.get("purpose") ?? "",
    };
  } catch {
    return null;
  }
}

/**
 * The local time stamp `YYYY-MM-DDTHH:MM:SS` people read in the lock.
 *
 * @param date - The time.
 * @returns The stamp.
 */
function localStamp(date: Date): string {
  /**
   * Two-digit field.
   *
   * @param n - The number.
   * @returns It with a leading zero.
   */
  const pad = (n: number): string => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

/** The edit lock of one repository. */
export class EditLock {
  /** Absolute path of the lock file. */
  readonly path: string;

  /**
   * Creates the lock handle (takes nothing yet).
   *
   * @param commonDir - The git common directory.
   */
  constructor(commonDir: string) {
    this.path = join(commonDir, EDIT_LOCK_FILE);
  }

  /**
   * Takes the lock (exclusive create). A dead or stale lock is replaced.
   *
   * @param purpose - One line saying what the app is changing (shown by the loop and other apps).
   * @throws ApiError `busy` when another live process holds it.
   */
  acquire(purpose: string): void {
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const fd = openSync(this.path, "wx");
        const now = new Date();
        const text = `pid: ${process.pid}\nstarted_epoch: ${(now.getTime() / 1000).toFixed(3)}\nstarted: ${localStamp(now)}\npurpose: ${purpose.replace(/[\r\n]+/g, " ")}\n`;
        try {
          writeSync(fd, text);
        } finally {
          closeSync(fd);
        }
        return;
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== "EEXIST") throw error;
        const holder = readLock(this.path);
        const stale =
          holder === null ||
          holder.pid === process.pid ||
          !processExists(holder.pid) ||
          Date.now() - holder.startedEpoch * 1000 > STALE_AFTER_MS;
        if (!stale) {
          throw new ApiError(
            "busy",
            `another backlog app (pid ${holder.pid}) is changing the backlog: ${holder.purpose}`,
          );
        }
        // Our own leftover (a crash inside a change) or a dead holder: replace it.
        rmSync(this.path, { force: true });
      }
    }
    throw new ApiError("busy", "the edit lock could not be taken");
  }

  /** Releases the lock if this process holds it. */
  release(): void {
    const holder = readLock(this.path);
    if (holder && holder.pid === process.pid) rmSync(this.path, { force: true });
  }
}
