// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Vite configuration of the web client (research R2).
 *
 * A plain single-page application: `vite build` writes `dist/`, which the server lists into its
 * static manifest; in development mode the server runs Vite in middleware mode on its own port,
 * behind the same security gate (contracts/security.md). Nothing is loaded from a CDN: fonts are
 * the system's, icons are bundled (FR-004).
 */

import { fileURLToPath } from "node:url";
import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  root: fileURLToPath(new URL(".", import.meta.url)),
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) },
  },
  build: {
    outDir: "dist",
    emptyOutDir: true,
    // Source maps stay out of the build: the app is used, not debugged, from dist.
    sourcemap: false,
    chunkSizeWarningLimit: 1500,
  },
  server: {
    // Middleware mode only (the server owns the port); never listen on the network.
    host: "127.0.0.1",
    strictPort: true,
  },
});
