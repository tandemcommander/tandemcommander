// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Playwright configuration of the end-to-end tests.
 *
 * The tests run on the Microsoft Edge that Windows 11 already has (`channel: "msedge"`), so no
 * browser is downloaded. Each spec starts its own server against a temporary fixture repository
 * (see `e2e/harness.ts`); the real `backlog/` is never used. Specs run one after another because
 * they start real Python and git processes.
 */

import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "e2e",
  testMatch: /.*\.spec\.ts/,
  fullyParallel: false,
  workers: 1,
  timeout: 120_000,
  expect: { timeout: 10_000 },
  reporter: [["list"]],
  outputDir: "test-results",
  use: {
    channel: "msedge",
    headless: true,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
});
