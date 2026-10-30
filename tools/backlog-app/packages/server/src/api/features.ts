// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Routes of the feature records and of release readiness (contracts/http-api.md, *Runs and
 * features*; user stories 4 and 6).
 *
 * Every route only reads. A feature is addressed by its three-digit number, a feature file by a
 * path that must appear in the feature's own listing (contracts/security.md, rule 7); the release
 * page reads local data only and offers no action (FR-046).
 */

import { Hono } from "hono";
import type { Services } from "../services.ts";
import { FEATURE_PATTERN, FeaturesService } from "../features/records.ts";
import { ReleaseService } from "../features/release.ts";
import { param } from "./common.ts";

/**
 * Creates the routes.
 *
 * @param services - The server's services.
 * @param features - The feature records (one is created when not given).
 * @param release - The release readiness (one is created when not given).
 * @returns The routes, mounted under `/api`.
 */
export function featureRoutes(
  services: Services,
  features: FeaturesService = new FeaturesService(services),
  release: ReleaseService = new ReleaseService(services),
): Hono {
  const app = new Hono();

  app.get("/features", async (c) => c.json({ features: await features.list(c.req.query("q") ?? "") }));

  app.get("/features/:nnn", async (c) =>
    c.json(await features.feature(param(c.req.param("nnn"), FEATURE_PATTERN, "feature"))),
  );

  app.get("/features/:nnn/files/:path{.+}", async (c) => {
    const number = param(c.req.param("nnn"), FEATURE_PATTERN, "feature");
    // The path only selects an entry of the feature's listing; it is never used as a path itself.
    return c.json(await features.file(number, c.req.param("path")));
  });

  app.get("/release", async (c) => c.json(await release.view()));

  return app;
}
