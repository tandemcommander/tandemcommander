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
 */

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
