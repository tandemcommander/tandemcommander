// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Repository rules every source file of the backlog app obeys (FR-050, research R22, R24).
 *
 * The rules ESLint cannot express are checked here, file by file:
 * - the SPDX header (copyright holder and licence) in the first lines;
 * - a file overview (`@file`) in every script and component;
 * - UTF-8 without a byte-order mark, and LF line ends only;
 * - no process started through a shell and no `exec` call (research R7).
 */

import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

/** Root folder of the backlog app (`tools/backlog-app`). */
const appRoot = fileURLToPath(new URL("..", import.meta.url));

/** Folders (relative to the app root) whose files are checked, recursively. */
const checkedFolders = [
  "packages/shared/src",
  "packages/shared/test",
  "packages/server/src",
  "packages/server/test",
  "packages/web/src",
  "packages/web/test",
  "packages/web/public",
  "e2e",
  "test",
];

/** Single files at the app root that are checked too (configuration written as code). */
const checkedRootFiles = ["eslint.config.js", "vitest.config.ts", "playwright.config.ts"];

/** File extensions that are source code and need the SPDX header and a file overview. */
const codeExtensions = [".ts", ".tsx", ".js", ".mjs"];

/** File extensions that are text and need the SPDX header, but have no doc-comment syntax for `@file`. */
const textExtensions = [".css", ".html", ".md"];

/** Folder names that are never descended into. */
const skippedFolders = new Set(["node_modules", "dist", "fixtures-out"]);

/**
 * Lists every file below a folder, depth first, skipping generated folders.
 *
 * @param folder - Absolute folder path; a missing folder yields no files.
 * @returns Absolute paths of the files found.
 */
function walk(folder: string): string[] {
  let names: string[];
  try {
    names = readdirSync(folder);
  } catch {
    return [];
  }
  const files: string[] = [];
  for (const name of names) {
    const path = join(folder, name);
    if (statSync(path).isDirectory()) {
      if (!skippedFolders.has(name)) files.push(...walk(path));
    } else {
      files.push(path);
    }
  }
  return files;
}

/**
 * Collects the files the rules apply to: code and text files of the checked folders and the root
 * configuration files. Data files (JSON, recorded traces) are not source and are not checked.
 *
 * @returns Absolute paths, sorted for stable test names.
 */
function checkedFiles(): string[] {
  const files = checkedFolders.flatMap((folder) => walk(join(appRoot, folder)));
  files.push(...checkedRootFiles.map((name) => join(appRoot, name)));
  return files
    .filter((path) => [...codeExtensions, ...textExtensions].some((ext) => path.endsWith(ext)))
    .filter((path) => !path.includes(`${join("test", "fixtures")}`))
    .sort();
}

// The forbidden patterns are assembled from parts so that this file does not match itself.
/** Text that would start a process through a shell. */
const shellTrue = ["shell", ": ", "true"].join("");
/** Text of a call of child_process.exec / execSync. */
const execCall = /\bexec(Sync)?\(/;

describe("repository rules of the backlog app", () => {
  const files = checkedFiles();

  it("finds the files to check", () => {
    expect(files.length).toBeGreaterThan(0);
  });

  for (const path of files) {
    const name = relative(appRoot, path).replaceAll("\\", "/");
    it(`${name}: UTF-8 without BOM, LF, SPDX header, overview, no shell`, () => {
      const bytes = readFileSync(path);
      // A byte-order mark breaks JSON parsers and is not used outside the C++ sources.
      expect(bytes.subarray(0, 3).equals(Buffer.from([0xef, 0xbb, 0xbf])), "no BOM").toBe(false);
      // `fatal: true` throws on invalid UTF-8 instead of replacing it silently.
      const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
      expect(text.includes("\r"), "LF line ends only").toBe(false);
      const head = text.split("\n").slice(0, 6).join("\n");
      expect(head, "SPDX copyright").toContain("SPDX-FileCopyrightText: 2026 Pavel Stupka");
      expect(head, "SPDX licence").toContain("SPDX-License-Identifier: GPL-2.0-or-later");
      if (codeExtensions.some((ext) => path.endsWith(ext))) {
        expect(text.slice(0, 2000), "file overview").toMatch(/@file\s+\S/);
      }
      // The two files that define the rule necessarily name the forbidden texts.
      if (!["test/repository-rules.test.ts", "eslint.config.js"].includes(name)) {
        expect(text.includes(shellTrue), "no shell: true").toBe(false);
        expect(execCall.test(text), "no exec / execSync").toBe(false);
      }
    });
  }
});
