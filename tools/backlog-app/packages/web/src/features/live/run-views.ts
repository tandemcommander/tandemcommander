// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The views of the run dashboard (feature 419): which views a run has, which one the page's
 * address asks for, and when the Chat tab shows that a new answer waits there. Pure rules, no React,
 * unit-tested in `packages/web/test/run-views.test.ts`.
 */

import type { Turn } from "@backlog-app/shared";

/** The views in the order of the tab row. */
export const RUN_VIEWS = [
  "overview",
  "story",
  "critical",
  "decisions",
  "gallery",
  "architecture",
  "files",
  "documents",
  "trace",
  "chat",
] as const;

/** One view. */
export type RunView = (typeof RUN_VIEWS)[number];

/** The view shown when the address names none (or one the run does not have). */
export const DEFAULT_VIEW: RunView = "overview";

/**
 * The views a run has: all of them, the chat only while an item's run is live (the conversation
 * belongs to the item being worked on).
 *
 * @param live - The run is in progress.
 * @param hasItem - The run works on an item (not an auto-triage).
 * @returns The views, in the order of the tab row.
 */
export function availableViews(live: boolean, hasItem: boolean): RunView[] {
  return RUN_VIEWS.filter((v) => v !== "chat" || (live && hasItem));
}

/**
 * The view the page shows for the value of its address's `view` parameter.
 *
 * @param value - The parameter's value (anything the address holds).
 * @param available - The views the run has.
 * @returns The view; the default for an empty, unknown or unavailable value.
 */
export function viewFromAddress(value: unknown, available: readonly RunView[]): RunView {
  return typeof value === "string" && (available as readonly string[]).includes(value)
    ? (value as RunView)
    : DEFAULT_VIEW;
}

/**
 * A short signature of a conversation that changes when something new appears in it: a new turn,
 * a turn's state, its first words of an answer.
 *
 * @param turns - The turns, oldest first.
 * @returns The signature; empty for an empty conversation.
 */
export function chatSignature(turns: readonly Pick<Turn, "state" | "assistant">[]): string {
  const last = turns.at(-1);
  if (!last) return "";
  return `${turns.length}:${last.state}:${last.assistant.length > 0 ? 1 : 0}`;
}

/**
 * Whether the Chat tab marks a new answer.
 *
 * @param seen - The signature last seen while the chat was shown (or first reported), null before any.
 * @param current - The signature now.
 * @param shown - The chat is the view shown now.
 * @returns True when something changed since the reader last saw the chat.
 */
export function chatMark(seen: string | null, current: string, shown: boolean): boolean {
  return !shown && seen !== null && current !== "" && current !== seen;
}
