// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Reader of the server's event streams (research R5).
 *
 * `EventSource` cannot send headers, so the streams are read with `fetch` and parsed with
 * `eventsource-parser`; the token goes in the `Authorization` header like on every other call and
 * never appears in a URL. The reader reconnects with growing pauses and sends `Last-Event-ID`, so
 * a trace stream resumes at the exact byte offset it had reached.
 */

import { createParser, type EventSourceMessage } from "eventsource-parser";
import { currentToken, reportSessionLost } from "./api.ts";

/** One received event. */
export interface StreamEvent {
  /** Event name. */
  event: string;
  /** Parsed JSON data. */
  data: unknown;
  /** Event id, if the server sent one. */
  id: string | null;
}

/** Options of {@link openStream}. */
export interface StreamOptions {
  /** Called for every event. */
  onEvent: (event: StreamEvent) => void;
  /** Called with `true` when connected and `false` when the connection is lost. */
  onConnection?: (connected: boolean) => void;
  /** Id to resume from on the first connection. */
  lastEventId?: string;
}

/**
 * Opens a stream and keeps it open until the returned function is called.
 *
 * @param path - Stream path under `/api`.
 * @param options - Callbacks and the resume id.
 * @returns A function that closes the stream for good.
 */
export function openStream(path: string, options: StreamOptions): () => void {
  let closed = false;
  let controller: AbortController | null = null;
  let lastId = options.lastEventId ?? null;
  let attempt = 0;

  /** Connects once and reads until the connection ends. */
  const connect = async (): Promise<void> => {
    controller = new AbortController();
    const headers: Record<string, string> = { Accept: "text/event-stream" };
    const token = currentToken();
    if (token) headers["Authorization"] = `Bearer ${token}`;
    if (lastId) headers["Last-Event-ID"] = lastId;
    const answer = await fetch(path, { headers, signal: controller.signal });
    // A refused token means the app was restarted: say so (the page shows how to get back in)
    // and stop - reconnecting with the same token can never succeed (review).
    if (answer.status === 401) {
      closed = true;
      reportSessionLost();
      return;
    }
    if (!answer.ok || !answer.body) throw new Error(`stream ${path}: ${answer.status}`);
    attempt = 0;
    options.onConnection?.(true);
    const parser = createParser({
      /**
       * Hands one parsed message to the caller.
       *
       * @param message - The message.
       */
      onEvent(message: EventSourceMessage) {
        if (message.id) lastId = message.id;
        let data: unknown = message.data;
        try {
          data = JSON.parse(message.data);
        } catch {
          // Non-JSON data is passed as text.
        }
        options.onEvent({ event: message.event ?? "message", data, id: message.id ?? null });
      },
    });
    const reader = answer.body.pipeThrough(new TextDecoderStream()).getReader();
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      parser.feed(value);
    }
  };

  /** Connects, and reconnects after a loss until closed. */
  const run = async (): Promise<void> => {
    while (!closed) {
      try {
        await connect();
      } catch {
        // Lost or refused; reconnect below.
      }
      if (closed) break;
      options.onConnection?.(false);
      attempt++;
      // 0.5 s, 1 s, 2 s, ... up to 10 s between attempts.
      const pause = Math.min(10_000, 500 * 2 ** Math.min(attempt - 1, 5));
      await new Promise((resolve) => setTimeout(resolve, pause));
    }
  };

  void run();
  return () => {
    closed = true;
    controller?.abort();
  };
}
