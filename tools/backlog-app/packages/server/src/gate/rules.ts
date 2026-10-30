// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The access rules applied to every request before routing (contracts/security.md, rules
 * 2-5). Rule 1 (listen on 127.0.0.1 only) is in `server.ts`, rules 6-7 in the static manifest and
 * the identifier checks of the routes.
 *
 * Order matters: the Host check runs first, so a page reached through DNS rebinding learns
 * nothing - not even whether a token would be accepted.
 */

import type { IncomingHttpHeaders } from "node:http";
import type { SessionAuth } from "./token.ts";

/** Largest accepted request body in bytes (256 KiB). */
export const MAX_BODY_BYTES = 256 * 1024;

/** Methods that change something; they need Origin, JSON and the token. */
const CHANGING_METHODS = new Set(["POST", "PUT", "PATCH", "DELETE"]);

/** Paths that are event streams (long GET requests). */
const STREAM_PATH = /^\/api\/(events|runs\/[^/]+\/stream|ai\/jobs\/[^/]+\/stream)$/;

/** API paths that work without the token. */
const TOKENLESS_PATHS = new Set(["/api/session/claim", "/api/instance/boot"]);

/** A refusal of the gate. */
export interface GateRefusal {
  /** HTTP status to answer with. */
  status: number;
  /** Error code of the API (empty for 421, which has no body). */
  code: string;
  /** Short text for the error body. */
  message: string;
}

/** What the rules need to know about a request. */
export interface GateRequest {
  /** HTTP method. */
  method: string;
  /** Path without the query. */
  pathname: string;
  /** Request headers (lower-case names). */
  headers: IncomingHttpHeaders;
}

/**
 * The origins the app's own page has.
 *
 * @param port - The listening port.
 * @returns The two allowed origins.
 */
function ownOrigins(port: number): string[] {
  return [`http://127.0.0.1:${port}`, `http://localhost:${port}`];
}

/**
 * Applies rules 2-5 to a request.
 *
 * @param request - Method, path and headers.
 * @param port - The listening port.
 * @param auth - The session secrets.
 * @returns A refusal, or null when the request may proceed.
 */
export function checkRequest(request: GateRequest, port: number, auth: SessionAuth): GateRefusal | null {
  const { method, pathname, headers } = request;

  // Rule 2: the Host must be this server's own address (DNS rebinding).
  const host = headers.host ?? "";
  if (host !== `127.0.0.1:${port}` && host !== `localhost:${port}`) {
    return { status: 421, code: "", message: "" };
  }

  const isApi = pathname === "/api" || pathname.startsWith("/api/");
  const changing = CHANGING_METHODS.has(method);
  const stream = method === "GET" && STREAM_PATH.test(pathname);
  if (!isApi && method !== "GET" && method !== "HEAD") {
    return { status: 405, code: "invalid-request", message: "method not allowed" };
  }

  // The launcher-to-instance call comes from a Node process, never from a page: browsers always
  // send Origin on a POST, so requiring its absence keeps pages out; the launcher secret is the
  // authentication.
  if (pathname === "/api/instance/boot") {
    if (method !== "POST" || headers.origin !== undefined) {
      return { status: 403, code: "forbidden-origin", message: "not allowed from a page" };
    }
    const secret = headers["x-launcher-secret"];
    if (!auth.verifyLauncherSecret(typeof secret === "string" ? secret : undefined)) {
      return { status: 401, code: "unauthorized", message: "wrong launcher secret" };
    }
    return null;
  }

  // Rule 3: changing requests and streams must come from the app's own page.
  if (changing || stream) {
    const site = headers["sec-fetch-site"];
    if (site !== undefined && site !== "same-origin" && site !== "none") {
      return { status: 403, code: "forbidden-origin", message: "cross-site request refused" };
    }
    const origin = headers.origin;
    // Browsers send Origin on every POST; a same-origin GET (a stream) may come without it.
    if (changing && origin === undefined) {
      return { status: 403, code: "forbidden-origin", message: "a changing request needs an Origin" };
    }
    if (origin !== undefined && !ownOrigins(port).includes(origin)) {
      return { status: 403, code: "forbidden-origin", message: "foreign origin refused" };
    }
  }

  // Rule 4: changing requests are JSON with a bounded body (no "simple" cross-site form posts).
  if (changing) {
    const type = (headers["content-type"] ?? "").split(";")[0]?.trim().toLowerCase();
    if (type !== "application/json") {
      return {
        status: 415,
        code: "unsupported-media-type",
        message: "changing requests must be application/json",
      };
    }
    // A body without a declared length (chunked) is refused: browsers always declare it for a
    // text body, and with a declared length Node's parser never reads more than that.
    const declared = headers["content-length"];
    if (declared === undefined) {
      return { status: 411, code: "invalid-request", message: "a changing request needs a Content-Length" };
    }
    const length = Number(declared);
    if (!Number.isFinite(length) || length > MAX_BODY_BYTES) {
      return { status: 413, code: "too-large", message: "the request body is larger than 256 KiB" };
    }
  }

  // Rule 5: every API route except the bootstrap claim needs this start's token.
  if (isApi && !TOKENLESS_PATHS.has(pathname)) {
    const authorization = headers.authorization;
    if (!auth.verifyBearer(typeof authorization === "string" ? authorization : undefined)) {
      return {
        status: 401,
        code: "unauthorized",
        message: "missing or wrong token - open the address the app printed",
      };
    }
  }
  return null;
}
