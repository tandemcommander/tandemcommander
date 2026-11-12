// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the side worktree of `main` (feature 371, research R1, R2): creation (sparse,
 * detached), sync after `main` moved, a commit on the detached HEAD landed on `main` with the
 * compare-and-swap, the swap refused when `main` moved meanwhile (and the tree reverted), a
 * dirty worktree repaired, the folder deleted and recreated, and the primary HEAD read.
 */

import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
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

  it("keeps a file directly under specs/ a file and lands ten changes in a row (426)", async () => {
    // The real repository has specs/FEATURE-HISTORY.md besides the feature folders; the old sync
    // made a folder of it and then could never check main out again. A folder named backlog
    // deeper in the tree is not part of the sparse set.
    writeFileSync(join(root, "specs", "FEATURE-HISTORY.md"), "# History\n");
    mkdirSync(join(root, "tools", "x", "backlog"), { recursive: true });
    writeFileSync(join(root, "tools", "x", "backlog", "a.txt"), "a\n");
    await gitIn(root, ["add", "-A"]);
    await gitIn(root, ["commit", "-q", "-m", "a history file"]);
    await gitIn(root, ["checkout", "-q", "-b", "345-a-run"]);
    const overview = join(worktree.path, "backlog", "BACKLOG.md");
    for (let round = 1; round <= 10; round++) {
      const base = await mainCommit();
      await worktree.sync(base);
      const history = join(worktree.path, "specs", "FEATURE-HISTORY.md");
      expect(existsSync(history) && statSync(history).isDirectory()).toBe(false);
      expect(existsSync(join(worktree.path, "specs", "243-example"))).toBe(true);
      expect(existsSync(join(worktree.path, "tools"))).toBe(false);
      writeFileSync(overview, readFileSync(overview, "utf8") + `\n<!-- round ${round} -->\n`);
      const hash = await worktree.commit(["backlog/BACKLOG.md"], `backlog(app): round ${round}\n`);
      expect(await worktree.landOnMain(hash, base)).toBe(true);
      // main changes the history file meanwhile (a run's merge), as on 2026-11-12.
      await gitIn(root, ["checkout", "-q", "main"]);
      writeFileSync(join(root, "specs", "FEATURE-HISTORY.md"), `# History\n- ${round}\n`);
      await gitIn(root, ["commit", "-q", "-am", `history ${round}`]);
      await gitIn(root, ["checkout", "-q", "345-a-run"]);
    }
    expect(
      (await gitIn(root, ["log", "--format=%s", "main"]))
        .split("\n")
        .filter((s) => s.startsWith("backlog(app): round")),
    ).toHaveLength(10);
  });

  it("brings a dirty worktree back to main: a folder at a file's path, a deleted and a changed file (426)", async () => {
    writeFileSync(join(root, "specs", "FEATURE-HISTORY.md"), "# History\n");
    await gitIn(root, ["add", "-A"]);
    await gitIn(root, ["commit", "-q", "-m", "a history file"]);
    await worktree.ensure();
    // The state the old sync left: an empty folder where the tracked file belongs ...
    const history = join(worktree.path, "specs", "FEATURE-HISTORY.md");
    rmSync(history, { force: true });
    mkdirSync(history, { recursive: true });
    // ... and other damage of a crashed change.
    rmSync(join(worktree.path, "backlog", "RUNS.md"));
    writeFileSync(join(worktree.path, "backlog", "BACKLOG.md"), "broken");
    // main moves on, changing the file the folder stands in for.
    writeFileSync(join(root, "specs", "FEATURE-HISTORY.md"), "# History\n- moved\n");
    await gitIn(root, ["commit", "-q", "-am", "history moved"]);
    const moved = await mainCommit();
    await worktree.sync(moved);
    expect((await gitIn(worktree.path, ["rev-parse", "HEAD"])).trim()).toBe(moved);
    expect((await gitIn(worktree.path, ["status", "--porcelain", "--untracked-files=all"])).trim()).toBe("");
    expect(existsSync(join(worktree.path, "backlog", "RUNS.md"))).toBe(true);
    expect(readFileSync(join(worktree.path, "backlog", "BACKLOG.md"), "utf8")).not.toBe("broken");
    expect(existsSync(history) && statSync(history).isDirectory()).toBe(false);
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
        // A worktree folder that cannot be listed is refused the same way, never deleted.
        expect(spawnSync(icacls, [worktree.path, "/inheritance:r", "/Q"], { windowsHide: true }).status).toBe(
          0,
        );
        expect(await worktree.exists()).toBe(false);
        await expect(worktree.sync(base)).rejects.toThrow(/cannot be read/);
        expect(existsSync(worktree.path)).toBe(true);
        expect(new StateDir(join(root, ".git")).restrictToOwner()).toEqual({
          private: true,
          contents: "reset",
        });
        expect(existsSync(join(worktree.path, "backlog", "BACKLOG.md"))).toBe(true);
        await worktree.sync(base);
        expect((await gitIn(worktree.path, ["rev-parse", "HEAD"])).trim()).toBe(base);
      } finally {
        spawnSync(icacls, [worktree.path, "/reset", "/T", "/C", "/Q"], { windowsHide: true });
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
