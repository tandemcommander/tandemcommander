// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Vitest configuration: one project per workspace package.
 *
 * `shared` and `server` run in Node; `web` runs its component tests in jsdom. Tests that need a
 * repository build a temporary one (see `packages/server/test/helpers/fixture-repo.ts`) and
 * never touch the real `backlog/`.
 */

import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

/** Absolute path of the web sources, for the `@/` import alias of the web package. */
const webSrc = fileURLToPath(new URL("./packages/web/src", import.meta.url));

export default defineConfig({
  test: {
    projects: [
      {
        test: {
          name: "shared",
          root: "packages/shared",
          include: ["test/**/*.test.ts"],
          environment: "node",
        },
      },
      {
        test: {
          name: "server",
          root: "packages/server",
          include: ["test/**/*.test.ts"],
          environment: "node",
          // Several tests start real Python and git processes on Windows.
          testTimeout: 60_000,
          hookTimeout: 60_000,
        },
      },
      {
        resolve: { alias: { "@": webSrc } },
        test: {
          name: "web",
          root: "packages/web",
          include: ["test/**/*.test.{ts,tsx}"],
          environment: "jsdom",
        },
      },
      {
        test: {
          name: "repository",
          root: ".",
          include: ["test/**/*.test.ts"],
          environment: "node",
        },
      },
    ],
  },
});
