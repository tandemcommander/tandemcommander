// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Unit test of the error text the web shows (feature 426): the server's message and its
 * textual detail (git's reason for a refused side worktree), a long detail cut at a whole
 * character, structured details and other errors unchanged.
 */

import { describe, expect, it } from "vitest";
import { ApiFailure, errorText } from "@/lib/api.ts";

describe("errorText", () => {
  it("adds a textual detail to the message", () => {
    const failure = new ApiFailure(
      500,
      "tool-failed",
      "git checkout in the side worktree failed",
      "error: Your local changes to the following files would be overwritten by checkout:\n\tspecs/FEATURE-HISTORY.md\n",
    );
    expect(errorText(failure)).toBe(
      "git checkout in the side worktree failed: error: Your local changes to the following files would be overwritten by checkout:\n\tspecs/FEATURE-HISTORY.md",
    );
  });

  it("keeps the message alone without a textual detail, or when the detail repeats it", () => {
    expect(errorText(new ApiFailure(409, "refused", "refused: no such item"))).toBe("refused: no such item");
    expect(errorText(new ApiFailure(409, "refused", "refused", { written: false }))).toBe("refused");
    expect(errorText(new ApiFailure(500, "tool-failed", "x failed", "  "))).toBe("x failed");
    expect(errorText(new ApiFailure(500, "tool-failed", "same", "same\n"))).toBe("same");
  });

  it("cuts a long detail at a whole character", () => {
    const detail = "č".repeat(599) + "😀" + "tail";
    const text = errorText(new ApiFailure(500, "tool-failed", "m", detail));
    expect(text.startsWith("m: ")).toBe(true);
    expect(text.endsWith("😀…")).toBe(true);
    expect(Array.from(text.slice(3))).toHaveLength(601);
  });

  it("gives the text of other errors", () => {
    expect(errorText(new Error("network down"))).toBe("network down");
    expect(errorText("plain")).toBe("plain");
  });
});
