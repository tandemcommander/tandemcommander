// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Release readiness from local data only (research R25; user story 6, FR-046).
 *
 * The page shows what a release would carry and what stands in its way: the unreleased section of
 * `CHANGELOG.md`, the person steps and decisions that mention a release, `main` against its
 * remote-tracking branch as last fetched, the local `v*` tags, and the *Release records* list of
 * `backlog/RELEASE.md`. Nothing here fetches, tags, builds or publishes; `tools/release/release.py`
 * is not called because its status reads the remote's tags over the network.
 */

import { readFileSync } from "node:fs";
import { join } from "node:path";
import type { ItemRow, ReadRef, SectionName } from "@backlog-app/shared";
import type { Services } from "../services.ts";
import { aheadBehind, git, showFile } from "../repo/git.ts";
import { stripBom } from "./records.ts";

/** The sections whose items can hold a release back. */
const BLOCKING_SECTIONS: readonly SectionName[] = ["Person steps", "Decisions for the maintainer"];

/** An item that holds a release back. */
export interface ReleaseBlocker {
  /** The item. */
  slug: string;
  /** Its title. */
  title: string;
  /** Its section (Person steps or Decisions for the maintainer). */
  section: SectionName;
  /** Its type. */
  type: string;
  /** Its status. */
  status: string;
  /** Its severity. */
  severity: number;
  /** Its area. */
  area: string;
  /** Its position in the section. */
  position: number | null;
}

/** The release page. */
export interface ReleaseView {
  /** Where the files were read from. */
  ref: ReadRef;
  /** The heading of the unreleased section of `CHANGELOG.md`, or null when there is none. */
  unreleasedHeading: string | null;
  /** The body of that section (Markdown; empty when there is none). */
  unreleased: string;
  /** Person steps and decisions that mention a release. */
  blockers: ReleaseBlocker[];
  /** Commits of `main` not on `origin/main` as last fetched, or null without a remote branch. */
  ahead: number | null;
  /** Commits of `origin/main` not on `main`, or null without a remote branch. */
  behind: number | null;
  /** Local tags `v*`, highest version first. */
  tags: string[];
  /** The *Release records* section of `backlog/RELEASE.md` (Markdown, with its heading). */
  records: string;
}

/** A section of a Markdown document. */
export interface MarkdownSection {
  /** The heading text (without the `#` marks). */
  heading: string;
  /** The heading line itself. */
  headingLine: string;
  /** The lines up to the next heading of the same or a higher level (trimmed). */
  body: string;
}

/**
 * Finds the first section whose heading satisfies a test; headings inside fenced code blocks are
 * not headings.
 *
 * @param text - The Markdown document.
 * @param test - Decides on a heading's text.
 * @returns The section, or null.
 */
export function markdownSection(text: string, test: (heading: string) => boolean): MarkdownSection | null {
  const lines = stripBom(text).replace(/\r\n/g, "\n").split("\n");
  let fenced = false;
  let found: { level: number; heading: string; headingLine: string } | null = null;
  const body: string[] = [];
  for (const line of lines) {
    if (/^\s*(```|~~~)/.test(line)) fenced = !fenced;
    const heading = fenced ? null : /^(#{1,6})\s+(.*?)\s*#*\s*$/.exec(line);
    if (found) {
      if (heading && heading[1]!.length <= found.level) break;
      body.push(line);
    } else if (heading && test(heading[2]!)) {
      found = { level: heading[1]!.length, heading: heading[2]!, headingLine: line };
    }
  }
  if (!found) return null;
  return { heading: found.heading, headingLine: found.headingLine, body: body.join("\n").trim() };
}

/** The release readiness service. */
export class ReleaseService {
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
   * Reads a text file of the repository from the source (open-read-close or `main`'s objects).
   *
   * @param ref - The source.
   * @param path - Path relative to the root, `/`-separated.
   * @returns The text, or an empty text when the file does not exist.
   */
  private async readText(ref: ReadRef, path: string): Promise<string> {
    const root = this.services.ctx.repo.root;
    if (ref === "main") return (await showFile(root, "main", path)) ?? "";
    try {
      return readFileSync(join(root, ...path.split("/")), "utf8");
    } catch {
      return "";
    }
  }

  /**
   * The person steps and decisions whose title or text mentions a release.
   *
   * @returns The blockers in board order.
   */
  private async blockers(): Promise<ReleaseBlocker[]> {
    const snapshot = await this.services.read.snapshot().catch(() => this.services.read.peek());
    if (!snapshot) return [];
    const blockers: ReleaseBlocker[] = [];
    for (const section of snapshot.board.sections) {
      if (!BLOCKING_SECTIONS.includes(section.name)) continue;
      for (const row of section.rows) {
        if (row.kind !== "item") continue;
        const item: ItemRow = row;
        if (!/\breleas/i.test(`${item.title}\n${item.body ?? ""}`)) continue;
        blockers.push({
          slug: item.slug,
          title: item.title,
          section: section.name,
          type: item.type,
          status: item.status,
          severity: item.severity,
          area: item.area,
          position: item.position,
        });
      }
    }
    return blockers;
  }

  /**
   * The local release tags, highest version first.
   *
   * @returns The tag names.
   */
  private async tags(): Promise<string[]> {
    const out = await git(this.services.ctx.repo.root, [
      "tag",
      "--list",
      "--sort=-version:refname",
      "v*",
    ]).catch(() => "");
    return out
      .split("\n")
      .map((t) => t.trim())
      .filter(Boolean);
  }

  /**
   * Everything the release page shows.
   *
   * @returns The view.
   */
  async view(): Promise<ReleaseView> {
    const ref = this.services.source();
    const [changelog, releaseDoc, blockers, counts, tags] = await Promise.all([
      this.readText(ref, "CHANGELOG.md"),
      this.readText(ref, "backlog/RELEASE.md"),
      this.blockers(),
      aheadBehind(this.services.ctx.repo.root).catch(() => null),
      this.tags(),
    ]);
    const unreleased = markdownSection(changelog, (h) => /unreleased/i.test(h));
    const records = markdownSection(releaseDoc, (h) => /^release records$/i.test(h.trim()));
    return {
      ref,
      unreleasedHeading: unreleased?.heading ?? null,
      unreleased: unreleased?.body ?? "",
      blockers,
      ahead: counts?.ahead ?? null,
      behind: counts?.behind ?? null,
      tags,
      records: records ? `${records.headingLine}\n\n${records.body}`.trim() : "",
    };
  }
}
