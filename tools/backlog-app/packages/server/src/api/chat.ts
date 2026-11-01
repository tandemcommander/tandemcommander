// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Routes of the conversation about an item (feature 371,
 * `specs/371-backlog-app-live-editing/contracts/http-api-additions.md`): the transcript, the
 * item's context, a message, stop, reset, and the stream of the running reply. The slug is
 * validated by form; `send` checks the item against the board. The message text goes to claude
 * on stdin, never on a command line.
 */

import { Hono, type Context } from "hono";
import { streamSSE } from "hono/streaming";
import { ChatMessageRequestSchema, type Turn } from "@backlog-app/shared";
import type { Services } from "../services.ts";
import type { ChatEvent } from "../chat/service.ts";
import { param, readBody, SLUG_PATTERN } from "./common.ts";

/** Milliseconds between pings of an idle stream. */
const PING_MS = 15_000;

/**
 * Creates the routes.
 *
 * @param services - The server's services.
 * @returns The routes, mounted under `/api`.
 */
export function chatRoutes(services: Services): Hono {
  const app = new Hono();
  const chat = services.chat;

  /**
   * The slug of the route.
   *
   * @param c - The request context.
   * @returns The validated slug.
   */
  const slugOf = (c: Context): string => param(c.req.param("slug"), SLUG_PATTERN, "item");

  app.get("/items/:slug/chat", (c) => c.json(chat.get(slugOf(c))));

  app.get("/items/:slug/chat/context", async (c) => c.json(await chat.context(slugOf(c))));

  app.post("/items/:slug/chat/messages", async (c) => {
    const slug = slugOf(c);
    const body = await readBody(c, ChatMessageRequestSchema);
    return c.json(await chat.send(slug, body.text));
  });

  app.post("/items/:slug/chat/stop", async (c) => c.json(await chat.stop(slugOf(c))));

  app.post("/items/:slug/chat/reset", async (c) => c.json(await chat.reset(slugOf(c))));

  app.get("/items/:slug/chat/stream", (c) => {
    const slug = slugOf(c);
    return streamSSE(c, async (stream) => {
      let closed = false;
      stream.onAbort(() => {
        closed = true;
      });
      /**
       * Sends one event.
       *
       * @param event - The event name.
       * @param turn - The turn number (the id's first part).
       * @param data - The payload.
       */
      const send = async (event: string, turn: number, data: unknown): Promise<void> => {
        await stream
          .writeSSE({ event, id: `${turn}:${Date.now().toString(36)}`, data: JSON.stringify(data) })
          .catch(() => {
            closed = true;
          });
      };
      // The running turn so far (a reconnect, or a second window): its text and progress at once.
      const running: Turn | undefined = chat.get(slug).turns.find((t) => t.state === "running");
      if (running) {
        if (running.assistant)
          await send("delta", running.id, { turn: running.id, text: running.assistant, whole: true });
        for (const line of running.progress)
          await send("progress", running.id, { turn: running.id, ...line });
      }
      const queue: ChatEvent[] = [];
      let wake: (() => void) | null = null;
      const unsubscribe = chat.subscribe((event) => {
        if (event.slug !== slug) return;
        queue.push(event);
        wake?.();
      });
      try {
        while (!closed) {
          if (queue.length === 0) {
            await Promise.race([
              new Promise<void>((resolve) => {
                wake = resolve;
              }),
              stream.sleep(PING_MS),
            ]);
            wake = null;
            if (queue.length === 0 && !closed) await send("ping", 0, {});
            continue;
          }
          const event = queue.shift()!;
          switch (event.kind) {
            case "delta":
              await send("delta", event.turn, { turn: event.turn, text: event.text });
              break;
            case "progress":
              await send("progress", event.turn, { turn: event.turn, at: event.at, text: event.text });
              break;
            case "done":
              await send("done", event.turn, { turn: event.turn });
              break;
            case "failed":
              await send("failed", event.turn, { turn: event.turn, error: event.error });
              break;
            default:
              break;
          }
        }
      } finally {
        unsubscribe();
      }
    });
  });

  return app;
}
