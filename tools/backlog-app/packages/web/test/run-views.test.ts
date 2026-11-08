// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Unit test of the views of the run dashboard (feature 419): the views a run has, the view
 * the address asks for, the conversation's signature and the mark on the Chat tab.
 */

import { describe, expect, it } from "vitest";
import {
  availableViews,
  chatMark,
  chatSignature,
  DEFAULT_VIEW,
  RUN_VIEWS,
  viewFromAddress,
} from "@/features/live/run-views.ts";

/**
 * A turn as the signature reads it.
 *
 * @param state - Its state.
 * @param assistant - The answer so far.
 * @returns The turn.
 */
const turn = (state: "running" | "done" | "failed" | "stopped", assistant = "") => ({ state, assistant });

describe("availableViews", () => {
  it("offers the chat only while an item's run is live", () => {
    expect(availableViews(true, true)).toEqual([...RUN_VIEWS]);
    expect(availableViews(false, true)).not.toContain("chat");
    expect(availableViews(true, false)).not.toContain("chat");
    expect(availableViews(false, false)).toHaveLength(RUN_VIEWS.length - 1);
  });

  it("starts with the overview and keeps the order of the tab row", () => {
    expect(availableViews(true, true)[0]).toBe("overview");
    expect(availableViews(true, true).at(-1)).toBe("chat");
    expect(availableViews(false, true).at(-1)).toBe("trace");
  });
});

describe("viewFromAddress", () => {
  const all = availableViews(true, true);
  const ended = availableViews(false, true);

  it("opens the view the address names", () => {
    for (const view of all) expect(viewFromAddress(view, all)).toBe(view);
  });

  it("opens the overview for an empty, unknown or unavailable view", () => {
    expect(DEFAULT_VIEW).toBe("overview");
    expect(viewFromAddress(undefined, all)).toBe("overview");
    expect(viewFromAddress("", all)).toBe("overview");
    expect(viewFromAddress("nonsense", all)).toBe("overview");
    expect(viewFromAddress("Story", all)).toBe("overview");
    expect(viewFromAddress(3, all)).toBe("overview");
    expect(viewFromAddress(["story"], all)).toBe("overview");
    // The conversation belongs to a live run: an ended run's address with view=chat shows the overview.
    expect(viewFromAddress("chat", ended)).toBe("overview");
    expect(viewFromAddress("story", ended)).toBe("story");
  });
});

describe("chatSignature", () => {
  it("is empty for an empty conversation", () => {
    expect(chatSignature([])).toBe("");
  });

  it("changes on a new turn, on the first words of an answer and on a state change", () => {
    const sent = chatSignature([turn("running")]);
    const writing = chatSignature([turn("running", "It builds")]);
    const more = chatSignature([turn("running", "It builds the project now")]);
    const done = chatSignature([turn("done", "It builds the project now.")]);
    const next = chatSignature([turn("done", "x"), turn("running")]);
    expect(new Set([sent, writing, done, next]).size).toBe(4);
    // More words of the same answer are not new: the tab is marked once per answer and state.
    expect(more).toBe(writing);
  });
});

describe("chatMark", () => {
  it("marks a change the reader has not seen while another view is shown", () => {
    expect(chatMark("1:running:0", "1:running:1", false)).toBe(true);
    expect(chatMark("1:running:1", "1:done:1", false)).toBe(true);
  });

  it("never marks while the chat is shown, before the first report, or without a change", () => {
    expect(chatMark("1:running:0", "1:done:1", true)).toBe(false);
    expect(chatMark(null, "1:done:1", false)).toBe(false);
    expect(chatMark("1:done:1", "1:done:1", false)).toBe(false);
    expect(chatMark("1:done:1", "", false)).toBe(false);
  });
});
