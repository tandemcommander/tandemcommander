// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Feature 412 measurement: a temp state folder locked by feature 344's exact icacls call,
 * then one start's `restrictToOwner()`; prints the DACL of every entry. Run from
 * `tools/backlog-app`: `node ../../specs/412-state-files-acl/probe/measure_after.ts`.
 */

import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { StateDir } from "../../../tools/backlog-app/packages/server/src/settings/state-dir.ts";

const system32 = join(process.env["SystemRoot"] ?? "C:\\Windows", "System32");
const base = mkdtempSync(join(tmpdir(), "tc412-measure-"));
const state = new StateDir(join(base, "git"));
mkdirSync(join(state.path, "main-worktree", "backlog"), { recursive: true });
const files = ["events.jsonl", "main-worktree/.git", "main-worktree/backlog/BACKLOG.md"].map((f) =>
  join(state.path, f),
);
for (const f of files) writeFileSync(f, "x\n");
const sid = /"(S-1-[\d-]+)"/.exec(
  spawnSync(join(system32, "whoami.exe"), ["/user", "/fo", "csv", "/nh"], { encoding: "utf8" }).stdout,
)?.[1];
// Feature 344's call, as an earlier start ran it.
spawnSync(join(system32, "icacls.exe"), [
  state.path,
  "/inheritance:r",
  "/grant:r",
  `*${sid}:(OI)(CI)F`,
  "*S-1-5-18:(OI)(CI)F",
  "/T",
  "/C",
  "/Q",
]);

/** Prints the DACL of every file and whether it can be read. */
function show(label: string): void {
  for (const f of files) {
    const dacl = spawnSync(
      join(system32, "WindowsPowerShell", "v1.0", "powershell.exe"),
      ["-NoProfile", "-Command", `(Get-Acl -LiteralPath '${f}').Sddl -replace '^.*?D:','D:'`],
      // Without PowerShell 7's module path (Windows PowerShell could not load Get-Acl).
      {
        encoding: "utf8",
        env: Object.fromEntries(
          Object.entries(process.env).filter(([key]) => key.toUpperCase() !== "PSMODULEPATH"),
        ),
      },
    ).stdout.trim();
    if (!dacl.startsWith("D:")) throw new Error(`Get-Acl failed for ${f}`);
    let readable = "readable";
    try {
      readFileSync(f);
    } catch (error) {
      readable = (error as NodeJS.ErrnoException).code ?? "error";
    }
    console.log(`${label} ${f.slice(state.path.length + 1)}: ${dacl} (${readable})`);
  }
}

show("after 344's start:");
console.log("restrictToOwner:", JSON.stringify(state.restrictToOwner()));
show("after 412's start:");
console.log(`folder left in place for inspection: ${base}`);
