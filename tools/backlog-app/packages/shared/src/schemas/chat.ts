// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Schemas of the conversation with Claude about one item (feature 371, data-model
 * *Conversation*; `specs/371-backlog-app-live-editing/contracts/chat.md`).
 *
 * A conversation is kept per item on the server (`chats/<slug>.json` in the app's state
 * folder); its turns stream to the page while they are produced. Claude only reads the
 * repository; nothing a conversation does changes the backlog.
 */

import { z } from "zod";
import { ItemSchema } from "./backlog.ts";
import { RunSchema } from "./runs.ts";

/** States of one turn. */
export const TURN_STATES = ["running", "done", "failed", "stopped"] as const;

/** One progress line of a turn (a tool use, a note). */
export const ChatProgressSchema = z.object({
  /** When it arrived (ISO). */
  at: z.string(),
  /** The line. */
  text: z.string(),
});

/** One exchange: the maintainer's message and Claude's reply. */
export const TurnSchema = z.object({
  /** 1-based number within the conversation. */
  id: z.number().int().positive(),
  /** When the message was sent (ISO). */
  at: z.string(),
  /** The maintainer's message. */
  user: z.string(),
  /** The reply text so far. */
  assistant: z.string(),
  /** Tool uses and notes, oldest first (at most 200). */
  progress: z.array(ChatProgressSchema),
  /** The state. */
  state: z.enum(TURN_STATES),
  /** Why it failed, when it did. */
  error: z.string().nullable(),
  /** The turn's cost in US dollars, when claude reported it. */
  costUsd: z.number().nullable(),
  /** When the reply ended (ISO), null while running. */
  endedAt: z.string().nullable(),
});

/** One turn. */
export type Turn = z.infer<typeof TurnSchema>;

/** The conversation of one item. */
export const ConversationSchema = z.object({
  /** The item. */
  slug: z.string(),
  /** Claude's session id (chosen by the app at the first message). */
  sessionId: z.string(),
  /** When it was started (ISO). */
  createdAt: z.string(),
  /** When it last changed (ISO). */
  updatedAt: z.string(),
  /** The sum of the turns' costs. */
  costUsd: z.number(),
  /** The turns, oldest first (at most 200 kept). */
  turns: z.array(TurnSchema),
  /** The model the conversation runs with, or null for claude's default. */
  model: z.string().nullable().default(null),
});

/** A conversation. */
export type Conversation = z.infer<typeof ConversationSchema>;

/** The item's essentials shown at the top of the conversation page. */
export const ChatContextSchema = z.object({
  /** The item as the detail view has it. */
  item: ItemSchema,
  /** The item's runs, newest first. */
  runs: z.array(RunSchema),
  /** The journal rows of the item (`RUNS.md`), as cells. */
  journal: z.array(z.array(z.string())),
  /** The feature folder of the item's run, when one exists (`specs/NNN-slug`). */
  featureFolder: z.string().nullable(),
  /** The branch the working tree is on (what Claude reads). */
  branch: z.string(),
  /** Whether a run works on the item now. */
  running: z.boolean(),
});

/** The context of a conversation. */
export type ChatContext = z.infer<typeof ChatContextSchema>;

/** A message to send. */
export const ChatMessageRequestSchema = z.object({
  /** The maintainer's text. */
  text: z.string().min(1).max(20_000),
});

/** A message request. */
export type ChatMessageRequest = z.infer<typeof ChatMessageRequestSchema>;

/** Data of the app-stream event `chat.changed`. */
export const ChatChangedSchema = z.object({
  /** The item. */
  slug: z.string(),
  /** The turn. */
  turn: z.number().int(),
  /** Its state. */
  state: z.enum(TURN_STATES),
});

/** Names of the events of a conversation stream `GET /api/items/{slug}/chat/stream`. */
export const CHAT_STREAM_EVENTS = ["delta", "progress", "done", "failed", "ping"] as const;
