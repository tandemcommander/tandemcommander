// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the side worktree of `main` (feature 371, research R1, R2): creation (sparse,
 * detached), sync after `main` moved, a commit on the detached HEAD landed on `main` with the
 * compare-and-swap, the swap refused when `main` moved meanwhile (and the tree reverted), a
 * dirty worktree repaired, the folder deleted and recreated, and the primary HEAD read.
 */

import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { SideWorktree } from "../src/backlog/side-worktree.ts";
import type { ServerContext } from "../src/context.ts";
import { EventHub } from "../src/events/hub.ts";
import { repoPaths } from "../src/repo/git.ts";
import { StateDir } from "../src/settings/state-dir.ts";
import { fixtureRepo, gitIn } from "./helpers/fixture-repo.ts";

let root = "";
let cleanup: () => void = () => undefined;
let worktree: SideWorktree;

/**
 * A server context of the fixture.
 *
 * @returns The context.
 */
async function contextOf(): Promise<ServerContext> {
  const repo = await repoPaths(root);
  return { repo, state: new StateDir(repo.commonDir), hub: new EventHub(), dev: false, loopTestArgs: [] };
}

/**
 * The commit `main` points to.
 *
 * @returns The hash.
 */
async function mainCommit(): Promise<string> {
  return (await gitIn(root, ["rev-parse", "main"])).trim();
}

beforeEach(async () => {
  ({ root, cleanup } = await fixtureRepo());
  worktree = new SideWorktree(await contextOf());
});

afterEach(() => {
  cleanup();
});

describe("SideWorktree", () => {
  it("is created sparse and detached at main, inside the app's state folder", async () => {
    expect(await worktree.exists()).toBe(false);
    await worktree.ensure();
    expect(await worktree.exists()).toBe(true);
    expect(worktree.path.replaceAll("\\", "/")).toContain("/.git/tandem-backlog-app/main-worktree");
    expect(existsSync(join(worktree.path, "backlog", "BACKLOG.md"))).toBe(true);
    // Sparse: the sources of the fixture are not checked out, the spec folders are.
    expect(existsSync(join(worktree.path, "tools"))).toBe(false);
    expect((await gitIn(worktree.path, ["rev-parse", "--abbrev-ref", "HEAD"])).trim()).toBe("HEAD");
    expect((await gitIn(worktree.path, ["rev-parse", "HEAD"])).trim()).toBe(await mainCommit());
    const list = await gitIn(root, ["worktree", "list"]);
    expect(list).toContain("main-worktree");
    expect(list).not.toContain("[main]\n" + worktree.path);
  });

  it("syncs to main after main moved, and lands a commit on main with the compare-and-swap", async () => {
    await worktree.ensure();
    const first = await mainCommit();
    // main moves in the primary tree (as a run's fast-forward would).
    writeFileSync(
      join(root, "backlog", "RUNS.md"),
      readFileSync(join(root, "backlog", "RUNS.md"), "utf8") + "\n",
    );
    await gitIn(root, ["commit", "-q", "-am", "moved"]);
    const second = await mainCommit();
    expect(second).not.toBe(first);
    await worktree.sync(second);
    expect((await gitIn(worktree.path, ["rev-parse", "HEAD"])).trim()).toBe(second);
    // The primary tree is on a run's branch (research R2: main is moved only then - with main
    // checked out there, the move would make the primary tree look modified).
    await gitIn(root, ["checkout", "-q", "-b", "345-a-run"]);
    // A change in the worktree, committed there, moves main; the primary tree is untouched.
    const overview = join(worktree.path, "backlog", "BACKLOG.md");
    writeFileSync(overview, readFileSync(overview, "utf8") + "\n<!-- side -->\n");
    const hash = await worktree.commit(["backlog/BACKLOG.md"], "backlog(app): a side change\n\n- side\n");
    expect(hash).not.toBe(second);
    expect(await worktree.landOnMain(hash, second)).toBe(true);
    expect(await mainCommit()).toBe(hash);
    expect((await gitIn(root, ["log", "-1", "--format=%s", "main"])).trim()).toBe(
      "backlog(app): a side change",
    );
    expect(await gitIn(root, ["status", "--porcelain"])).toBe("");
    expect(readFileSync(join(root, "backlog", "BACKLOG.md"), "utf8")).not.toContain("<!-- side -->");
  });

  it("refuses to land when main moved meanwhile, and the tree is reverted", async () => {
    await worktree.ensure();
    const base = await mainCommit();
    await worktree.sync(base);
    const overview = join(worktree.path, "backlog", "BACKLOG.md");
    writeFileSync(overview, readFileSync(overview, "utf8") + "\n<!-- side -->\n");
    const hash = await worktree.commit(["backlog/BACKLOG.md"], "backlog(app): late\n");
    // main moved in between (the run's return).
    writeFileSync(
      join(root, "backlog", "RUNS.md"),
      readFileSync(join(root, "backlog", "RUNS.md"), "utf8") + "\n",
    );
    await gitIn(root, ["commit", "-q", "-am", "the run returned"]);
    const moved = await mainCommit();
    expect(await worktree.landOnMain(hash, base)).toBe(false);
    expect(await mainCommit()).toBe(moved);
    await worktree.revert();
    await worktree.sync(moved);
    expect(readFileSync(overview, "utf8")).not.toContain("<!-- side -->");
    expect((await gitIn(worktree.path, ["status", "--porcelain"])).trim()).toBe("");
  });

  it("repairs a dirty worktree and recreates a deleted one", async () => {
    await worktree.ensure();
    const base = await mainCommit();
    writeFileSync(join(worktree.path, "backlog", "stray.md"), "x");
    writeFileSync(join(worktree.path, "backlog", "RUNS.md"), "broken");
    await worktree.sync(base);
    expect(existsSync(join(worktree.path, "backlog", "stray.md"))).toBe(false);
    expect(readFileSync(join(worktree.path, "backlog", "RUNS.md"), "utf8")).not.toBe("broken");
    rmSync(worktree.path, { recursive: true, force: true });
    expect(await worktree.exists()).toBe(false);
    await worktree.sync(base);
    expect(await worktree.exists()).toBe(true);
    expect(existsSync(join(worktree.path, "backlog", "BACKLOG.md"))).toBe(true);
    // A folder without git's record (a crash between the two creation steps) is replaced too.
    rmSync(worktree.path, { recursive: true, force: true });
    await gitIn(root, ["worktree", "prune"]);
    mkdirSync(worktree.path, { recursive: true });
    writeFileSync(join(worktree.path, "leftover.txt"), "x");
    await worktree.sync(base);
    expect(existsSync(join(worktree.path, "leftover.txt"))).toBe(false);
    expect(await worktree.exists()).toBe(true);
  });

  it.skipIf(process.platform !== "win32")(
    "refuses an unreadable .git without deleting the worktree, and works again after the start's repair (412)",
    async () => {
      await worktree.ensure();
      const base = await mainCommit();
      const dotGit = join(worktree.path, ".git");
      const icacls = join(process.env["SystemRoot"] ?? "C:\\Windows", "System32", "icacls.exe");
      // The lock a start of feature 344 left: inheritance removed, nothing granted.
      expect(spawnSync(icacls, [dotGit, "/inheritance:r", "/Q"], { windowsHide: true }).status).toBe(0);
      try {
        expect(() => readFileSync(dotGit)).toThrow();
        expect(await worktree.exists()).toBe(false);
        await expect(worktree.sync(base)).rejects.toThrow(/cannot be read/);
        expect(existsSync(join(worktree.path, "backlog", "BACKLOG.md"))).toBe(true);
        // The next start of the app repairs the state folder.
        expect(new StateDir(join(root, ".git")).restrictToOwner()).toEqual({
          private: true,
          contents: "reset",
        });
        expect(await worktree.exists()).toBe(true);
        await worktree.sync(base);
        expect((await gitIn(worktree.path, ["rev-parse", "HEAD"])).trim()).toBe(base);
      } finally {
        spawnSync(icacls, [dotGit, "/reset", "/Q"], { windowsHide: true });
      }
    },
  );

  it("reads the primary tree's HEAD: main, a branch, detached", async () => {
    expect(await worktree.primaryHead()).toBe("refs/heads/main");
    await gitIn(root, ["checkout", "-q", "-b", "345-x"]);
    expect(await worktree.primaryHead()).toBe("refs/heads/345-x");
    await gitIn(root, ["checkout", "-q", "--detach"]);
    expect(await worktree.primaryHead()).toBe(await gitIn(root, ["rev-parse", "HEAD"]).then((s) => s.trim()));
  });

  it("hashes and lists files of the worktree", async () => {
    await worktree.ensure();
    expect(worktree.fileHash("backlog/BACKLOG.md")).toMatch(/^[0-9a-f]{64}$/);
    expect(worktree.fileHash("backlog/nothing.md")).toBeNull();
    writeFileSync(join(worktree.path, "backlog", "new.md"), "x");
    expect(await worktree.changedPaths()).toEqual(["backlog/new.md"]);
    await worktree.revert();
    expect(await worktree.changedPaths()).toEqual([]);
  });
});
