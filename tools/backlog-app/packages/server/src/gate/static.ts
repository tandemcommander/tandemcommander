// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Static files of the built web client, served by exact lookup (contracts/security.md,
 * rule 6).
 *
 * At start the server lists `packages/web/dist/` once into a map from URL path to file. A request
 * is served only when its path is exactly a key of that map. No text of a request ever reaches a
 * path function, which removes the whole class of traversal bugs (`..`, `%5C` on Windows, NUL
 * bytes) instead of filtering them - the generic static handler of the framework had exactly such
 * an advisory in 2026 (analysis A3 §2.1).
 */

import { readdirSync, readFileSync, statSync } from "node:fs";
import { extname, join, relative } from "node:path";

/** MIME types of the files a Vite build produces. */
const MIME_TYPES: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
  ".woff2": "font/woff2",
  ".txt": "text/plain; charset=utf-8",
  ".map": "application/json; charset=utf-8",
};

/** One file the manifest can serve. */
export interface StaticFile {
  /** File content (built files are small; they are read once at start). */
  body: Buffer;
  /** Content type. */
  type: string;
  /** True for content-hashed assets, which may be cached forever. */
  immutable: boolean;
}

/** The map of servable files of one web build. */
export class StaticManifest {
  /** Files by URL path (`/index.html`, `/assets/index-abc123.js`). */
  private readonly files: Map<string, StaticFile>;

  /**
   * Creates a manifest from prepared entries (tests) - use {@link StaticManifest.fromFolder}.
   *
   * @param files - Files by URL path.
   */
  constructor(files: Map<string, StaticFile>) {
    this.files = files;
  }

  /**
   * Lists a build folder into a manifest.
   *
   * @param folder - The `dist` folder of the web build.
   * @returns The manifest.
   */
  static fromFolder(folder: string): StaticManifest {
    const files = new Map<string, StaticFile>();
    /**
     * Adds the files of one folder, recursively.
     *
     * @param dir - Absolute folder path.
     */
    const add = (dir: string): void => {
      for (const name of readdirSync(dir)) {
        const path = join(dir, name);
        if (statSync(path).isDirectory()) {
          add(path);
          continue;
        }
        const urlPath = `/${relative(folder, path).replaceAll("\\", "/")}`;
        files.set(urlPath, {
          body: readFileSync(path),
          type: MIME_TYPES[extname(name).toLowerCase()] ?? "application/octet-stream",
          immutable: urlPath.startsWith("/assets/"),
        });
      }
    };
    add(folder);
    return new StaticManifest(files);
  }

  /**
   * Finds the file for a request path. Paths under `/assets/` must match exactly; any other path
   * that is not a file is the single-page app (`index.html`), so deep links work.
   *
   * @param pathname - The raw request path (not decoded - decoding could create a match).
   * @returns The file, or null for 404.
   */
  lookup(pathname: string): StaticFile | null {
    const exact = this.files.get(pathname);
    if (exact) return exact;
    if (pathname.startsWith("/assets/")) return null;
    return this.files.get("/index.html") ?? null;
  }
}
