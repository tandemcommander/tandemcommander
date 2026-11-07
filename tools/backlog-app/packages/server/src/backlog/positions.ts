// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Positions the page counts versus positions the backlog tool counts (feature 414, review 2).
 *
 * While a run works on an item, the board the page shows lacks that item's row: it is overlaid into
 * *In progress* (feature 371, `overlayRunning`), but `BACKLOG.md` on `main` - where the tool writes -
 * still has it in its ordered section. A position typed or computed on the page counts the visible
 * rows; the tool's `--position` counts every item row. Below the hidden row the two differ by one,
 * so the page's position is shifted before it reaches the tool - the same correction the section
 * order endpoint makes by putting the hidden row back where the files have it.
 *
 * The hidden row is the one the board overlays: `services.running()` (the run lock's item), not
 * the gate's frozen slug, which also names the item of an interrupted run whose row the board still
 * shows (review 3). The tool's `place_row` takes the moved item's own row out before it counts, so
 * the moved item is left out of the count here too (review 3).
 */

import type { ItemRow, SectionName } from "@backlog-app/shared";
import type { Services } from "../services.ts";

/**
 * The tool's position for a position counted on the page.
 *
 * @param fileSlugs - The item slugs of the target section as the files have them (with the hidden
 * row).
 * @param hidden - The slug the page does not show (the running item), or null.
 * @param position - The 1-based position the page counted, or undefined (the end).
 * @returns The position to pass to the tool (undefined stays undefined: the tool appends).
 */
export function filePosition(
  fileSlugs: readonly string[],
  hidden: string | null,
  position: number | undefined,
): number | undefined {
  if (position === undefined || hidden === null) return position;
  const at = fileSlugs.indexOf(hidden);
  // Visible row i (0-based) is file row i above the hidden row and file row i + 1 from it on. A place
  // directly before the visible row that follows the hidden one may stay before the hidden row:
  // once the run ends and the row leaves the section, both give the same place.
  return at >= 0 && position - 1 > at ? position + 1 : position;
}

/**
 * The tool's position for a position the page (or an AI that read the run's tree) counted in a
 * section.
 *
 * @param services - The server's services (the running item, the raw board of `main`).
 * @param section - The target section.
 * @param position - The page's 1-based position, or undefined (the end).
 * @param moved - The item being placed (left out of the count, as the tool does), if any.
 * @returns The position for `--position`.
 */
export async function toolPosition(
  services: Pick<Services, "running" | "read">,
  section: SectionName,
  position: number | undefined,
  moved?: string,
): Promise<number | undefined> {
  const hidden = services.running()?.slug ?? null;
  if (position === undefined || hidden === null || hidden === moved) return position;
  const rows = (await services.read.snapshot()).rawBoard.sections.find((s) => s.name === section)?.rows ?? [];
  const slugs = rows.filter((r): r is ItemRow => r.kind === "item" && r.slug !== moved).map((r) => r.slug);
  return filePosition(slugs, hidden, position);
}
