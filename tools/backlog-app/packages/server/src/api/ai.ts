// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Routes of the AI jobs (contracts/http-api.md, *AI jobs*; contracts/ai-jobs.md).
 *
 * A job is started, listed, read, cancelled and - once the maintainer reviewed its proposal -
 * applied through the backlog tool. `GET /api/ai/jobs/{id}/stream` sends the job's progress lines
 * (`event: progress`, the id is the line's 1-based number, so a reconnect with `Last-Event-ID`
 * continues after it) and ends with `event: done` (the proposal or answer) or `event: failed`
 * (failed or cancelled, with the job).
 */

import { Hono, type Context } from "hono";
import { streamSSE } from "hono/streaming";
import { AiJobApplyRequestSchema, AiJobCreateRequestSchema, ApiError } from "@backlog-app/shared";
import type { Services } from "../services.ts";
import { AiJobRunner, JOB_ID_PATTERN } from "../ai/runner.ts";
import { applyProposal } from "../ai/apply.ts";
import { param, readBody } from "./common.ts";

/** Milliseconds between looks at a running job on its stream. */
const STREAM_POLL_MS = 250;

/**
 * Creates the routes.
 *
 * @param services - The server's services.
 * @param runner - The one job runner of the server (one is created when not given).
 * @returns The routes, mounted under `/api`.
 */
export function aiRoutes(services: Services, runner: AiJobRunner = new AiJobRunner(services)): Hono {
  const app = new Hono();

  /**
   * The job of the route, validated by form and existence.
   *
   * @param c - The request context.
   * @returns The job id.
   * @throws ApiError `not-found`.
   */
  const jobId = (c: Context): string => {
    const id = param(c.req.param("id"), JOB_ID_PATTERN, "job");
    if (!runner.get(id)) throw new ApiError("not-found", "no such job");
    return id;
  };

  app.post("/ai/jobs", async (c) => c.json(await runner.start(await readBody(c, AiJobCreateRequestSchema))));

  app.get("/ai/jobs", (c) => c.json({ jobs: runner.list() }));

  app.get("/ai/jobs/:id", (c) => c.json(runner.get(jobId(c))));

  app.post("/ai/jobs/:id/cancel", async (c) => c.json(await runner.cancel(jobId(c))));

  app.post("/ai/jobs/:id/apply", async (c) => {
    const id = jobId(c);
    const body = await readBody(c, AiJobApplyRequestSchema);
    return c.json(await applyProposal(services, runner, id, body));
  });

  app.get("/ai/jobs/:id/stream", (c) => {
    const id = jobId(c);
    const resume = Number(c.req.header("last-event-id") ?? "0");
    let sent = Number.isInteger(resume) && resume >= 0 ? resume : 0;
    return streamSSE(c, async (stream) => {
      let closed = false;
      stream.onAbort(() => {
        closed = true;
      });
      while (!closed) {
        const job = runner.get(id);
        if (!job) return;
        // Progress lines not sent yet, each with its 1-based number as the event id.
        while (sent < job.progress.length) {
          await stream.writeSSE({
            event: "progress",
            id: String(sent + 1),
            data: JSON.stringify(job.progress[sent]),
          });
          sent++;
        }
        if (job.state !== "running") {
          await stream.writeSSE({
            event: job.state === "done" ? "done" : "failed",
            data: JSON.stringify(job),
          });
          return;
        }
        await stream.sleep(STREAM_POLL_MS);
      }
    });
  });

  return app;
}
