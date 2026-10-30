// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the access rules (contracts/security.md, *Tests*): every rule is exercised through
 * a real HTTP server on 127.0.0.1 with hand-made headers, because a browser would never let a test
 * forge `Host` or `Origin`.
 */

import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { request, type IncomingHttpHeaders, type Server } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Hono } from "hono";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { SessionAuth } from "../src/gate/token.ts";
import { StaticManifest } from "../src/gate/static.ts";
import { createAppServer, listenLoopback } from "../src/server.ts";

/** Answer of a raw HTTP request. */
interface RawAnswer {
  /** HTTP status. */
  status: number;
  /** Response headers. */
  headers: IncomingHttpHeaders;
  /** Body text. */
  body: string;
}

/**
 * Sends a request with exactly the given headers (no browser rules apply).
 *
 * @param port - Server port.
 * @param method - HTTP method.
 * @param path - Request path with query.
 * @param headers - Headers to send, including `host`.
 * @param body - Optional body.
 * @returns The answer.
 */
function send(
  port: number,
  method: string,
  path: string,
  headers: Record<string, string>,
  body?: string,
): Promise<RawAnswer> {
  return new Promise((resolve, reject) => {
    const all =
      body === undefined ? headers : { ...headers, "content-length": String(Buffer.byteLength(body)) };
    const req = request({ host: "127.0.0.1", port, method, path, headers: all }, (res) => {
      let text = "";
      res.setEncoding("utf8");
      res.on("data", (chunk: string) => (text += chunk));
      res.on("end", () => resolve({ status: res.statusCode ?? 0, headers: res.headers, body: text }));
    });
    req.on("error", reject);
    if (body !== undefined) req.write(body);
    req.end();
  });
}

describe("security gate", () => {
  let server: Server;
  let port = 0;
  let auth: SessionAuth;
  let token = "";
  /** Headers of a correct same-origin request with the token. */
  let good: () => Record<string, string>;

  beforeAll(async () => {
    // A minimal web build so the static manifest has something to serve.
    const dist = mkdtempSync(join(tmpdir(), "backlog-app-dist-"));
    mkdirSync(join(dist, "assets"));
    writeFileSync(join(dist, "index.html"), "<!doctype html><title>app</title>");
    writeFileSync(join(dist, "assets", "app-1234.js"), "console.log(1)");

    auth = new SessionAuth();
    const api = new Hono();
    api.get("/api/ping", (c) => c.json({ ok: true }));
    api.post("/api/echo", async (c) => c.json(await c.req.json()));
    api.post("/api/session/claim", async (c) => {
      const { boot } = await c.req.json<{ boot: string }>();
      const claimed = auth.claim(boot);
      return claimed ? c.json({ token: claimed }) : c.json({ error: { code: "unauthorized" } }, 401);
    });
    server = createAppServer({
      auth,
      api,
      staticFiles: StaticManifest.fromFolder(dist),
      dev: false,
      port: () => port,
    });
    port = await listenLoopback(server, 0);
    const code = auth.mintBootCode();
    const claim = await send(
      port,
      "POST",
      "/api/session/claim",
      { host: `127.0.0.1:${port}`, origin: `http://127.0.0.1:${port}`, "content-type": "application/json" },
      JSON.stringify({ boot: code }),
    );
    token = (JSON.parse(claim.body) as { token: string }).token;
    good = () => ({
      host: `127.0.0.1:${port}`,
      origin: `http://127.0.0.1:${port}`,
      "content-type": "application/json",
      authorization: `Bearer ${token}`,
    });
  });

  afterAll(() => {
    server.close();
  });

  it("listens on 127.0.0.1 only", () => {
    const address = server.address();
    expect(typeof address === "object" && address?.address).toBe("127.0.0.1");
  });

  it("serves a correct request", async () => {
    const answer = await send(port, "GET", "/api/ping", good());
    expect(answer.status).toBe(200);
    expect(answer.body).toBe('{"ok":true}');
  });

  it("accepts localhost as host name too", async () => {
    const answer = await send(port, "GET", "/api/ping", { ...good(), host: `localhost:${port}` });
    expect(answer.status).toBe(200);
  });

  it("refuses a foreign Host with 421 and no body detail (DNS rebinding)", async () => {
    const answer = await send(port, "GET", "/api/ping", { ...good(), host: `evil.example:${port}` });
    expect(answer.status).toBe(421);
    expect(answer.body).toBe("");
    const wrongPort = await send(port, "GET", "/", { host: "127.0.0.1:1" });
    expect(wrongPort.status).toBe(421);
  });

  it("refuses a POST from a foreign origin with 403", async () => {
    const answer = await send(port, "POST", "/api/echo", { ...good(), origin: "http://evil.example" }, "{}");
    expect(answer.status).toBe(403);
  });

  it("refuses a POST without an Origin with 403", async () => {
    const headers = good();
    delete headers["origin"];
    const answer = await send(port, "POST", "/api/echo", headers, "{}");
    expect(answer.status).toBe(403);
  });

  it("refuses Sec-Fetch-Site cross-site and same-site with 403", async () => {
    for (const site of ["cross-site", "same-site"]) {
      const answer = await send(port, "POST", "/api/echo", { ...good(), "sec-fetch-site": site }, "{}");
      expect(answer.status).toBe(403);
    }
    const sameOrigin = await send(
      port,
      "POST",
      "/api/echo",
      { ...good(), "sec-fetch-site": "same-origin" },
      "{}",
    );
    expect(sameOrigin.status).toBe(200);
  });

  it("refuses a form-encoded POST with 415", async () => {
    const answer = await send(
      port,
      "POST",
      "/api/echo",
      { ...good(), "content-type": "application/x-www-form-urlencoded" },
      "a=1",
    );
    expect(answer.status).toBe(415);
  });

  it("refuses a chunked body without Content-Length with 411", async () => {
    const answer = await new Promise<number>((resolve, reject) => {
      const req = request(
        { host: "127.0.0.1", port, method: "POST", path: "/api/echo", headers: good() },
        (res) => {
          res.resume();
          resolve(res.statusCode ?? 0);
        },
      );
      req.on("error", reject);
      req.write("{}");
      req.end();
    });
    expect(answer).toBe(411);
  });

  it("refuses a body over 256 KiB with 413", async () => {
    const big = JSON.stringify({ text: "x".repeat(300 * 1024) });
    const answer = await send(port, "POST", "/api/echo", good(), big);
    expect(answer.status).toBe(413);
  });

  it("refuses a missing, wrong or foreign token with 401", async () => {
    const headers = good();
    delete headers["authorization"];
    expect((await send(port, "GET", "/api/ping", headers)).status).toBe(401);
    expect((await send(port, "GET", "/api/ping", { ...good(), authorization: "Bearer nope" })).status).toBe(
      401,
    );
    expect((await send(port, "GET", "/api/ping", { ...good(), authorization: token })).status).toBe(401);
    // A token of an earlier start is just another wrong token.
    const earlier = new SessionAuth();
    expect(
      (await send(port, "GET", "/api/ping", { ...good(), authorization: `Bearer ${earlier.token}` })).status,
    ).toBe(401);
  });

  it("accepts a bootstrap code once only", async () => {
    const code = auth.mintBootCode();
    const headers = { ...good() };
    delete headers["authorization"];
    const first = await send(port, "POST", "/api/session/claim", headers, JSON.stringify({ boot: code }));
    expect(first.status).toBe(200);
    const second = await send(port, "POST", "/api/session/claim", headers, JSON.stringify({ boot: code }));
    expect(second.status).toBe(401);
  });

  it("refuses an expired bootstrap code", () => {
    let now = 1_000_000;
    const timed = new SessionAuth(() => now);
    const code = timed.mintBootCode();
    now += 121_000;
    expect(timed.claim(code)).toBeNull();
  });

  it("sets the security headers and no CORS headers", async () => {
    const answer = await send(port, "GET", "/api/ping", good());
    expect(answer.headers["content-security-policy"]).toContain("default-src 'self'");
    expect(answer.headers["content-security-policy"]).toContain("frame-ancestors 'none'");
    expect(answer.headers["x-content-type-options"]).toBe("nosniff");
    expect(answer.headers["referrer-policy"]).toBe("no-referrer");
    expect(answer.headers["cache-control"]).toBe("no-store");
    expect(Object.keys(answer.headers).some((h) => h.startsWith("access-control-"))).toBe(false);
  });

  it("serves static files by exact lookup only (no traversal)", async () => {
    const host = { host: `127.0.0.1:${port}` };
    expect((await send(port, "GET", "/assets/app-1234.js", host)).status).toBe(200);
    for (const path of [
      "/assets/..%5C..%5Cpackage.json",
      "/assets/../index.html",
      "/assets/%2e%2e/%2e%2e/package.json",
      "/assets/app-1234.js%00.png",
      "/assets/missing.js",
    ]) {
      expect((await send(port, "GET", path, host)).status, path).toBe(404);
    }
    // Any other path is the single-page app.
    const spa = await send(port, "GET", "/items/some-slug", host);
    expect(spa.status).toBe(200);
    expect(spa.body).toContain("<title>app</title>");
  });

  it("does not serve the API's data without the token, even for static-looking paths", async () => {
    expect((await send(port, "GET", "/api/ping.js", { host: `127.0.0.1:${port}` })).status).toBe(401);
  });
});
