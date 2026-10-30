// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Events of the per-tab stream `GET /api/events` (contracts/http-api.md, *Streams*).
 *
 * The stream tells every open tab what changed; tabs then re-fetch what they show (TanStack Query
 * invalidation) instead of the server pushing whole documents. Events are Server-Sent Events read
 * with `fetch` so that the token travels in the `Authorization` header (research R5).
 */

import { z } from "zod";

/** Names of the events of `GET /api/events`. */
export const APP_EVENT_NAMES = [
  "hello",
  "board.changed",
  "gate.changed",
  "loop.changed",
  "run.changed",
  "tray.changed",
  "check.changed",
  "job.changed",
  "notify",
  "ping",
] as const;

/** One event name. */
export type AppEventName = (typeof APP_EVENT_NAMES)[number];

/** Data of `board.changed`. */
export const BoardChangedSchema = z.object({
  /** The new board revision. */
  board: z.string(),
  /** Where the board is read from now. */
  ref: z.enum(["worktree", "main"]),
});

/** Data of `run.changed`: the summary every tab shows in its top bar. */
export const RunChangedSchema = z.object({
  /** The run id, or null when no run is active. */
  id: z.string().nullable(),
  /** The item. */
  slug: z.string().nullable(),
  /** Phase. */
  phase: z.string().nullable(),
  /** Task progress. */
  tasks: z.object({ done: z.number(), total: z.number() }).nullable(),
});

/** Names of the events of a trace stream `GET /api/runs/{id}/stream`. */
export const TRACE_STREAM_EVENTS = ["trace", "attempt", "phase", "ended", "ping"] as const;
