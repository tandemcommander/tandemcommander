// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The hub of the per-tab event stream `GET /api/events` (contracts/http-api.md, *Streams*;
 * research R5).
 *
 * Server modules publish small "something changed" events (`board.changed`, `loop.changed`, ...);
 * the hub fans them out to every connected tab. Tabs re-fetch what they show, so an event carries
 * only identifiers and revisions, never whole documents. Each subscriber has its own write queue:
 * a slow tab never delays the others, and a tab whose queue grows beyond a bound is dropped (it
 * reconnects and starts again with `hello`).
 */

import type { AppEventName } from "@backlog-app/shared";

/** One message as written to a stream. */
export interface HubMessage {
  /** Event name. */
  event: AppEventName;
  /** JSON-serialisable data. */
  data: unknown;
  /** Event id (a per-process counter). */
  id: number;
}

/** Something that can write messages to one client (wraps an SSE stream). */
export interface HubSink {
  /**
   * Writes one message; resolves when it was handed to the connection.
   *
   * @param message - The message.
   */
  write(message: HubMessage): Promise<void>;
  /** Ends the connection (the client will reconnect). */
  close(): void;
}

/** Most messages a subscriber may have waiting before it is dropped. */
const MAX_QUEUE = 500;

/** One connected client and its pending messages. */
interface Subscriber {
  /** Where its messages go. */
  sink: HubSink;
  /** Messages not written yet. */
  queue: HubMessage[];
  /** True while a write is in flight. */
  writing: boolean;
}

/** Fan-out of application events to every connected tab. */
export class EventHub {
  /** The connected clients. */
  private readonly subscribers = new Set<Subscriber>();

  /** The id of the last published message. */
  private lastId = 0;

  /**
   * Publishes an event to every connected client.
   *
   * @param event - Event name.
   * @param data - Event data (small: identifiers, revisions, summaries).
   */
  publish(event: AppEventName, data: unknown): void {
    const message: HubMessage = { event, data, id: ++this.lastId };
    for (const subscriber of this.subscribers) this.enqueue(subscriber, message);
  }

  /**
   * Connects a client. The first message it gets is `hello` with the given state.
   *
   * @param sink - The client's stream.
   * @param hello - Data of the `hello` message (the full `/api/state`).
   * @returns A function that disconnects the client.
   */
  subscribe(sink: HubSink, hello: unknown): () => void {
    const subscriber: Subscriber = { sink, queue: [], writing: false };
    this.subscribers.add(subscriber);
    this.enqueue(subscriber, { event: "hello", data: hello, id: ++this.lastId });
    return () => {
      this.subscribers.delete(subscriber);
    };
  }

  /**
   * Number of connected clients (for diagnostics and tests).
   *
   * @returns The count.
   */
  get size(): number {
    return this.subscribers.size;
  }

  /**
   * Queues a message for one client and starts writing if idle.
   *
   * @param subscriber - The client.
   * @param message - The message.
   */
  private enqueue(subscriber: Subscriber, message: HubMessage): void {
    if (subscriber.queue.length >= MAX_QUEUE) {
      // The client cannot keep up (or its connection hangs): drop it; it reconnects with hello.
      this.subscribers.delete(subscriber);
      subscriber.sink.close();
      return;
    }
    subscriber.queue.push(message);
    if (!subscriber.writing) void this.drain(subscriber);
  }

  /**
   * Writes a client's queued messages one after another.
   *
   * @param subscriber - The client.
   */
  private async drain(subscriber: Subscriber): Promise<void> {
    subscriber.writing = true;
    try {
      let next = subscriber.queue.shift();
      while (next) {
        await subscriber.sink.write(next);
        next = subscriber.queue.shift();
      }
    } catch {
      // The connection is gone; forget the client.
      this.subscribers.delete(subscriber);
    } finally {
      subscriber.writing = false;
    }
  }
}
