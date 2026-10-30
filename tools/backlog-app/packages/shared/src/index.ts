// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Entry point of `@backlog-app/shared`: every schema, type and pure rule the server and the
 * web client share. The package is consumed as TypeScript source (no build): Node strips the
 * types natively on the server, Vite compiles it for the browser (research R6).
 */

export * from "./schemas/backlog.ts";
export * from "./schemas/loop.ts";
export * from "./schemas/runs.ts";
export * from "./schemas/app-state.ts";
export * from "./api/errors.ts";
export * from "./api/requests.ts";
export * from "./api/events.ts";
