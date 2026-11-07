// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the page-to-tool position rule (feature 414, review 2): a position counted on a
 * board without the running item's row, translated to the tool's count of every item row.
 */

import { describe, expect, it } from "vitest";
import { filePosition } from "../src/backlog/positions.ts";

/** A section as the files have it; `run` is the hidden running item. */
const FILE = ["a", "run", "b", "c"];

/**
 * Inserts a slug at a 1-based position (beyond the end = last), as the tool's `place_row` does.
 *
 * @param order - The section.
 * @param slug - The new row.
 * @param position - The position, or undefined for the end.
 * @returns The new order.
 */
function insert(order: readonly string[], slug: string, position: number | undefined): string[] {
  const at = position === undefined ? order.length : Math.min(order.length, position - 1);
  return [...order.slice(0, at), slug, ...order.slice(at)];
}

describe("filePosition", () => {
  it("keeps the position without a hidden row, or when the hidden row is not in the section", () => {
    expect(filePosition(FILE, null, 3)).toBe(3);
    expect(filePosition(["a", "b"], "run", 2)).toBe(2);
    expect(filePosition(FILE, "run", undefined)).toBeUndefined();
  });

  it("gives every visible place the same place among the visible rows", () => {
    const visible = FILE.filter((s) => s !== "run");
    for (let position = 1; position <= visible.length + 1; position++) {
      const placed = insert(FILE, "x", filePosition(FILE, "run", position)).filter((s) => s !== "run");
      expect(placed, `position ${position}`).toEqual(insert(visible, "x", position));
    }
  });

  it("shifts only below the hidden row", () => {
    expect(filePosition(FILE, "run", 1)).toBe(1);
    expect(filePosition(FILE, "run", 2)).toBe(2);
    expect(filePosition(FILE, "run", 3)).toBe(4);
    expect(filePosition(FILE, "run", 4)).toBe(5);
    expect(filePosition(["run", "a"], "run", 1)).toBe(1);
    expect(filePosition(["run", "a"], "run", 2)).toBe(3);
    expect(filePosition(["a", "run"], "run", 2)).toBe(2);
  });
});
