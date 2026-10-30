// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The outer HTTP server (research R4): it applies the access rules to every request first,
 * then hands `/api/*` to the Hono application and everything else to the static manifest of the
 * web build (or, in development mode, to Vite's middleware).
 *
 * The server listens on 127.0.0.1 only and verifies that after binding (contracts/security.md,
 * rule 1): never `0.0.0.0` or `::`, so nothing on the network can reach it, and Windows Firewall
 * never asks.
 */

import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import type { AddressInfo } from "node:net";
import { getRequestListener } from "@hono/node-server";
import type { Hono } from "hono";
import { securityHeaders } from "./gate/headers.ts";
import { checkRequest } from "./gate/rules.ts";
import type { SessionAuth } from "./gate/token.ts";
import type { StaticManifest } from "./gate/static.ts";

/** A connect-style middleware (Vite's dev server exposes one). */
export type DevMiddleware = (req: IncomingMessage, res: ServerResponse, next: () => void) => void;

/** What the outer server needs. */
export interface AppServerOptions {
  /** The session secrets. */
  auth: SessionAuth;
  /** The API application (routes under `/api`). */
  api: Hono;
  /** The built web client; null in development mode. */
  staticFiles: StaticManifest | null;
  /** Development mode (relaxed CSP for live reload). */
  dev: boolean;
  /** The listening port, read per request (known only after binding). */
  port: () => number;
  /** Vite's middleware in development mode. */
  devMiddleware?: DevMiddleware;
}

/**
 * Writes a JSON error answer of the gate.
 *
 * @param res - The response.
 * @param status - HTTP status.
 * @param code - API error code.
 * @param message - Text.
 */
function refuse(res: ServerResponse, status: number, code: string, message: string): void {
  if (status === 421) {
    // A misdirected request learns nothing about this server (DNS rebinding).
    res.writeHead(421, { "Content-Length": "0" });
    res.end();
    return;
  }
  const body = JSON.stringify({ error: { code, message } });
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(body),
  });
  res.end(body);
}

/**
 * Creates the outer server (not yet listening).
 *
 * @param options - Secrets, API, static files, mode, port.
 * @returns The Node HTTP server.
 */
export function createAppServer(options: AppServerOptions): Server {
  const apiListener = getRequestListener(options.api.fetch);
  return createServer((req, res) => {
    const url = req.url ?? "/";
    const query = url.indexOf("?");
    // The raw path is used on purpose: decoding it could turn `%2e%2e` into a traversal.
    const pathname = query >= 0 ? url.slice(0, query) : url;
    const method = req.method ?? "GET";
    const port = options.port();

    const refusal = checkRequest({ method, pathname, headers: req.headers }, port, options.auth);
    if (refusal) {
      // Security headers are set on refusals too, so a refused page can never be framed.
      for (const [name, value] of Object.entries(securityHeaders(options.dev, port, "no-store"))) {
        res.setHeader(name, value);
      }
      refuse(res, refusal.status, refusal.code, refusal.message);
      return;
    }

    const isApi = pathname === "/api" || pathname.startsWith("/api/");
    const staticFile = !isApi && options.staticFiles ? options.staticFiles.lookup(pathname) : null;
    const cache = staticFile?.immutable ? "immutable" : "no-store";
    for (const [name, value] of Object.entries(securityHeaders(options.dev, port, cache))) {
      res.setHeader(name, value);
    }

    if (isApi) {
      void apiListener(req, res);
      return;
    }
    if (options.devMiddleware) {
      options.devMiddleware(req, res, () => refuse(res, 404, "not-found", "not found"));
      return;
    }
    if (!staticFile) {
      refuse(res, 404, "not-found", "not found");
      return;
    }
    res.writeHead(200, { "Content-Type": staticFile.type, "Content-Length": staticFile.body.length });
    res.end(method === "HEAD" ? undefined : staticFile.body);
  });
}

/**
 * Binds a server to 127.0.0.1 and verifies the address (rule 1).
 *
 * @param server - The server.
 * @param port - The port; 0 lets the system choose (tests).
 * @returns The bound port.
 * @throws Error when the port is in use or the bound address is not 127.0.0.1.
 */
export function listenLoopback(server: Server, port: number): Promise<number> {
  return new Promise((resolve, reject) => {
    /**
     * Reports a bind failure (typically `EADDRINUSE`).
     *
     * @param error - The listen error.
     */
    const onError = (error: Error): void => {
      reject(error);
    };
    server.once("error", onError);
    server.listen({ port, host: "127.0.0.1", exclusive: true }, () => {
      server.off("error", onError);
      const address = server.address() as AddressInfo | null;
      if (!address || address.address !== "127.0.0.1") {
        server.close();
        reject(
          new Error(
            `the server is bound to ${address?.address ?? "nothing"}, not 127.0.0.1 - refusing to run`,
          ),
        );
        return;
      }
      resolve(address.port);
    });
  });
}
