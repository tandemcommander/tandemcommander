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

/** The ordered sections an Inbox item can be placed into at a chosen position (feature 414). */
export const TRIAGE_TARGETS: readonly SectionName[] = [
  "Next",
  "Decisions for the maintainer",
  "Person steps",
];

/**
 * The position the severity rule gives in a section: directly below the last row of at least the
 * item's severity, so the item never jumps ahead of something judged more severe; 1 (the top) when
 * every row is less severe or the section is empty.
 *
 * @param severity - The item's severity.
 * @param sectionRows - The item rows of the section in their order (without the item itself).
 * @returns The 1-based position.
 */
export function positionBySeverity(severity: number, sectionRows: Pick<ItemRow, "severity">[]): number {
  let position = 1;
  sectionRows.forEach((row, index) => {
    if (row.severity >= severity) position = index + 2;
  });
  return position;
}

/**
 * Reads a position typed in the triage's chooser (feature 414): a whole number of at least 1. A
 * number past the end of the section is accepted - the backlog tool then appends the row - and
 * says so, so the maintainer knows before confirming.
 *
 * @param text - What was typed.
 * @param count - The number of item rows in the target section (the Inbox item is not among them).
 * @returns The position and whether it is past the end, or a hint why it is refused.
 */
export function readTriagePosition(
  text: string,
  count: number,
): { position: number; last: boolean } | { hint: string } {
  const trimmed = text.trim();
  if (!/^\d+$/.test(trimmed)) return { hint: "type a whole number: 1 is the top" };
  const position = Number(trimmed);
  if (position < 1) return { hint: "positions count from 1 (the top)" };
  return { position, last: position > count + 1 };
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
  const position = positionBySeverity(item.severity, sectionRows);
  const why =
    position === 1
      ? `severity ${item.severity} is higher than every item in ${section}`
      : `below the last item of severity ${item.severity} or more in ${section}`;
  return { section, position, why };
}
