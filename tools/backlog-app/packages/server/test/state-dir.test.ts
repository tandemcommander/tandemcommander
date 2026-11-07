// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the state folder's permissions (feature 412, amends review M2 of 344): after
 * `restrictToOwner()` every entry of the folder - files, a hidden `.git`, nested folders - is
 * readable, writable and deletable by the user and grants nobody but the user and SYSTEM; entries
 * an earlier start locked (an empty protected DACL) are repaired; a folder that cannot be listed
 * is made listable; a junction to a folder outside is never followed. The ACL cases run only on
 * Windows.
 */

import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { StateDir } from "../src/settings/state-dir.ts";

/** System32 of this machine. */
const SYSTEM32 = join(process.env["SystemRoot"] ?? "C:\\Windows", "System32");

/** SYSTEM's SID string in SDDL. */
const SYSTEM_SDDL = "SY";

/**
 * Runs a System32 tool and fails the test on a non-zero exit.
 *
 * @param tool - The executable name.
 * @param args - Its arguments.
 * @returns Its stdout.
 */
function run(tool: string, args: string[]): string {
  const result = spawnSync(join(SYSTEM32, tool), args, { encoding: "utf8", windowsHide: true });
  if (result.status !== 0) throw new Error(`${tool} ${args.join(" ")}: ${result.stdout}${result.stderr}`);
  return result.stdout;
}

/**
 * The SID of the user running the tests.
 *
 * @returns The SID string.
 */
function userSid(): string {
  const sid = /"(S-1-[\d-]+)"/.exec(run("whoami.exe", ["/user", "/fo", "csv", "/nh"]))?.[1];
  if (!sid) throw new Error("no SID");
  return sid;
}

/**
 * The DACL part (`D:...`) of the security descriptors of several paths, in one PowerShell call.
 *
 * @param paths - Absolute paths.
 * @returns The DACL strings, in order.
 */
function daclsOf(paths: string[]): string[] {
  const list = paths.map((p) => `'${p.replaceAll("'", "''")}'`).join(",");
  const script = `foreach ($p in @(${list})) { ((Get-Acl -LiteralPath $p).Sddl -replace '^.*?D:', 'D:') -replace 'S:.*$', '' }`;
  const result = spawnSync(
    join(SYSTEM32, "WindowsPowerShell", "v1.0", "powershell.exe"),
    ["-NoProfile", "-NonInteractive", "-Command", script],
    // Without PowerShell 7's module path, which keeps Windows PowerShell from loading Get-Acl
    // when the tests start from pwsh (review 1 of 412).
    { encoding: "utf8", windowsHide: true, env: withoutModulePath() },
  );
  const dacls = result.stdout.split(/\r?\n/).filter((line) => line.startsWith("D:"));
  if (result.status !== 0 || dacls.length !== paths.length) throw new Error(`Get-Acl: ${result.stderr}`);
  return dacls;
}

/**
 * The environment without `PSModulePath` (any case).
 *
 * @returns A copy of the environment.
 */
function withoutModulePath(): NodeJS.ProcessEnv {
  return Object.fromEntries(
    Object.entries(process.env).filter(([key]) => key.toUpperCase() !== "PSMODULEPATH"),
  );
}

/**
 * The ACE strings of a DACL (the bodies of the parentheses of `D:PAI(A;..)(A;..)`).
 *
 * @param dacl - The DACL string.
 * @returns The ACEs.
 */
function acesOf(dacl: string): string[] {
  return [...dacl.matchAll(/\(([^)]*)\)/g)].map((match) => match[1] ?? "");
}

/**
 * Asserts that an entry inside the state folder inherits only the user's and SYSTEM's access.
 *
 * @param dacl - The entry's DACL.
 * @param sid - The user's SID.
 */
function expectInheritsOwnerOnly(dacl: string, sid: string): void {
  expect(dacl.startsWith("D:P")).toBe(false);
  const aces = acesOf(dacl);
  expect(aces.length).toBeGreaterThan(0);
  for (const ace of aces) {
    const [, flags, , , , trustee] = ace.split(";");
    expect(flags).toContain("ID");
    expect([SYSTEM_SDDL, sid]).toContain(trustee);
  }
  expect(aces.some((ace) => ace.endsWith(`;${sid}`))).toBe(true);
}

/**
 * Locks an entry the way feature 344's start did: inheritance removed, nothing granted.
 *
 * @param path - The entry.
 */
function lockEntry(path: string): void {
  run("icacls.exe", [path, "/inheritance:r", "/Q"]);
}

/**
 * Gives an entry and everything under it back the access inherited from its parent (test
 * cleanup; links are removed before).
 *
 * @param path - The entry.
 */
function unlockTree(path: string): void {
  spawnSync(join(SYSTEM32, "icacls.exe"), [path, "/reset", "/T", "/C", "/Q"], { windowsHide: true });
}

describe.skipIf(process.platform !== "win32")("StateDir.restrictToOwner on Windows", () => {
  let base = "";
  let state: StateDir;
  let sid = "";
  let links: string[] = [];

  beforeEach(() => {
    base = mkdtempSync(join(tmpdir(), "tc412-"));
    state = new StateDir(join(base, "git"));
    sid = userSid();
  });

  afterEach(() => {
    // The links go first: the cleanup's /T would follow them.
    for (const link of links) unlinkSync(link);
    links = [];
    unlockTree(base);
    rmSync(base, { recursive: true, force: true });
  });

  /**
   * Fills the state folder: two files, a hidden `.git`, a nested folder with a file.
   *
   * @returns The files.
   */
  function fill(): string[] {
    mkdirSync(join(state.path, "main-worktree", "backlog", "items"), { recursive: true });
    const files = [
      join(state.path, "events.jsonl"),
      join(state.path, "main-worktree", ".git"),
      join(state.path, "main-worktree", "backlog", "items", "desc.md"),
    ];
    for (const file of files) writeFileSync(file, "text\n");
    run("attrib.exe", ["+h", files[1] ?? ""]);
    return files;
  }

  /**
   * Asserts that the user can read, write and delete every file.
   *
   * @param files - The files.
   */
  function expectUsable(files: string[]): void {
    for (const file of files) {
      expect(readFileSync(file, "utf8")).toBe("text\n");
      run("attrib.exe", ["-h", file]);
      writeFileSync(file, "changed\n");
      expect(readFileSync(file, "utf8")).toBe("changed\n");
      rmSync(file);
      expect(existsSync(file)).toBe(false);
    }
  }

  it("keeps every file, the hidden .git and nested folders usable, granted to the user and SYSTEM only", () => {
    const files = fill();
    expect(state.restrictToOwner()).toEqual({ private: true, contents: "reset" });
    const [folder, ...entries] = daclsOf([
      state.path,
      join(state.path, "main-worktree"),
      join(state.path, "main-worktree", "backlog", "items"),
      ...files,
    ]);
    // The folder itself: protected, owner and SYSTEM, inheritable.
    expect(folder?.startsWith("D:PAI")).toBe(true);
    for (const ace of acesOf(folder ?? "")) {
      expect(ace.split(";")[1]).toBe("OICI");
      expect([SYSTEM_SDDL, sid]).toContain(ace.split(";")[5]);
    }
    expect(entries).toHaveLength(5);
    for (const dacl of entries) expectInheritsOwnerOnly(dacl, sid);
    expectUsable(files);
  });

  it("repairs files an earlier start locked", () => {
    const files = fill();
    for (const file of files) lockEntry(file);
    // Control: the locked file cannot be read.
    expect(() => readFileSync(files[0] ?? "")).toThrow();
    expect(state.restrictToOwner()).toEqual({ private: true, contents: "reset" });
    for (const dacl of daclsOf(files)) expectInheritsOwnerOnly(dacl, sid);
    expectUsable(files);
  });

  it("makes a folder that cannot be listed listable and repairs its files", () => {
    const files = fill();
    const inner = join(state.path, "main-worktree", "backlog");
    for (const file of files) lockEntry(file);
    lockEntry(inner);
    expect(state.restrictToOwner()).toEqual({ private: true, contents: "reset" });
    for (const dacl of daclsOf([inner, ...files])) expectInheritsOwnerOnly(dacl, sid);
    expectUsable(files);
  });

  it("succeeds on an empty folder", () => {
    expect(state.restrictToOwner()).toEqual({ private: true, contents: "reset" });
  });

  it("never follows a junction to a folder outside", () => {
    const files = fill();
    for (const file of files) lockEntry(file);
    const outside = join(base, "outside");
    mkdirSync(outside);
    const outsideFile = join(outside, "keep.txt");
    writeFileSync(outsideFile, "outside\n");
    // An explicit ACE a reset would remove: Users may read.
    run("icacls.exe", [outsideFile, "/grant", "*S-1-5-32-545:(R)", "/Q"]);
    const before = daclsOf([outsideFile])[0] ?? "";
    expect(before).toContain(";;FR;;;BU)");
    const link = join(state.path, "link");
    symlinkSync(outside, link, "junction");
    links.push(link);
    expect(state.restrictToOwner()).toEqual({ private: true, contents: "reset" });
    expect(daclsOf([outsideFile])[0]).toBe(before);
    for (const dacl of daclsOf(files)) expectInheritsOwnerOnly(dacl, sid);
    expectUsable(files);
  });

  it("never follows a file symbolic link to a file outside (the folder-by-folder reset's /L)", (ctx) => {
    const files = fill();
    const outside = join(base, "outside");
    mkdirSync(outside);
    const outsideFile = join(outside, "keep.txt");
    writeFileSync(outsideFile, "outside\n");
    run("icacls.exe", [outsideFile, "/grant", "*S-1-5-32-545:(R)", "/Q"]);
    const before = daclsOf([outsideFile])[0] ?? "";
    expect(before).toContain(";;FR;;;BU)");
    const link = join(state.path, "file-link");
    try {
      symlinkSync(outsideFile, link, "file");
    } catch {
      // Creating a file symbolic link needs Developer Mode or the privilege.
      ctx.skip();
      return;
    }
    links.push(link);
    expect(state.restrictToOwner()).toEqual({ private: true, contents: "reset" });
    expect(daclsOf([outsideFile])[0]).toBe(before);
    for (const dacl of daclsOf(files)) expectInheritsOwnerOnly(dacl, sid);
    expectUsable(files);
  });
});
