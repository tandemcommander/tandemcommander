// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Entry point of the backlog app's server (contracts/launcher.md, *Server start*).
 *
 * Started by `bin/start-backlog-app.sh` as `node packages/server/src/main.ts --root <repo>`;
 * Node 24 strips the TypeScript types natively (research R6). Steps:
 * 1. a running instance of the app for the same repository is reused (it is asked for a new start
 *    address);
 * 2. the server binds 127.0.0.1 on the stable default port 47321 (browser storage - theme, drafts -
 *    survives restarts because the origin stays the same, research R17);
 * 3. the start address with a single-use code is printed and opened in the default browser;
 * 4. Ctrl+C ends the server and its own short-lived children - never the backlog loop, which runs
 *    in its own console window.
 */

import { existsSync, readFileSync, rmSync } from "node:fs";
import { request } from "node:http";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";
import { z } from "zod";
import { loopTestArgsFromEnv, type ServerContext } from "./context.ts";
import { createApi } from "./api/app.ts";
import { EventHub } from "./events/hub.ts";
import { StaticManifest } from "./gate/static.ts";
import { SessionAuth } from "./gate/token.ts";
import { killAllChildren, startProcess } from "./proc/spawn.ts";
import { repoPaths } from "./repo/git.ts";
import { createAppServer, listenLoopback, type DevMiddleware } from "./server.ts";
import { Services } from "./services.ts";
import { StateDir } from "./settings/state-dir.ts";

/** The default port: stable, so the browser's per-origin storage survives restarts. */
export const DEFAULT_PORT = 47321;

/** Folder of the web package. */
const WEB_DIR = fileURLToPath(new URL("../../web/", import.meta.url));

/** The instance file's content. */
const InstanceSchema = z.object({
  pid: z.number(),
  port: z.number(),
  started: z.string(),
  repoRoot: z.string(),
  launcherSecret: z.string(),
});

/**
 * Prints a line to the terminal the server was started from.
 *
 * @param text - The line.
 */
function say(text: string): void {
  process.stdout.write(`${text}\n`);
}

/**
 * Opens an address in the default browser without a command processor: `rundll32` with the URL
 * handler, called by full path (Git's tools shadow System32 names on PATH).
 *
 * @param url - The address.
 */
function openBrowser(url: string): void {
  const systemRoot = process.env["SystemRoot"] ?? "C:\\Windows";
  try {
    startProcess(join(systemRoot, "System32", "rundll32.exe"), ["url.dll,FileProtocolHandler", url], {
      cwd: systemRoot,
    }).done.catch(() => undefined);
  } catch {
    say("(could not open the browser - open the address above yourself)");
  }
}

/**
 * Asks a running instance for a new start address.
 *
 * @param port - Its port.
 * @param secret - Its launcher secret.
 * @returns The address, or null when it does not answer.
 */
function askInstance(port: number, secret: string): Promise<string | null> {
  return new Promise((resolveUrl) => {
    const body = "{}";
    const req = request(
      {
        host: "127.0.0.1",
        port,
        method: "POST",
        path: "/api/instance/boot",
        timeout: 3000,
        headers: {
          host: `127.0.0.1:${port}`,
          "content-type": "application/json",
          "content-length": String(Buffer.byteLength(body)),
          "x-launcher-secret": secret,
        },
      },
      (res) => {
        let text = "";
        res.setEncoding("utf8");
        res.on("data", (chunk: string) => (text += chunk));
        res.on("end", () => {
          try {
            resolveUrl(res.statusCode === 200 ? (JSON.parse(text) as { url: string }).url : null);
          } catch {
            resolveUrl(null);
          }
        });
      },
    );
    req.on("error", () => resolveUrl(null));
    req.on("timeout", () => {
      req.destroy();
      resolveUrl(null);
    });
    req.end(body);
  });
}

/**
 * Starts the server.
 *
 * @returns Resolves when the server is listening.
 */
async function main(): Promise<void> {
  const { values } = parseArgs({
    options: {
      root: { type: "string" },
      port: { type: "string" },
      dev: { type: "boolean", default: false },
      "no-open": { type: "boolean", default: false },
    },
    strict: true,
  });
  const repo = await repoPaths(resolve(values.root ?? "."));
  const state = new StateDir(repo.commonDir);
  const dev = values.dev === true;
  const requestedPort = values.port === undefined ? DEFAULT_PORT : Number(values.port);
  if (!Number.isInteger(requestedPort) || requestedPort < 0 || requestedPort > 65535) {
    say(`invalid --port ${values.port ?? ""}`);
    process.exit(2);
  }

  // 1. Reuse a running instance of this repository.
  const instanceFile = state.file("instance.json");
  if (existsSync(instanceFile)) {
    try {
      const instance = InstanceSchema.parse(JSON.parse(readFileSync(instanceFile, "utf8")));
      const url = await askInstance(instance.port, instance.launcherSecret);
      if (url) {
        say(`Backlog app is already running: ${url}`);
        if (!values["no-open"]) openBrowser(url);
        return;
      }
    } catch {
      // A stale or broken instance file is replaced below.
    }
  }

  // 2. Services and the server.
  const auth = new SessionAuth();
  const hub = new EventHub();
  const ctx: ServerContext = { repo, state, hub, dev, loopTestArgs: loopTestArgsFromEnv() };
  const services = new Services(ctx, auth);
  const api = createApi(services);
  let port = requestedPort;
  // In development mode requests go to Vite once it is ready; Vite needs this server for its
  // live-reload WebSocket, so it is created after the server.
  let vite: DevMiddleware | null = null;
  /**
   * Forwards a request to Vite, or answers 503 while Vite is still starting.
   *
   * @param req - The request.
   * @param res - The response.
   * @param next - Called when Vite has nothing for the path.
   */
  const devMiddleware: DevMiddleware = (req, res, next) => {
    if (vite) {
      vite(req, res, next);
      return;
    }
    res.writeHead(503, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("starting - reload in a moment");
  };
  let staticFiles: StaticManifest | null = null;
  if (!dev) {
    const dist = join(WEB_DIR, "dist");
    if (!existsSync(join(dist, "index.html"))) {
      say("the web client is not built - run bin/start-backlog-app.sh (it builds it) or npm run build");
      process.exit(1);
    }
    staticFiles = StaticManifest.fromFolder(dist);
  }
  const server = createAppServer({
    auth,
    api,
    staticFiles,
    dev,
    port: () => port,
    ...(dev ? { devMiddleware } : {}),
  });
  try {
    port = await listenLoopback(server, requestedPort);
  } catch (error) {
    const code = (error as NodeJS.ErrnoException).code;
    say(
      code === "EADDRINUSE" ? `port ${requestedPort} is in use - start with --port <another>` : String(error),
    );
    process.exit(1);
  }
  if (dev) {
    // Vite runs inside this server (middleware mode); its live-reload WebSocket shares the port.
    const { createServer: createViteServer } = await import("vite");
    const viteServer = await createViteServer({
      root: WEB_DIR,
      configFile: join(WEB_DIR, "vite.config.ts"),
      appType: "spa",
      server: { middlewareMode: true, hmr: { server } },
    });
    vite = viteServer.middlewares;
  }
  // The launcher secret hands out sessions: it is stored only once the state folder is readable
  // by this user alone (review M2); otherwise it is turned off and not written.
  const privateState = state.restrictToOwner();
  if (!privateState) {
    auth.disableLauncherSecret();
    say("note: the app's state folder could not be made private - a second start cannot reuse this one");
  }
  state.writeJson("instance.json", {
    pid: process.pid,
    port,
    started: new Date().toISOString(),
    repoRoot: repo.root,
    launcherSecret: privateState ? auth.launcherSecret : "",
  });
  services.start();

  // 3. The start address.
  const url = `http://127.0.0.1:${port}/?boot=${auth.mintBootCode()}`;
  say(`Backlog app: ${url}`);
  say(`Repository: ${repo.root}${dev ? "  (development mode)" : ""}`);
  say("Ctrl+C stops the app; a running backlog loop keeps running.");
  if (!values["no-open"]) openBrowser(url);

  // 4. Clean shutdown.
  let stopping = false;
  /**
   * Ends the server: no new requests, own children ended, instance file removed.
   */
  const shutdown = (): void => {
    if (stopping) return;
    stopping = true;
    services.stop();
    server.close();
    server.closeAllConnections();
    rmSync(instanceFile, { force: true });
    void killAllChildren().finally(() => process.exit(0));
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
  process.on("SIGBREAK", shutdown);
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? (error.stack ?? error.message) : String(error)}\n`);
  process.exit(1);
});
