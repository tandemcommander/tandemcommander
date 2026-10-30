// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Response headers of every answer (contracts/security.md, *Response headers*).
 *
 * The content security policy loads nothing from the network (FR-004): scripts, styles, fonts and
 * images come only from the app itself; inline scripts are not allowed (the theme script is an
 * external file, research R3). Inline styles are allowed because the UI primitives position
 * popovers with style attributes. No `Access-Control-*` header is ever sent, so other origins
 * cannot read answers.
 */

/**
 * The content security policy.
 *
 * @param dev - Development mode: Vite's live reload needs a WebSocket to the dev server and its
 *   inline preamble.
 * @param port - The listening port (for the dev WebSocket).
 * @returns The header value.
 */
export function contentSecurityPolicy(dev: boolean, port: number): string {
  const script = dev ? "script-src 'self' 'unsafe-inline'" : "script-src 'self'";
  const connect = dev
    ? `connect-src 'self' ws://127.0.0.1:${port} ws://localhost:${port}`
    : "connect-src 'self'";
  return [
    "default-src 'self'",
    script,
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data:",
    "font-src 'self'",
    connect,
    "object-src 'none'",
    "base-uri 'none'",
    "form-action 'self'",
    "frame-ancestors 'none'",
  ].join("; ");
}

/**
 * The security headers of an answer.
 *
 * @param dev - Development mode (relaxed CSP for live reload).
 * @param port - The listening port.
 * @param cache - `no-store` for the API and the page, `immutable` for hashed assets.
 * @returns Header names and values.
 */
export function securityHeaders(
  dev: boolean,
  port: number,
  cache: "no-store" | "immutable",
): Record<string, string> {
  return {
    "Content-Security-Policy": contentSecurityPolicy(dev, port),
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Cross-Origin-Opener-Policy": "same-origin",
    "Cross-Origin-Resource-Policy": "same-origin",
    "Cache-Control": cache === "immutable" ? "public, max-age=31536000, immutable" : "no-store",
  };
}
