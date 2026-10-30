// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Item history and the archive of closed items, read from git (research R16).
 *
 * A closed item's folder is deleted by `backlog.py remove`; it lives on only in git history. The
 * archive lists every removal of an item's `desc.md` and reads the description it had just
 * before, through one `git cat-file --batch` process for all of them. The result is cached per
 * removing commit in the app's state folder, since a commit never changes.
 */

import { z } from "zod";
import type { ClosedItem, HistoryCommit } from "@backlog-app/shared";
import type { ServerContext } from "../context.ts";
import { git, GIT_TIMEOUT_MS, logEntries, showFile } from "../repo/git.ts";
import { runProcess } from "../proc/spawn.ts";

/** The cache file of the archive. */
const CACHE = "cache/closed.json";

/** One cached archive entry. */
const CachedSchema = z.array(
  z.object({
    slug: z.string(),
    title: z.string(),
    type: z.string(),
    area: z.string(),
    severity: z.number().nullable(),
    closedIn: z.object({ hash: z.string(), date: z.string(), subject: z.string() }),
    feature: z.string().nullable(),
  }),
);

/**
 * Reads the header fields of a `desc.md` text (the 15-key block between `---` lines).
 *
 * @param text - The file content.
 * @returns The fields by key.
 */
export function headerFields(text: string): Record<string, string> {
  const fields: Record<string, string> = {};
  const lines = text.replace(/\r\n/g, "\n").split("\n");
  if (lines[0] !== "---") return fields;
  for (const line of lines.slice(1)) {
    if (line === "---") break;
    const colon = line.indexOf(": ");
    if (colon > 0) fields[line.slice(0, colon)] = line.slice(colon + 2);
  }
  return fields;
}

/**
 * Reads several blobs in one `git cat-file --batch` process.
 *
 * @param root - Repository root.
 * @param specs - Object names (`<commit>^:<path>`).
 * @returns The contents, null for a missing object, in the same order.
 */
async function catFileBatch(root: string, specs: string[]): Promise<(string | null)[]> {
  if (specs.length === 0) return [];
  const result = await runProcess("git", ["cat-file", "--batch"], {
    cwd: root,
    timeoutMs: 2 * GIT_TIMEOUT_MS,
    stdin: `${specs.join("\n")}\n`,
  });
  const out = Buffer.from(result.stdout, "utf8");
  const contents: (string | null)[] = [];
  let offset = 0;
  for (let i = 0; i < specs.length; i++) {
    const newline = out.indexOf(0x0a, offset);
    if (newline < 0) break;
    const header = out.subarray(offset, newline).toString("utf8");
    offset = newline + 1;
    if (header.endsWith(" missing")) {
      contents.push(null);
      continue;
    }
    // `<oid> blob <size>`; the size counts bytes, the content is followed by a newline.
    const size = Number(header.split(" ")[2]);
    contents.push(out.subarray(offset, offset + size).toString("utf8"));
    offset += size + 1;
  }
  return contents;
}

/** Item history and the closed-items archive. */
export class HistoryService {
  /** The server context. */
  private readonly ctx: ServerContext;

  /**
   * Creates the service.
   *
   * @param ctx - The server context.
   */
  constructor(ctx: ServerContext) {
    this.ctx = ctx;
  }

  /**
   * Every commit that changed an item's description, newest first (also after its removal).
   *
   * @param slug - The item (validated by the caller).
   * @returns The commits.
   */
  async itemHistory(slug: string): Promise<HistoryCommit[]> {
    return logEntries(this.ctx.repo.root, ["main", "--", `backlog/items/${slug}/desc.md`]);
  }

  /**
   * The description of an item at a commit (at a removing commit: just before it).
   *
   * @param slug - The item.
   * @param hash - A commit from its history (validated as hex by the caller).
   * @returns The Markdown, or null when the item did not exist there.
   */
  async itemAt(slug: string, hash: string): Promise<string | null> {
    const path = `backlog/items/${slug}/desc.md`;
    return (
      (await showFile(this.ctx.repo.root, hash, path)) ??
      (await showFile(this.ctx.repo.root, `${hash}^`, path))
    );
  }

  /**
   * The archive of closed items, newest first.
   *
   * @returns The closed items (without their descriptions).
   */
  async closedItems(): Promise<ClosedItem[]> {
    const root = this.ctx.repo.root;
    // One record per removing commit: header line, then the removed paths.
    const out = await git(root, [
      "log",
      "main",
      "--diff-filter=D",
      "--name-only",
      "--format=%x1e%H%x00%aI%x00%s",
      "--",
      "backlog/items/*/desc.md",
    ]);
    const removals: { slug: string; hash: string; date: string; subject: string }[] = [];
    for (const record of out.split("\x1e")) {
      const [head = "", ...paths] = record.split("\n").filter((line) => line.length > 0);
      const [hash = "", date = "", subject = ""] = head.split("\0");
      for (const path of paths) {
        const match = /^backlog\/items\/([^/]+)\/desc\.md$/.exec(path);
        if (match && hash) removals.push({ slug: match[1]!, hash, date, subject });
      }
    }
    // Reuse cached entries; read the missing descriptions in one batch.
    const cached = new Map(
      this.ctx.state
        .readJson(CACHE, CachedSchema, [])
        .map((entry) => [`${entry.closedIn.hash}:${entry.slug}`, entry]),
    );
    const missing = removals.filter((r) => !cached.has(`${r.hash}:${r.slug}`));
    const texts = await catFileBatch(
      root,
      missing.map((r) => `${r.hash}^:backlog/items/${r.slug}/desc.md`),
    );
    missing.forEach((removal, index) => {
      const fields = headerFields(texts[index] ?? "");
      const feature = /^\[(\d{3})\]/.exec(removal.subject)?.[1] ?? null;
      cached.set(`${removal.hash}:${removal.slug}`, {
        slug: removal.slug,
        title: fields["title"] ?? removal.slug,
        type: fields["type"] ?? "?",
        area: fields["area"] ?? "?",
        severity:
          fields["severity"] !== undefined && /^\d+$/.test(fields["severity"])
            ? Number(fields["severity"])
            : null,
        closedIn: { hash: removal.hash, date: removal.date, subject: removal.subject },
        feature,
      });
    });
    const items = removals.map((r) => cached.get(`${r.hash}:${r.slug}`)!).filter(Boolean);
    if (missing.length > 0) this.ctx.state.writeJson(CACHE, [...cached.values()]);
    return items;
  }

  /**
   * One closed item with its last description.
   *
   * @param slug - The item.
   * @returns The item, or null when it was never closed.
   */
  async closedItem(slug: string): Promise<ClosedItem | null> {
    const item = (await this.closedItems()).find((i) => i.slug === slug);
    if (!item) return null;
    const lastDescription =
      (await showFile(this.ctx.repo.root, `${item.closedIn.hash}^`, `backlog/items/${slug}/desc.md`)) ?? "";
    return { ...item, lastDescription };
  }
}
