// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The API application: every route under `/api` (contracts/http-api.md).
 *
 * Access rules run before this application, in the outer server (`server.ts`); routes here assume
 * an authenticated same-origin request. Errors of any route become the API's error answers.
 */

import { basename } from "node:path";
import { Hono } from "hono";
import { streamSSE } from "hono/streaming";
import { z } from "zod";
import {
  ApiError,
  LoopStartOptionsSchema,
  SavedViewSchema,
  SettingsSchema,
  ConfirmRequestSchema,
  type StateView,
} from "@backlog-app/shared";
import type { Services } from "../services.ts";
import { aheadBehind } from "../repo/git.ts";
import { backlogReadRoutes } from "./backlog-read.ts";
import { backlogWriteRoutes } from "./backlog-write.ts";
import { errorAnswer, readBody } from "./common.ts";

/** Milliseconds between keep-alive pings on an event stream. */
const PING_MS = 15_000;

/** Cached ahead/behind counts (git rev-list on every state request would be wasteful). */
let aheadCache: { at: number; value: { ahead: number; behind: number } | null } = { at: 0, value: null };

/**
 * The overview state every tab shows in its top bar (also the `hello` event).
 *
 * @param services - The server's services.
 * @returns The state.
 */
export async function stateView(services: Services): Promise<StateView> {
  if (Date.now() - aheadCache.at > 30_000) {
    aheadCache = { at: Date.now(), value: await aheadBehind(services.ctx.repo.root).catch(() => null) };
  }
  const settings = services.settings.settings();
  return {
    gate: services.gate(),
    loop: services.loop.view,
    run: null,
    tray: { pending: services.tray.pending().length, outside: 0 },
    repo: {
      root: services.ctx.repo.root,
      name: basename(services.ctx.repo.root),
      branch: services.repo.state?.branch ?? "?",
      ahead: aheadCache.value?.ahead ?? null,
      behind: aheadCache.value?.behind ?? null,
    },
    source: services.source(),
    check: { total: services.read.peek()?.check.total ?? 0 },
    unseenEvents: settings.lastSeenEventId >= 0 ? 0 : 0,
    dev: services.ctx.dev,
  };
}

/**
 * Creates the API application.
 *
 * @param services - The server's services.
 * @returns The Hono application.
 */
export function createApi(services: Services): Hono {
  const app = new Hono().basePath("/api");

  app.onError((error, c) => errorAnswer(error, c));
  app.notFound((c) => c.json({ error: { code: "not-found", message: "no such route" } }, 404));

  // --- session (contracts/security.md, *Token and bootstrap*) ---
  app.post("/session/claim", async (c) => {
    const { boot } = await readBody(c, z.object({ boot: z.string().min(1).max(100) }));
    const token = services.auth.claim(boot);
    if (!token)
      throw new ApiError(
        "unauthorized",
        "the start code is unknown, used or expired - open the address the app printed",
      );
    return c.json({ token, repo: { root: services.ctx.repo.root, name: basename(services.ctx.repo.root) } });
  });

  app.post("/session/link", (c) => {
    const url = new URL(c.req.url);
    return c.json({ url: `${url.origin}/?boot=${services.auth.mintBootCode()}` });
  });

  // A second launch asks this instance for a new start address (launcher secret checked by the gate).
  app.post("/instance/boot", (c) => {
    const url = new URL(c.req.url);
    return c.json({ url: `${url.origin}/?boot=${services.auth.mintBootCode()}` });
  });

  // --- overview state and the event stream ---
  app.get("/state", async (c) => c.json(await stateView(services)));

  app.get("/events", (c) =>
    streamSSE(c, async (stream) => {
      let closed = false;
      const unsubscribe = services.ctx.hub.subscribe(
        {
          write: (message) =>
            stream.writeSSE({
              event: message.event,
              id: String(message.id),
              data: JSON.stringify(message.data),
            }),
          close: () => {
            closed = true;
            void stream.close();
          },
        },
        await stateView(services),
      );
      stream.onAbort(() => {
        closed = true;
      });
      // Keep the connection alive and notice a vanished client.
      while (!closed) {
        await stream.sleep(PING_MS);
        if (closed) break;
        await stream.writeSSE({ event: "ping", data: "{}" }).catch(() => {
          closed = true;
        });
      }
      unsubscribe();
    }),
  );

  // --- backlog reads ---
  app.route("/", backlogReadRoutes(services));
  app.route("/", backlogWriteRoutes(services));

  // --- the loop (research R13) ---
  app.get("/loop", async (c) => c.json({ view: services.loop.view ?? (await services.loop.refresh()) }));

  app.post("/loop/start", async (c) => {
    const options = await readBody(c, LoopStartOptionsSchema);
    // The loop starts only on a clean tree: commit the app's own changes first (research R11).
    if (options.commitTray !== false) await services.commitTrayForLoop();
    return c.json(await services.loopControl.start(options));
  });
  app.post("/loop/pause", async (c) => c.json(await services.loopControl.pause()));
  app.post("/loop/resume", async (c) => {
    const body = (await c.req.json<{ commitTray?: boolean }>().catch(() => ({}))) as { commitTray?: boolean };
    if (body.commitTray !== false) await services.commitTrayForLoop();
    return c.json(await services.loopControl.resume());
  });
  app.post("/loop/stop", async (c) => c.json(await services.loopControl.stop()));
  app.post("/loop/kill", async (c) => {
    const { confirm } = await readBody(c, ConfirmRequestSchema);
    return c.json(await services.loopControl.kill(confirm));
  });

  // --- settings and saved views ---
  app.get("/settings", (c) => c.json(services.settings.settings()));
  app.put("/settings", async (c) =>
    c.json(services.settings.saveSettings(await readBody(c, SettingsSchema))),
  );
  app.get("/views", (c) => c.json({ views: services.settings.views() }));
  app.post("/views", async (c) =>
    c.json({ views: services.settings.saveView(await readBody(c, SavedViewSchema)) }),
  );
  app.delete("/views/:name", (c) =>
    c.json({ views: services.settings.deleteView(decodeURIComponent(c.req.param("name"))) }),
  );

  return app;
}
