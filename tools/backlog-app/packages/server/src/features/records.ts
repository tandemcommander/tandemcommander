// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The records of features: the folders `specs/NNN-*`, what each holds, how far its tasks
 * are, its commits and its entry in `specs/FEATURE-HISTORY.md` (data-model *Feature record*; user
 * story 4, scenario 4).
 *
 * The source follows the board's (research R10): the working tree when it is on `main` and no run
 * holds the run lock - read open-read-close, never kept open - and otherwise `main`'s git objects
 * (`ls-tree`, `show`), so a run's branch and its atomic replaces are never touched. A file is served
 * only by a path found in the feature's own listing; the server builds the path itself and checks
 * that it stays under `specs/` (contracts/security.md, rule 7).
 */

import { readdirSync, readFileSync, type Dirent } from "node:fs";
import { join, resolve, sep } from "node:path";
import { ApiError, foldText, type ItemRow, type ReadRef } from "@backlog-app/shared";
import type { Services } from "../services.ts";
import { git, logEntries, showFile, type LogEntry } from "../repo/git.ts";

/** Form of a feature number in a path. */
export const FEATURE_PATTERN = /^\d{3}$/;

/** Form of a feature folder name: the number, a dash, the short name. */
const FOLDER_PATTERN = /^(\d{3})-([A-Za-z0-9][A-Za-z0-9._-]*)$/;

/** The documents of a feature folder, in the order the feature page shows them. */
export const FEATURE_DOCUMENTS = [
  "spec.md",
  "plan.md",
  "tasks.md",
  "fix-log.md",
  "closing-report.md",
  "research.md",
  "data-model.md",
  "quickstart.md",
] as const;

/** Most files listed for one feature (probe folders can hold many outputs). */
const MAX_FILES = 1000;

/** Largest file served as text (bytes). */
const MAX_TEXT_BYTES = 2 * 1024 * 1024;

/** One feature in the list. */
export interface FeatureSummary {
  /** The three-digit number. */
  number: string;
  /** The short name (the folder name without the number). */
  name: string;
  /** The folder name under `specs/`. */
  folder: string;
  /** True when `specs/FEATURE-HISTORY.md` has its entry (the feature was finished). */
  closed: boolean;
  /** Slugs of the backlog items whose header, text or log names the feature. */
  items: string[];
}

/** Everything the feature page shows. */
export interface FeatureRecord extends FeatureSummary {
  /** Where it was read from. */
  ref: ReadRef;
  /** Paths of the folder's files relative to the folder, `/`-separated; the documents first. */
  files: string[];
  /** Progress of `tasks.md` (ticked and all checkboxes), or null without a task list. */
  tasks: { done: number; total: number } | null;
  /** Commits of `main` whose subject starts with `[NNN]`, newest first. */
  commits: LogEntry[];
  /** The feature's entry in `specs/FEATURE-HISTORY.md` (Markdown), or null. */
  history: string | null;
}

/** One file of a feature folder. */
export interface FeatureFile {
  /** Its path relative to the folder. */
  path: string;
  /** Its text, or null when it is binary or too large. */
  text: string | null;
  /** True when the file holds binary data. */
  binary: boolean;
  /** Size in bytes (of the UTF-8 text when read from git). */
  size: number;
}

/** A feature folder found in the listing. */
interface FeatureFolder {
  /** The number. */
  number: string;
  /** The short name. */
  name: string;
  /** The folder name. */
  folder: string;
}

/**
 * Removes a byte-order mark the Markdown files of the repository may start with.
 *
 * @param text - File text.
 * @returns The text without a leading BOM.
 */
export function stripBom(text: string): string {
  return text.startsWith("﻿") ? text.slice(1) : text;
}

/**
 * Splits `specs/FEATURE-HISTORY.md` into its entries: every top-level list line `- NNN-name: ...`
 * up to the next such line or heading.
 *
 * @param text - The file text.
 * @returns The entry text (Markdown, without trailing blank lines) by feature number.
 */
export function historyEntries(text: string): Map<string, string> {
  const entries = new Map<string, string>();
  let number: string | null = null;
  let lines: string[] = [];
  /** Stores the entry being collected. */
  const flush = (): void => {
    if (number !== null && !entries.has(number)) entries.set(number, lines.join("\n").trimEnd());
    number = null;
    lines = [];
  };
  for (const line of stripBom(text).replace(/\r\n/g, "\n").split("\n")) {
    const start = /^- (\d{3})-/.exec(line);
    if (start) {
      flush();
      number = start[1]!;
      lines = [line];
    } else if (/^#{1,6}\s/.test(line) || (/^\S/.test(line) && !line.startsWith("- "))) {
      // A heading or an unindented paragraph ends the entry.
      flush();
    } else if (number !== null) {
      if (line.startsWith("- ")) flush();
      else lines.push(line);
    }
  }
  flush();
  return entries;
}

/**
 * Which features each item names: its `feature` header, or a mention in its text or log such as
 * `feature 243`, `specs/243-...`, `review:243`, `[243]` or `243-some-name`.
 *
 * @param rows - Item rows with their bodies.
 * @returns Slugs by feature number.
 */
export function featureMentions(rows: readonly ItemRow[]): Map<string, Set<string>> {
  const mentions = new Map<string, Set<string>>();
  /**
   * Records one mention.
   *
   * @param number - The feature number.
   * @param slug - The item.
   */
  const add = (number: string, slug: string): void => {
    const set = mentions.get(number) ?? new Set<string>();
    set.add(slug);
    mentions.set(number, set);
  };
  const pattern =
    /(?:\bfeatures?\s+|\bspecs\/|\b(?:review|leftover|measure|probe):)(\d{3})\b|\[(\d{3})\]|\b(\d{3})-[a-z]/gi;
  for (const row of rows) {
    if (row.feature && FEATURE_PATTERN.test(row.feature)) add(row.feature, row.slug);
    const text = `${row.source}\n${row.body ?? ""}`;
    for (const match of text.matchAll(pattern)) add((match[1] ?? match[2] ?? match[3])!, row.slug);
  }
  return mentions;
}

/**
 * The progress of a task list: ticked and all checkboxes of list lines.
 *
 * @param text - The text of `tasks.md`.
 * @returns The counts, or null when the file has no checkbox.
 */
export function taskProgress(text: string): { done: number; total: number } | null {
  const done = (text.match(/^\s*[-*] \[[xX]\]/gm) ?? []).length;
  const open = (text.match(/^\s*[-*] \[ \]/gm) ?? []).length;
  return done + open > 0 ? { done, total: done + open } : null;
}

/**
 * Orders a feature's files: the known documents in their order, then everything else by name.
 *
 * @param files - Relative paths.
 * @returns The sorted paths.
 */
function orderFiles(files: string[]): string[] {
  /**
   * The place of a path among the known documents.
   *
   * @param path - A relative path.
   * @returns Its index, or the number of documents for any other file.
   */
  const rank = (path: string): number => {
    const index = (FEATURE_DOCUMENTS as readonly string[]).indexOf(path);
    return index >= 0 ? index : FEATURE_DOCUMENTS.length;
  };
  return [...files].sort((a, b) => rank(a) - rank(b) || (a < b ? -1 : a > b ? 1 : 0));
}

/** The feature records of the repository. */
export class FeaturesService {
  /** The server's services. */
  private readonly services: Services;

  /**
   * Creates the service.
   *
   * @param services - The server's services.
   */
  constructor(services: Services) {
    this.services = services;
  }

  /**
   * The repository root.
   *
   * @returns Its absolute path.
   */
  private get root(): string {
    return this.services.ctx.repo.root;
  }

  /**
   * Reads a text file of the repository from the source (open-read-close or `main`'s objects).
   *
   * @param ref - The source.
   * @param path - Path relative to the root, `/`-separated (built by the server).
   * @returns The text without a BOM, or null when the file does not exist.
   */
  private async readText(ref: ReadRef, path: string): Promise<string | null> {
    if (ref === "main") {
      const text = await showFile(this.root, "main", path);
      return text === null ? null : stripBom(text);
    }
    try {
      return stripBom(readFileSync(join(this.root, ...path.split("/")), "utf8"));
    } catch {
      return null;
    }
  }

  /**
   * The feature folders under `specs/`, ordered by number (the first folder of a number wins).
   *
   * @param ref - The source.
   * @returns The folders.
   */
  private async folders(ref: ReadRef): Promise<FeatureFolder[]> {
    let names: string[];
    if (ref === "main") {
      const out = await git(this.root, ["ls-tree", "-d", "-z", "--name-only", "main", "--", "specs/"]).catch(
        () => "",
      );
      names = out
        .split("\0")
        .filter(Boolean)
        .map((path) => path.replace(/^specs\//, ""));
    } else {
      try {
        names = readdirSync(join(this.root, "specs"), { withFileTypes: true })
          .filter((entry) => entry.isDirectory())
          .map((entry) => entry.name);
      } catch {
        names = [];
      }
    }
    const seen = new Set<string>();
    const folders: FeatureFolder[] = [];
    for (const folder of names.sort()) {
      const match = FOLDER_PATTERN.exec(folder);
      if (!match || seen.has(match[1]!)) continue;
      seen.add(match[1]!);
      folders.push({ number: match[1]!, name: match[2]!, folder });
    }
    return folders;
  }

  /**
   * The files of a feature folder, relative to it.
   *
   * @param ref - The source.
   * @param folder - The folder name (from {@link FeaturesService.folders}).
   * @returns The relative paths, the documents first.
   */
  private async listFiles(ref: ReadRef, folder: string): Promise<string[]> {
    const prefix = `specs/${folder}/`;
    let files: string[] = [];
    if (ref === "main") {
      const out = await git(this.root, ["ls-tree", "-r", "-z", "--name-only", "main", "--", prefix]);
      files = out
        .split("\0")
        .filter((path) => path.startsWith(prefix))
        .map((path) => path.slice(prefix.length));
    } else {
      /**
       * Collects the files below a folder, depth first.
       *
       * @param absolute - The folder on disk.
       * @param relative - Its path relative to the feature folder (`""` or `contracts/`).
       */
      const walk = (absolute: string, relative: string): void => {
        let entries: Dirent[];
        try {
          entries = readdirSync(absolute, { withFileTypes: true });
        } catch {
          return;
        }
        for (const entry of entries) {
          if (files.length >= MAX_FILES) return;
          if (entry.isDirectory()) walk(join(absolute, entry.name), `${relative}${entry.name}/`);
          else if (entry.isFile()) files.push(`${relative}${entry.name}`);
        }
      };
      walk(join(this.root, "specs", folder), "");
    }
    return orderFiles(files.slice(0, MAX_FILES));
  }

  /**
   * The items of the board with their bodies (from the read model).
   *
   * @returns The item rows.
   */
  private async itemRows(): Promise<ItemRow[]> {
    const snapshot = this.services.read.peek() ?? (await this.services.read.snapshot().catch(() => null));
    if (!snapshot) return [];
    return snapshot.board.sections.flatMap((section) =>
      section.rows.filter((row): row is ItemRow => row.kind === "item"),
    );
  }

  /**
   * Every feature, newest number first.
   *
   * @param query - Optional filter on the number and name (accent- and case-insensitive).
   * @returns The features.
   */
  async list(query = ""): Promise<FeatureSummary[]> {
    const ref = this.services.source();
    const [folders, historyText, rows] = await Promise.all([
      this.folders(ref),
      this.readText(ref, "specs/FEATURE-HISTORY.md"),
      this.itemRows(),
    ]);
    const history = historyEntries(historyText ?? "");
    const mentions = featureMentions(rows);
    const wanted = foldText(query.trim());
    return folders
      .filter((f) => !wanted || foldText(`${f.number} ${f.name}`).includes(wanted))
      .reverse()
      .map((f) => ({
        number: f.number,
        name: f.name,
        folder: f.folder,
        closed: history.has(f.number),
        items: [...(mentions.get(f.number) ?? [])].sort(),
      }));
  }

  /**
   * The folder of a feature number.
   *
   * @param ref - The source.
   * @param number - The number (any text; validated here).
   * @returns The folder.
   * @throws ApiError `not-found` when the number is malformed or has no folder.
   */
  private async folderOf(ref: ReadRef, number: string): Promise<FeatureFolder> {
    if (!FEATURE_PATTERN.test(number)) throw new ApiError("not-found", "no such feature");
    const folder = (await this.folders(ref)).find((f) => f.number === number);
    if (!folder) throw new ApiError("not-found", "no such feature");
    return folder;
  }

  /**
   * One feature with its files, task progress, commits and history entry.
   *
   * @param number - The feature number.
   * @returns The record.
   * @throws ApiError `not-found` when there is no such feature.
   */
  async feature(number: string): Promise<FeatureRecord> {
    const ref = this.services.source();
    const folder = await this.folderOf(ref, number);
    const [files, historyText, rows, commits] = await Promise.all([
      this.listFiles(ref, folder.folder),
      this.readText(ref, "specs/FEATURE-HISTORY.md"),
      this.itemRows(),
      // `-F` keeps the brackets literal; the subject test below drops mentions in message bodies.
      logEntries(this.root, ["main", "-F", `--grep=[${number}]`]).catch(() => []),
    ]);
    const tasksText = files.includes("tasks.md")
      ? await this.readText(ref, `specs/${folder.folder}/tasks.md`)
      : null;
    const history = historyEntries(historyText ?? "");
    return {
      number: folder.number,
      name: folder.name,
      folder: folder.folder,
      closed: history.has(folder.number),
      items: [...(featureMentions(rows).get(folder.number) ?? [])].sort(),
      ref,
      files,
      tasks: tasksText === null ? null : taskProgress(tasksText),
      commits: commits.filter((c) => c.subject.startsWith(`[${number}]`)),
      history: history.get(folder.number) ?? null,
    };
  }

  /**
   * One file of a feature, by a path that must appear in the feature's own listing.
   *
   * @param number - The feature number.
   * @param path - The requested path relative to the feature folder.
   * @returns The file.
   * @throws ApiError `not-found` for an unknown feature or a path outside its listing.
   */
  async file(number: string, path: string): Promise<FeatureFile> {
    const ref = this.services.source();
    const folder = await this.folderOf(ref, number);
    const files = await this.listFiles(ref, folder.folder);
    // The request text only selects an entry; the path read is the listing's own string.
    const listed = files.find((f) => f === path);
    if (listed === undefined) throw new ApiError("not-found", "no such file of this feature");
    const relative = `specs/${folder.folder}/${listed}`;
    if (ref === "main") {
      const text = await showFile(this.root, "main", relative);
      if (text === null) throw new ApiError("not-found", "the file is not on main");
      const size = Buffer.byteLength(text, "utf8");
      const binary = text.includes("\0");
      return {
        path: listed,
        text: binary || size > MAX_TEXT_BYTES ? null : stripBom(text),
        binary,
        size,
      };
    }
    // Build the absolute path and make sure it stays under `specs/` (ordinal, case-insensitive).
    const specsRoot = resolve(this.root, "specs") + sep;
    const absolute = resolve(this.root, ...relative.split("/"));
    if (!absolute.toLowerCase().startsWith(specsRoot.toLowerCase())) {
      throw new ApiError("not-found", "no such file of this feature");
    }
    let bytes: Buffer;
    try {
      bytes = readFileSync(absolute);
    } catch {
      throw new ApiError("not-found", "the file was removed");
    }
    const binary = bytes.subarray(0, 8000).includes(0);
    return {
      path: listed,
      text: binary || bytes.length > MAX_TEXT_BYTES ? null : stripBom(bytes.toString("utf8")),
      binary,
      size: bytes.length,
    };
  }
}
