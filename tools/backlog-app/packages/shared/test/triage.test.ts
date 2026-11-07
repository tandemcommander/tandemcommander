// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the triage suggestion: the admission rules of the sections and the position by
 * severity.
 */

import { describe, expect, it } from "vitest";
import {
  admittingSection,
  positionBySeverity,
  readTriagePosition,
  suggestPlacement,
  TRIAGE_TARGETS,
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

describe("positionBySeverity (feature 414)", () => {
  it("places below the last row of at least the severity, the top when none is that severe", () => {
    expect(positionBySeverity(5, rows)).toBe(4);
    expect(positionBySeverity(6, rows)).toBe(2);
    expect(positionBySeverity(10, rows)).toBe(1);
    expect(positionBySeverity(0, rows)).toBe(5);
    expect(positionBySeverity(3, [])).toBe(1);
    // A less severe row above a more severe one: below the last row that is severe enough.
    expect(positionBySeverity(4, [{ severity: 2 }, { severity: 6 }, { severity: 1 }])).toBe(3);
  });

  it("gives the suggestion's position for every severity", () => {
    for (let severity = 0; severity <= 10; severity++) {
      expect(positionBySeverity(severity, rows)).toBe(
        suggestPlacement({ type: "bug", who: "agent", severity }, rows).position,
      );
    }
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
