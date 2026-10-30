// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the triage suggestion: the admission rules of the sections and the position by
 * severity.
 */

import { describe, expect, it } from "vitest";
import { admittingSection, suggestPlacement } from "../src/query/triage.ts";

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
