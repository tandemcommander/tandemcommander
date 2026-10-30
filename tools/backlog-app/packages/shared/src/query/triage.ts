// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The deterministic placement suggestion for an Inbox item (FR-027; analysis A4 §3.6).
 *
 * It follows the backlog's admission rules (analysis A1 §2.3): a decision goes to *Decisions for
 * the maintainer*, a person step or an item only a person can do to *Person steps*, everything else
 * to *Next*. The position follows the priority the maintainer gave the section: the new item goes
 * directly below the last item of at least its severity, so it never jumps ahead of something
 * judged more severe. It is advice: the maintainer accepts, adjusts or skips it.
 */

import type { ItemRow, SectionName } from "../schemas/backlog.ts";

/** A suggested place. */
export interface Placement {
  /** The section. */
  section: SectionName;
  /** 1-based position in it. */
  position: number;
  /** Why, in one sentence. */
  why: string;
}

/**
 * The section an item belongs to by its type and who.
 *
 * @param item - The item's type and who.
 * @returns The section.
 */
export function admittingSection(item: Pick<ItemRow, "type" | "who">): SectionName {
  if (item.type === "decision") return "Decisions for the maintainer";
  if (item.type === "person-step" || item.who === "person") return "Person steps";
  return "Next";
}

/**
 * Suggests where an Inbox item goes.
 *
 * @param item - The item (its type, who and severity).
 * @param sectionRows - The item rows of the target section in their order.
 * @returns The suggested place.
 */
export function suggestPlacement(
  item: Pick<ItemRow, "type" | "who" | "severity">,
  sectionRows: Pick<ItemRow, "severity">[],
): Placement {
  const section = admittingSection(item);
  // Below the last row of at least the same severity; at the top when every row is less severe.
  let position = 1;
  sectionRows.forEach((row, index) => {
    if (row.severity >= item.severity) position = index + 2;
  });
  const why =
    position === 1
      ? `severity ${item.severity} is higher than every item in ${section}`
      : `below the last item of severity ${item.severity} or more in ${section}`;
  return { section, position, why };
}
