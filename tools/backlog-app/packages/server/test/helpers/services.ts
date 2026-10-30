// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Builds the server's services and API for a fixture repository, without timers: tests call
 * the pollers' `refresh()` themselves, so every step is deterministic.
 */

import type { Hono } from "hono";
import { createApi } from "../../src/api/app.ts";
import type { ServerContext } from "../../src/context.ts";
import { EventHub } from "../../src/events/hub.ts";
import { SessionAuth } from "../../src/gate/token.ts";
import { repoPaths } from "../../src/repo/git.ts";
import { Services } from "../../src/services.ts";
import { StateDir } from "../../src/settings/state-dir.ts";

/** Services and API of a test repository. */
export interface TestApp {
  /** The services. */
  services: Services;
  /** The API application (no outer security gate: the gate has its own tests). */
  api: Hono;
  /** Refreshes the loop and repository state and reloads the read model. */
  refresh: () => Promise<void>;
  /** Calls the API with a JSON body. */
  post: (path: string, body: unknown) => Promise<{ status: number; json: unknown }>;
  /** Calls the API with GET. */
  get: (path: string) => Promise<{ status: number; json: unknown }>;
}

/**
 * Creates the services of a repository.
 *
 * @param root - The repository root.
 * @returns The test app.
 */
export async function testApp(root: string): Promise<TestApp> {
  const repo = await repoPaths(root);
  const ctx: ServerContext = {
    repo,
    state: new StateDir(repo.commonDir),
    hub: new EventHub(),
    dev: false,
    loopTestArgs: [],
  };
  const services = new Services(ctx, new SessionAuth());
  const api = createApi(services);
  const refresh = async (): Promise<void> => {
    await Promise.all([services.loop.refresh(), services.repo.refresh()]);
    services.reconcile();
    await services.read.reload();
  };
  await refresh();
  const call = async (method: string, path: string, body?: unknown) => {
    const response = await api.request(path, {
      method,
      ...(body === undefined
        ? {}
        : { body: JSON.stringify(body), headers: { "Content-Type": "application/json" } }),
    });
    const text = await response.text();
    return { status: response.status, json: text ? (JSON.parse(text) as unknown) : null };
  };
  return {
    services,
    api,
    refresh,
    post: (path, body) => call("POST", path, body),
    get: (path) => call("GET", path),
  };
}
