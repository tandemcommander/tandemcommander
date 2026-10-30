// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Read-only access to the repository's git data (research R10, R16).
 *
 * A run of the backlog loop may be using the repository at any moment (checking out its branch,
 * committing, merging). This module therefore runs only git commands that take no lock: `log`,
 * `show`, `rev-parse`, `ls-tree`, `cat-file`, `rev-list`, `for-each-ref`, tree-to-tree `diff`, and
 * `status` with optional locks off (analysis A2 §5.2). Commands that write (`add`, `commit`) are
 * not here: the change tray runs them itself, only on `main` and only while the write gate is
 * open.
 */

import { existsSync } from "node:fs";
import { isAbsolute, join, resolve } from "node:path";
import { runProcess } from "../proc/spawn.ts";

/** The git subcommands this module may run. Anything else is a programming error. */
const READ_ONLY_COMMANDS = new Set([
  "log",
  "show",
  "rev-parse",
  "ls-tree",
  "cat-file",
  "rev-list",
  "for-each-ref",
  "diff",
  "status",
  "symbolic-ref",
  "tag",
  "merge-base",
]);

/** A failed git command. */
export class GitError extends Error {
  /** The git exit code. */
  readonly code: number | null;

  /**
   * Creates the error.
   *
   * @param message - What failed, with git's stderr.
   * @param code - The exit code.
   */
  constructor(message: string, code: number | null) {
    super(message);
    this.name = "GitError";
    this.code = code;
  }
}

/**
 * Runs one read-only git command in the repository.
 *
 * @param root - Repository root.
 * @param args - The git arguments; the first one must be a read-only subcommand.
 * @returns The command's stdout.
 * @throws GitError when git fails, Error when the subcommand is not read-only.
 */
export async function git(root: string, args: readonly string[]): Promise<string> {
  const sub = args[0] ?? "";
  if (!READ_ONLY_COMMANDS.has(sub)) throw new Error(`git ${sub} is not a read-only command`);
  if (sub === "tag" && args.length > 1 && !args.includes("--list") && !args.includes("-l")) {
    throw new Error("git tag is allowed only for listing");
  }
  // `-c core.quotepath=false` keeps non-ASCII paths readable instead of octal escapes.
  const result = await runProcess("git", ["-c", "core.quotepath=false", ...args], {
    cwd: root,
    timeoutMs: GIT_TIMEOUT_MS,
  });
  if (result.code !== 0) {
    throw new GitError(`git ${args.join(" ")} failed: ${result.stderr.trim()}`, result.code);
  }
  return result.stdout;
}

/**
 * Time limit of one git command. A hanging git (a credential prompt, a locked index on a network
 * drive) must not hang the app - above all not while it holds the edit lock, which the loop waits
 * for as long as the app lives (review S1).
 */
export const GIT_TIMEOUT_MS = 60_000;

/** The git locations of a repository. */
export interface RepoPaths {
  /** The working tree root. */
  root: string;
  /** The git common directory (`.git` of the main worktree); the loop keeps its state there. */
  commonDir: string;
}

/**
 * Finds the repository root and the git common directory of a folder.
 *
 * @param folder - Any folder inside the repository.
 * @returns The two paths, absolute.
 */
export async function repoPaths(folder: string): Promise<RepoPaths> {
  const root = (await git(folder, ["rev-parse", "--show-toplevel"])).trim();
  const common = (await git(folder, ["rev-parse", "--git-common-dir"])).trim();
  const absRoot = resolve(root);
  return { root: absRoot, commonDir: isAbsolute(common) ? resolve(common) : resolve(absRoot, common) };
}

/**
 * The branch the working tree is on, or `HEAD` when detached.
 *
 * @param root - Repository root.
 * @returns The branch name.
 */
export async function currentBranch(root: string): Promise<string> {
  return (await git(root, ["rev-parse", "--abbrev-ref", "HEAD"])).trim();
}

/**
 * The full hash a ref points to.
 *
 * @param root - Repository root.
 * @param ref - A branch, tag or commit.
 * @returns The commit hash, or null when the ref does not exist.
 */
export async function resolveRef(root: string, ref: string): Promise<string | null> {
  try {
    return (await git(root, ["rev-parse", "--verify", "--quiet", `${ref}^{commit}`])).trim() || null;
  } catch {
    return null;
  }
}

/**
 * Whether a merge is in progress (a `MERGE_HEAD` exists): the backlog may then hold conflict
 * markers and must not be changed.
 *
 * @param paths - The repository's paths.
 * @returns True during a merge.
 */
export function mergeInProgress(paths: RepoPaths): boolean {
  return existsSync(join(paths.commonDir, "MERGE_HEAD"));
}

/** One entry of `git status --porcelain`. */
export interface StatusEntry {
  /** The two status letters (index, worktree). */
  code: string;
  /** Path relative to the root, `/`-separated. */
  path: string;
}

/**
 * The dirty paths of the working tree, read without taking optional locks.
 *
 * @param root - Repository root.
 * @param pathspec - Optional paths to limit the listing to.
 * @returns The entries; untracked folders are listed by their files.
 */
export async function statusEntries(root: string, pathspec: readonly string[] = []): Promise<StatusEntry[]> {
  const out = await git(root, [
    "status",
    "--porcelain=v1",
    "-z",
    "--untracked-files=all",
    "--no-renames",
    ...(pathspec.length ? ["--", ...pathspec] : []),
  ]);
  return out
    .split("\0")
    .filter((record) => record.length > 3)
    .map((record) => ({ code: record.slice(0, 2), path: record.slice(3) }));
}

/** One commit of a log listing. */
export interface LogEntry {
  /** Full hash. */
  hash: string;
  /** Author date, ISO 8601 strict. */
  date: string;
  /** Subject line. */
  subject: string;
  /** Author name. */
  author: string;
}

/**
 * Lists commits with hash, date, subject and author.
 *
 * @param root - Repository root.
 * @param args - Extra `git log` arguments (range, `--`, paths, filters).
 * @returns The commits, newest first.
 */
export async function logEntries(root: string, args: readonly string[]): Promise<LogEntry[]> {
  // Fields are separated by NUL and records by a byte that never occurs in subjects.
  const out = await git(root, ["log", "--format=%H%x00%aI%x00%s%x00%an%x1e", ...args]);
  return out
    .split("\x1e")
    .map((record) => record.replace(/^\n/, ""))
    .filter((record) => record.includes("\0"))
    .map((record) => {
      const [hash = "", date = "", subject = "", author = ""] = record.split("\0");
      return { hash, date, subject, author };
    });
}

/**
 * Reads a file as it is in a commit, without touching the working tree.
 *
 * @param root - Repository root.
 * @param ref - The commit or branch.
 * @param path - Path relative to the root, `/`-separated.
 * @returns The file content, or null when the file does not exist in that commit.
 */
export async function showFile(root: string, ref: string, path: string): Promise<string | null> {
  try {
    return await git(root, ["show", `${ref}:${path}`]);
  } catch (error) {
    if (error instanceof GitError) return null;
    throw error;
  }
}

/**
 * Commits of `main` not on its remote-tracking branch and the reverse, as last fetched (no fetch;
 * the app makes no network requests of its own, FR-004).
 *
 * @param root - Repository root.
 * @returns Ahead / behind counts, or null when there is no `origin/main`.
 */
export async function aheadBehind(root: string): Promise<{ ahead: number; behind: number } | null> {
  if (!(await resolveRef(root, "origin/main"))) return null;
  const out = (await git(root, ["rev-list", "--left-right", "--count", "main...origin/main"])).trim();
  const [ahead = "0", behind = "0"] = out.split(/\s+/);
  return { ahead: Number(ahead), behind: Number(behind) };
}
