// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The app's side worktree of `main` (feature 371, research R1, R2): where a change is
 * applied while a run holds the run lock and works on its branch in the primary working tree.
 *
 * It is a sparse (`backlog/` only; the feature folders of `specs/` are created empty, so the
 * tool's `feature-missing` rule finds them), detached (never a branch: the run's checkout of
 * `main` must never find `main` checked out elsewhere) and persistent worktree at
 * `<git-common-dir>/tandem-backlog-app/main-worktree/`. Before every change it is brought to
 * `main`'s commit and verified clean; the backlog tool runs on it with `--root`; the change is
 * committed on the detached HEAD and `main` is moved with a compare-and-swap
 * (`git update-ref refs/heads/main <new> <old>`), which fails harmlessly when `main` moved
 * meanwhile (the run's return). Anything left behind by a failed step is reverted.
 *
 * This module is the only one besides the change tray that runs writing git commands, and it
 * runs them only inside the worktree (plus `worktree add/prune` and the ref update of `main`).
 * `git sparse-checkout` in a linked worktree sets `extensions.worktreeConfig` in the
 * repository's config once (git 2.20+ reads it); the app's own config is otherwise untouched.
 */

import { existsSync, mkdirSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { createHash } from "node:crypto";
import { ApiError } from "@backlog-app/shared";
import type { ServerContext } from "../context.ts";
import { runProcess, type ProcessResult } from "../proc/spawn.ts";
import { GIT_TIMEOUT_MS } from "../repo/git.ts";

/** The folder name inside the app's state folder. */
export const SIDE_WORKTREE_FOLDER = "main-worktree";

/**
 * The sparse patterns: the backlog only. The feature folders the tool's `feature-missing` rule
 * looks for are created empty by {@link SideWorktree.sync} from the commit's tree (a pattern
 * for one file per folder misses folders without that file; every folder is 67 MB).
 */
const SPARSE_PATTERNS = ["backlog"];

/** The side worktree of one repository. */
export class SideWorktree {
  /** Absolute path of the worktree. */
  readonly path: string;

  /** The server context. */
  private readonly ctx: ServerContext;

  /**
   * Creates the handle (nothing on disk yet).
   *
   * @param ctx - The server context.
   */
  constructor(ctx: ServerContext) {
    this.ctx = ctx;
    this.path = ctx.state.file(SIDE_WORKTREE_FOLDER);
  }

  /**
   * Runs git in a folder.
   *
   * @param cwd - The folder.
   * @param args - Git arguments.
   * @param stdin - Text for stdin.
   * @returns The result.
   */
  private git(cwd: string, args: string[], stdin?: string): Promise<ProcessResult> {
    return runProcess("git", ["-c", "core.quotepath=false", ...args], {
      cwd,
      timeoutMs: GIT_TIMEOUT_MS,
      ...(stdin === undefined ? {} : { stdin }),
    });
  }

  /**
   * Runs git in the worktree and fails loudly.
   *
   * @param args - Git arguments.
   * @param stdin - Text for stdin.
   * @returns Git's stdout.
   * @throws ApiError `tool-failed` when git fails.
   */
  private async inTree(args: string[], stdin?: string): Promise<string> {
    const result = await this.git(this.path, args, stdin);
    if (result.code !== 0) {
      throw new ApiError(
        "tool-failed",
        `git ${args[0] ?? ""} in the side worktree failed`,
        result.stderr.trim(),
      );
    }
    return result.stdout;
  }

  /**
   * Whether the worktree exists on disk and is known to git.
   *
   * @returns True when usable.
   */
  async exists(): Promise<boolean> {
    if (!existsSync(join(this.path, ".git"))) return false;
    const result = await this.git(this.path, ["rev-parse", "--is-inside-work-tree"]);
    return result.code === 0 && result.stdout.trim() === "true";
  }

  /**
   * Removes git's record of worktrees whose folders are gone (also this one after a deletion).
   */
  async prune(): Promise<void> {
    await this.git(this.ctx.repo.root, ["worktree", "prune"]);
  }

  /**
   * Creates the worktree when it is missing: detached at `main`, sparse, checked out.
   *
   * @throws ApiError `tool-failed` when git refuses.
   */
  async ensure(): Promise<void> {
    if (await this.exists()) return;
    // A `.git` that is there but cannot be read is a permission problem (feature 412: a start of
    // feature 344 left the state folder's files with an empty ACL), never a reason to delete.
    const dotGit = join(this.path, ".git");
    if (existsSync(dotGit)) {
      try {
        readFileSync(dotGit);
      } catch (error) {
        const code = (error as NodeJS.ErrnoException).code;
        if (code === "EACCES" || code === "EPERM") {
          throw new ApiError(
            "tool-failed",
            "the side worktree of main cannot be read (its .git file is not accessible) - restart the backlog app to repair the state folder's permissions",
            String(error),
          );
        }
      }
    }
    // A folder without git's record (a crash between the two steps) is removed first.
    if (existsSync(this.path)) rmSync(this.path, { recursive: true, force: true });
    await this.prune();
    const add = await this.git(this.ctx.repo.root, [
      "worktree",
      "add",
      "--detach",
      "--no-checkout",
      this.path,
      "main",
    ]);
    if (add.code !== 0) {
      throw new ApiError("tool-failed", "the side worktree of main could not be created", add.stderr.trim());
    }
    await this.inTree(["sparse-checkout", "set", "--no-cone", ...SPARSE_PATTERNS]);
    await this.inTree(["checkout", "-q", "--detach", "main"]);
  }

  /**
   * Brings the worktree to one commit of `main`, clean: detached at the commit, the sparse
   * patterns applied again, every local change and untracked backlog file gone.
   *
   * @param commit - The commit `main` points to (the base of the change).
   * @throws ApiError `tool-failed` when the tree cannot be made clean.
   */
  async sync(commit: string): Promise<void> {
    await this.ensure();
    // Files are checked out as the blobs hold them (no line-end conversion): the revisions the
    // client holds during a run are blob hashes, and the primary tree's `core.autocrlf` /
    // `text=auto` would check CRLF out here (review M1 of 371). Per-worktree settings need
    // `extensions.worktreeConfig`, which `sparse-checkout` already enabled.
    await this.inTree(["config", "--worktree", "core.autocrlf", "false"]);
    await this.inTree(["config", "--worktree", "core.eol", "lf"]);
    await this.inTree(["checkout", "-q", "--detach", commit]);
    await this.inTree(["sparse-checkout", "reapply"]);
    await this.inTree(["reset", "-q", "--hard", commit]);
    await this.inTree(["clean", "-fdq", "--", "backlog"]);
    // The feature folders, empty: the tool's `feature-missing` rule only asks whether
    // `specs/NNN-*` exists. Empty folders are invisible to git status.
    const folders = (await this.inTree(["ls-tree", "--name-only", "-z", commit, "--", "specs/"])).split("\0");
    for (const folder of folders) {
      if (/^specs\/[^/]+$/.test(folder))
        mkdirSync(join(this.path, "specs", folder.slice(6)), { recursive: true });
    }
    const head = (await this.inTree(["rev-parse", "HEAD"])).trim();
    const status = (await this.inTree(["status", "--porcelain=v1", "--untracked-files=all"])).trim();
    if (head !== commit || status !== "") {
      throw new ApiError(
        "tool-failed",
        "the side worktree of main could not be brought to main",
        `HEAD ${head.slice(0, 12)}, status: ${status.slice(0, 500)}`,
      );
    }
  }

  /**
   * Discards everything the worktree holds beyond its HEAD (after a refused or failed change).
   */
  async revert(): Promise<void> {
    if (!(await this.exists())) return;
    await this.git(this.path, ["reset", "-q", "--hard"]);
    await this.git(this.path, ["clean", "-fdq", "--", "backlog"]);
  }

  /**
   * The SHA-256 of a file of the worktree, or null when it does not exist.
   *
   * @param relative - Path relative to the worktree, `/`-separated.
   * @returns The hex digest or null.
   */
  fileHash(relative: string): string | null {
    try {
      return createHash("sha256")
        .update(readFileSync(join(this.path, ...relative.split("/"))))
        .digest("hex");
    } catch {
      return null;
    }
  }

  /**
   * The dirty paths of the worktree (what the tool changed), `/`-separated.
   *
   * @returns The paths.
   */
  async changedPaths(): Promise<string[]> {
    const out = await this.inTree([
      "status",
      "--porcelain=v1",
      "-z",
      "--untracked-files=all",
      "--no-renames",
    ]);
    return out
      .split("\0")
      .filter((record) => record.length > 3)
      .map((record) => record.slice(3).replaceAll("\\", "/"));
  }

  /**
   * Commits the given paths on the detached HEAD.
   *
   * @param paths - Repository-relative paths under `backlog/`.
   * @param message - The commit message (on stdin).
   * @returns The new commit hash.
   * @throws ApiError `refused` when git refuses (the tree is reverted).
   */
  async commit(paths: string[], message: string): Promise<string> {
    const add = await this.git(this.path, ["add", "-A", "--", ...paths]);
    if (add.code !== 0) {
      await this.revert();
      throw new ApiError("refused", `git add in the side worktree failed: ${add.stderr.trim()}`);
    }
    const commit = await this.git(
      this.path,
      ["commit", "-q", "-F", "-", "--", ...paths],
      message.endsWith("\n") ? message : `${message}\n`,
    );
    if (commit.code !== 0) {
      await this.revert();
      throw new ApiError(
        "refused",
        `git commit in the side worktree failed: ${(commit.stderr || commit.stdout).trim()}`,
      );
    }
    return (await this.inTree(["rev-parse", "HEAD"])).trim();
  }

  /**
   * Moves `main` to a commit, only if it still points where the change was based
   * (compare-and-swap).
   *
   * @param commit - The new commit (a descendant of `expectedOld`).
   * @param expectedOld - The commit `main` must still point to.
   * @returns True when `main` was moved; false when it had moved meanwhile.
   */
  async landOnMain(commit: string, expectedOld: string): Promise<boolean> {
    const result = await this.git(this.ctx.repo.root, [
      "update-ref",
      "-m",
      "backlog(app): a change during a run",
      "refs/heads/main",
      commit,
      expectedOld,
    ]);
    return result.code === 0;
  }

  /**
   * The symbolic target of the primary working tree's HEAD (`refs/heads/main` when it is on
   * `main`; the commit when detached).
   *
   * @returns The ref name or the commit.
   */
  async primaryHead(): Promise<string> {
    const result = await this.git(this.ctx.repo.root, ["symbolic-ref", "-q", "HEAD"]);
    if (result.code === 0) return result.stdout.trim();
    return (await this.git(this.ctx.repo.root, ["rev-parse", "HEAD"])).stdout.trim();
  }
}
