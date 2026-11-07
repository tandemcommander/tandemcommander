// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the triage suggestion: the admission rules of the sections and the position by
 * severity.
 */

import { describe, expect, it } from "vitest";
import {
  admittingSection,
  readTriagePosition,
  suggestPlacement,
  TRIAGE_TARGETS,
  triagePosition,
} from "../src/query/triage.ts";

/** Severities of a section in its order. */
const rows = [{ severity: 7 }, { severity: 5 }, { severity: 5 }, { severity: 3 }];

describe("suggestPlacement", () => {
  it("sends decisions, person work and the rest to their sections", () => {
    expect(admittingSection({ type: "decision", who: "person" })).toBe("Decisions for the maintainer");
    expect(admittingSection({ type: "person-step", who: "person" })).toBe("Person steps");
    expect(admittingSection({ type: "bug", who: "person" })).toBe("Person steps");
    expect(admittingSection({ type: "bug", who: "both" })).toBe("Next");
  });

  it("places below the last item of at least the same severity", () => {
    expect(suggestPlacement({ type: "bug", who: "agent", severity: 5 }, rows).position).toBe(4);
    expect(suggestPlacement({ type: "bug", who: "agent", severity: 6 }, rows).position).toBe(2);
    expect(suggestPlacement({ type: "bug", who: "agent", severity: 9 }, rows).position).toBe(1);
    expect(suggestPlacement({ type: "bug", who: "agent", severity: 1 }, rows).position).toBe(5);
    expect(suggestPlacement({ type: "bug", who: "agent", severity: 4 }, []).position).toBe(1);
  });
});

describe("triagePosition (feature 414: the auto-triage rule)", () => {
  /** A section with severities 4, 4, 5, 4, 2 (not sorted, like the real Next). */
  const mixed = [
    { slug: "a", severity: 4 },
    { slug: "b", severity: 4 },
    { slug: "c", severity: 5 },
    { slug: "d", severity: 4 },
    { slug: "e", severity: 2 },
  ];

  it("takes the place of the first less severe row, the end when there is none", () => {
    expect(triagePosition({ severity: 5 }, rows)).toBe(4);
    expect(triagePosition({ severity: 6 }, rows)).toBe(2);
    expect(triagePosition({ severity: 10 }, rows)).toBe(1);
    expect(triagePosition({ severity: 0 }, rows)).toBe(5);
    expect(triagePosition({ severity: 3 }, [])).toBe(1);
    // Not sorted by severity: the first less severe row decides, not the last more severe one.
    expect(triagePosition({ severity: 5 }, mixed)).toBe(1);
    expect(triagePosition({ severity: 4 }, mixed)).toBe(5);
    expect(triagePosition({ severity: 4 }, [{ severity: 2 }, { severity: 6 }, { severity: 1 }])).toBe(1);
    // Equal severity goes after the existing rows of that severity.
    expect(triagePosition({ severity: 2 }, mixed)).toBe(6);
  });

  it("goes after a row of the section the item depends on", () => {
    expect(triagePosition({ severity: 5, dependsOn: ["d"] }, mixed)).toBe(5);
    expect(triagePosition({ severity: 5, dependsOn: ["b", "d"] }, mixed)).toBe(5);
    // A dependency above the place changes nothing; one not in the section neither.
    expect(triagePosition({ severity: 3, dependsOn: ["a"] }, mixed)).toBe(5);
    expect(triagePosition({ severity: 5, dependsOn: ["elsewhere"] }, mixed)).toBe(1);
    // A dependency at the place itself: directly after it.
    expect(triagePosition({ severity: 3, dependsOn: ["e"] }, mixed)).toBe(6);
  });

  it("gives the suggestion's position for every severity", () => {
    for (let severity = 0; severity <= 10; severity++) {
      for (const section of [rows, mixed]) {
        expect(triagePosition({ severity }, section)).toBe(
          suggestPlacement({ type: "bug", who: "agent", severity }, section).position,
        );
      }
    }
    expect(suggestPlacement({ type: "bug", who: "agent", severity: 5, dependsOn: ["d"] }, mixed)).toEqual({
      section: "Next",
      position: 5,
      why: "after the item of Next it depends on",
    });
  });

  it("offers the three ordered sections, Next first", () => {
    expect(TRIAGE_TARGETS).toEqual(["Next", "Decisions for the maintainer", "Person steps"]);
  });
});

describe("readTriagePosition (feature 414)", () => {
  it("refuses anything but a whole number of at least 1", () => {
    for (const text of ["", " ", "abc", "1.5", "-1", "+2", "2x", "1e2"]) {
      expect(readTriagePosition(text, 3)).toEqual({ hint: "type a whole number: 1 is the top" });
    }
    expect(readTriagePosition("0", 3)).toEqual({ hint: "positions count from 1 (the top)" });
    expect(readTriagePosition("000", 3)).toEqual({ hint: "positions count from 1 (the top)" });
  });

  it("accepts a position, trimmed, and says when it is past the end", () => {
    expect(readTriagePosition(" 2 ", 3)).toEqual({ position: 2, last: false });
    expect(readTriagePosition("1", 0)).toEqual({ position: 1, last: false });
    // count + 1 is the last place itself, not past it.
    expect(readTriagePosition("4", 3)).toEqual({ position: 4, last: false });
    expect(readTriagePosition("5", 3)).toEqual({ position: 5, last: true });
    expect(readTriagePosition("99", 0)).toEqual({ position: 99, last: true });
  });
});
