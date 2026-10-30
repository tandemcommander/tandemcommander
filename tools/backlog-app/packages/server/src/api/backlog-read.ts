// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Read routes of the backlog (contracts/http-api.md, *Backlog (read)*; user story 1).
 *
 * Every route reads through the read model or the tool, from the source research R10 chooses.
 * Path parameters are validated against their form before anything is read (contracts/security.md,
 * rule 7); files of an item are served only by names the tool listed for that item.
 */

import { readFileSync } from "node:fs";
import { join } from "node:path";
import { Hono } from "hono";
import {
  ApiError,
  evaluateFilter,
  foldText,
  highlightTexts,
  parseFilter,
  type BoardView,
  type FilterRow,
  type ItemRow,
  type ItemRowView,
  type SectionView,
} from "@backlog-app/shared";
import type { Services } from "../services.ts";
import { showFile } from "../repo/git.ts";
import { param, SLUG_PATTERN } from "./common.ts";

/** Characters of context on each side of a search hit. */
const SNIPPET_CONTEXT = 70;

/**
 * An excerpt of the item text around the first hit of a free word.
 *
 * @param row - The item row with its body.
 * @param texts - The positive free words and phrases.
 * @returns The excerpt, or null when the hit is only in the title.
 */
export function snippetOf(row: ItemRow, texts: string[]): string | null {
  if (texts.length === 0) return null;
  const source = `${row.body ?? ""}\n${row.issue ?? ""}`.replace(/\s+/g, " ");
  const folded = foldText(source);
  for (const text of texts) {
    // Folding keeps the length of most texts (accents are separate code points after NFD and
    // removed), so the position in the folded text is close to the original's; good enough for
    // an excerpt.
    const at = folded.indexOf(foldText(text));
    if (at >= 0) {
      const start = Math.max(0, at - SNIPPET_CONTEXT);
      const end = Math.min(source.length, at + text.length + SNIPPET_CONTEXT);
      return `${start > 0 ? "…" : ""}${source.slice(start, end).trim()}${end < source.length ? "…" : ""}`;
    }
  }
  return null;
}

/**
 * Creates the read routes.
 *
 * @param services - The server's services.
 * @returns The routes, to be mounted under `/api`.
 */
export function backlogReadRoutes(services: Services): Hono {
  const app = new Hono();

  app.get("/legend", async (c) => c.json((await services.read.snapshot()).legend));

  app.get("/board", async (c) => {
    const snapshot = await services.read.snapshot();
    const query = c.req.query("q") ?? "";
    const parsed = parseFilter(query, snapshot.legend);
    const texts = highlightTexts(parsed.terms);
    const filtering = parsed.terms.length > 0;
    const snippets: Record<string, string> = {};
    let matches = 0;
    const sections: SectionView[] = snapshot.board.sections.map((section) => {
      const items = section.rows.filter((r): r is ItemRow => r.kind === "item");
      const rows: SectionView["rows"] = [];
      for (const row of section.rows) {
        if (row.kind === "note") {
          if (!filtering) rows.push(row);
          continue;
        }
        const filterRow: FilterRow = { ...row, section: section.name };
        if (!evaluateFilter(parsed.terms, filterRow)) continue;
        matches++;
        const snippet = snippetOf(row, texts);
        if (snippet) snippets[row.slug] = snippet;
        // Bodies stay on the server: they are only needed for searching.
        const { body: _body, issue: _issue, ...visible } = row;
        const view: ItemRowView = { ...visible, section: section.name };
        rows.push(view);
      }
      return { name: section.name, ordered: section.ordered, rows, total: items.length };
    });
    const answer: BoardView = {
      revision: snapshot.board.revision,
      ref: snapshot.source,
      lastTriaged: snapshot.board.lastTriaged,
      sections,
      unreadable: snapshot.board.unreadable,
      errors: parsed.errors,
      snippets,
      matches,
      next: snapshot.next,
    };
    return c.json(answer);
  });

  app.post("/query/parse", async (c) => {
    const body = (await c.req.json<{ q?: unknown }>().catch(() => ({}))) as { q?: unknown };
    const legend = (await services.read.snapshot()).legend;
    return c.json(parseFilter(typeof body.q === "string" ? body.q : "", legend));
  });

  app.get("/next", async (c) => c.json((await services.read.snapshot()).next));

  app.get("/check", async (c) => c.json((await services.read.snapshot()).check));

  app.get("/items/:slug", async (c) => {
    const slug = param(c.req.param("slug"), SLUG_PATTERN, "item");
    return c.json(await services.tool.show(slug, services.source()));
  });

  app.get("/items/:slug/history", async (c) => {
    const slug = param(c.req.param("slug"), SLUG_PATTERN, "item");
    return c.json({ commits: await services.history.itemHistory(slug) });
  });

  app.get("/items/:slug/history/:hash", async (c) => {
    const slug = param(c.req.param("slug"), SLUG_PATTERN, "item");
    const hash = param(c.req.param("hash"), /^[0-9a-f]{7,40}$/, "commit");
    const markdown = await services.history.itemAt(slug, hash);
    if (markdown === null) throw new ApiError("not-found", "the item did not exist in that commit");
    return c.json({ markdown });
  });

  app.get("/items/:slug/files/:name", async (c) => {
    const slug = param(c.req.param("slug"), SLUG_PATTERN, "item");
    const name = c.req.param("name");
    const source = services.source();
    const item = await services.tool.show(slug, source);
    // Only names the tool listed for this item are served; the path is built here, never from
    // the request (contracts/security.md, rule 7).
    let relative: string | null = null;
    if (name === "issue.md" && item.files.issue) relative = "issue.md";
    else if (name === "reply.md" && item.files.reply) relative = "reply.md";
    else if (item.files.evidence.includes(name)) relative = `evidence/${name}`;
    if (!relative) throw new ApiError("not-found", "no such file of this item");
    const path = `backlog/items/${slug}/${relative}`;
    const text =
      source === "main"
        ? await showFile(services.ctx.repo.root, "main", path)
        : readFileSync(join(services.ctx.repo.root, ...path.split("/")), "utf8");
    if (text === null) throw new ApiError("not-found", "the file is not on main");
    return c.json({ name, text });
  });

  app.get("/closed", async (c) => {
    const query = foldText(c.req.query("q") ?? "");
    const items = await services.history.closedItems();
    return c.json({
      items: query ? items.filter((i) => foldText(`${i.title} ${i.slug} ${i.area}`).includes(query)) : items,
    });
  });

  app.get("/closed/:slug", async (c) => {
    const slug = param(c.req.param("slug"), SLUG_PATTERN, "item");
    const item = await services.history.closedItem(slug);
    if (!item) throw new ApiError("not-found", "no closed item with this slug");
    return c.json(item);
  });

  return app;
}
