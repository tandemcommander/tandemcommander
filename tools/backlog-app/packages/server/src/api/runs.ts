// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Routes of runs, run statistics, notifications and the trace stream
 * (contracts/http-api.md, *Runs and features*, *Streams*).
 *
 * The trace stream `GET /api/runs/{id}/stream` sends the run's events from a byte offset: first
 * what is already in the file (in pages), then - for the live run - every new event as the run
 * writes it. The event id is the byte offset after the line, so a reconnect with `Last-Event-ID`
 * continues exactly where it stopped (research R5).
 */

import { Hono } from "hono";
import { streamSSE } from "hono/streaming";
import { ApiError, type TraceEvent } from "@backlog-app/shared";
import type { Services } from "../services.ts";
import { RUN_ID_PATTERN } from "../runs/service.ts";
import { param } from "./common.ts";

/** Form of a run id in a path: a trace folder or a journal row. */
const RUN_PARAM = /^(\d{8}-\d{6}-claude-[a-z0-9-]+|runs-md-\d+)$/;

/**
 * Creates the routes.
 *
 * @param services - The server's services.
 * @returns The routes, mounted under `/api`.
 */
export function runRoutes(services: Services): Hono {
  const app = new Hono();

  app.get("/runs", async (c) =>
    c.json({
      runs: await services.runs.list({
        ...(c.req.query("outcome") ? { outcome: c.req.query("outcome")! } : {}),
        ...(c.req.query("slug") ? { slug: c.req.query("slug")! } : {}),
        ...(c.req.query("kind") ? { kind: c.req.query("kind")! } : {}),
      }),
    }),
  );

  app.get("/runs/live", (c) => c.json({ run: services.runs.liveRun() }));

  app.get("/runs/:id", async (c) =>
    c.json(await services.runs.detail(param(c.req.param("id"), RUN_PARAM, "run"))),
  );

  app.get("/runs/:id/events", (c) => {
    const id = param(c.req.param("id"), RUN_ID_PATTERN, "run");
    const from = Number(c.req.query("from") ?? "0");
    if (!Number.isInteger(from) || from < 0) throw new ApiError("invalid-request", "from is a byte offset");
    return c.json(services.runs.events(id, from));
  });

  // Feature 415 (contracts/http-api.md): documents, decisions, gallery and estimate of a run.
  app.get("/runs/:id/insight", async (c) =>
    c.json(await services.insight.insight(param(c.req.param("id"), RUN_ID_PATTERN, "run"))),
  );

  app.get("/runs/:id/documents/:name", async (c) =>
    c.json(
      await services.insight.document(
        param(c.req.param("id"), RUN_ID_PATTERN, "run"),
        param(c.req.param("name"), /^[a-z][a-z-]{1,30}$/, "document"),
      ),
    ),
  );

  app.get("/runs/:id/images/:key", async (c) => {
    const id = param(c.req.param("id"), RUN_ID_PATTERN, "run");
    const key = param(c.req.param("key"), /^[0-9a-f]{16}$/, "image");
    const image = await services.insight.image(id, key);
    return c.body(new Uint8Array(image.bytes), 200, { "Content-Type": image.type });
  });

  app.get("/runs/:id/stream", (c) => {
    const id = param(c.req.param("id"), RUN_ID_PATTERN, "run");
    const resume = Number(c.req.header("last-event-id") ?? c.req.query("from") ?? "0");
    // The end of the last line whose events were all sent (feature 426: kept apart from the
    // catch-up's read position - sharing one variable ended the catch-up after its first page).
    let sent = Number.isInteger(resume) && resume >= 0 ? resume : 0;
    return streamSSE(c, async (stream) => {
      let closed = false;
      stream.onAbort(() => {
        closed = true;
      });
      /**
       * Sends events. All events of one line share the line's end offset; they are all sent
       * (feature 426: the second and later ones were skipped), and only the last of them carries
       * that offset as its id, so a resume after a lost connection never skips the rest of a line.
       *
       * @param events - The events, in order.
       */
      const send = async (events: TraceEvent[]): Promise<void> => {
        const floor = sent;
        for (let i = 0; i < events.length; i++) {
          const event = events[i]!;
          if (event.end <= floor) continue;
          const lastOfLine = events[i + 1]?.end !== event.end;
          await stream.writeSSE({
            event: event.kind === "attempt" ? "attempt" : "trace",
            ...(lastOfLine ? { id: String(event.end) } : {}),
            data: JSON.stringify(event),
          });
          if (lastOfLine) sent = Math.max(sent, event.end);
        }
      };
      // Live events that arrive during the catch-up wait in a queue.
      const queued: TraceEvent[] = [];
      const unsubscribe = services.runs.subscribe((runId, events) => {
        if (runId === id) queued.push(...events);
      });
      try {
        // Catch up from the file, a page at a time, until a page makes no progress (a page
        // without events - lines that give none - is not the end).
        let readAt = sent;
        for (;;) {
          if (closed) return;
          const page = services.runs.events(id, readAt);
          await send(page.events);
          if (page.next <= readAt) break;
          readAt = page.next;
        }
        sent = Math.max(sent, readAt);
        if (services.runs.liveId() !== id) {
          await stream.writeSSE({ event: "ended", data: JSON.stringify({ offset: sent }) });
          return;
        }
        // Follow the live run.
        let lastPhase = "";
        while (!closed) {
          const events = queued.splice(0);
          await send(events);
          const live = services.runs.liveRun();
          if (!live || live.id !== id) {
            await stream.writeSSE({ event: "ended", data: JSON.stringify({ offset: sent }) });
            return;
          }
          if (live.phase !== lastPhase) {
            lastPhase = live.phase;
            await stream.writeSSE({ event: "phase", data: JSON.stringify({ phase: live.phase }) });
          }
          await stream.sleep(500);
        }
      } finally {
        unsubscribe();
      }
    });
  });

  app.get("/stats", async (c) => c.json(await services.runs.stats(c.req.query("from") ?? null)));

  app.get("/events/log", (c) => {
    const since = Number(c.req.query("since") ?? "0");
    return c.json({ events: services.notifications.after(Number.isFinite(since) ? since : 0) });
  });

  app.post("/events/seen", async (c) => {
    const body = (await c.req.json<{ upTo?: unknown }>().catch(() => ({}))) as { upTo?: unknown };
    const upTo = typeof body.upTo === "number" ? body.upTo : 0;
    const settings = services.settings.settings();
    if (upTo > settings.lastSeenEventId) services.settings.updateSettings({ lastSeenEventId: upTo });
    return c.json({ ok: true });
  });

  return app;
}
