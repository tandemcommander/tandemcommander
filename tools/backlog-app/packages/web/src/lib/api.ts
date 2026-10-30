// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The client of the server's API (contracts/http-api.md, contracts/security.md).
 *
 * Session: the address the server opened carries a single-use bootstrap code (`?boot=`). The
 * client exchanges it for the session token, removes it from the address bar, and keeps the token
 * in the tab's session storage and in local storage (other tabs of the same origin). Every call
 * sends the token as `Authorization: Bearer`; the browser never attaches it on its own, which is
 * what makes cross-site requests powerless (research R18). Changing calls are JSON with a
 * `Content-Length` (fetch sets it for a string body).
 */

import type { ErrorBody } from "@backlog-app/shared";

/** Storage key of the session token. */
const TOKEN_KEY = "backlog-app.token";

/** The token of this session, once known. */
let sessionToken: string | null = null;

/** A failed API call with the server's error code. */
export class ApiFailure extends Error {
  /** HTTP status. */
  readonly status: number;

  /** The API error code (`refused`, `changed-underneath`, ...). */
  readonly code: string;

  /** Extra data of the error. */
  readonly detail: unknown;

  /**
   * Creates the failure.
   *
   * @param status - HTTP status.
   * @param code - API error code.
   * @param message - The server's message (for `refused`: the tool's text verbatim).
   * @param detail - Extra data.
   */
  constructor(status: number, code: string, message: string, detail?: unknown) {
    super(message);
    this.name = "ApiFailure";
    this.status = status;
    this.code = code;
    this.detail = detail;
  }
}

/**
 * Reads a stored value; storage can be unavailable.
 *
 * @param storage - Session or local storage.
 * @returns The token or null.
 */
function readToken(storage: Storage): string | null {
  try {
    return storage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
}

/**
 * Establishes the session: claims the bootstrap code of the address, or reuses a stored token.
 *
 * @returns True when a token is available (it may still turn out to be from an earlier start).
 */
export async function establishSession(): Promise<boolean> {
  const url = new URL(window.location.href);
  const boot = url.searchParams.get("boot");
  if (boot) {
    // Remove the code from the address at once: it is single-use and must not stay in history.
    url.searchParams.delete("boot");
    window.history.replaceState(null, "", url.pathname + url.search + url.hash);
    const answer = await fetch("/api/session/claim", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ boot }),
    });
    if (answer.ok) {
      const { token } = (await answer.json()) as { token: string };
      sessionToken = token;
      try {
        window.sessionStorage.setItem(TOKEN_KEY, token);
        window.localStorage.setItem(TOKEN_KEY, token);
      } catch {
        // Without storage the token lives in memory for this page.
      }
      return true;
    }
  }
  sessionToken = readToken(window.sessionStorage) ?? readToken(window.localStorage);
  return sessionToken !== null;
}

/**
 * The session token (for the stream reader).
 *
 * @returns The token or null.
 */
export function currentToken(): string | null {
  return sessionToken;
}

/** Listeners told when the server rejects the token (the app was restarted). */
const sessionLostListeners = new Set<() => void>();

/**
 * Registers a listener for a lost session (401 from the server).
 *
 * @param listener - Called once per loss.
 * @returns The unsubscribe function.
 */
export function onSessionLost(listener: () => void): () => void {
  sessionLostListeners.add(listener);
  return () => sessionLostListeners.delete(listener);
}

/**
 * Performs an API call and decodes the JSON answer.
 *
 * @param method - HTTP method.
 * @param path - Path under `/api`, with query.
 * @param body - JSON body of a changing call.
 * @param signal - Abort signal.
 * @returns The decoded answer.
 * @throws ApiFailure for an error answer.
 */
export async function apiCall<T>(
  method: string,
  path: string,
  body?: unknown,
  signal?: AbortSignal,
): Promise<T> {
  const headers: Record<string, string> = {};
  if (sessionToken) headers["Authorization"] = `Bearer ${sessionToken}`;
  if (body !== undefined) headers["Content-Type"] = "application/json";
  const init: RequestInit = { method, headers };
  if (body !== undefined) init.body = JSON.stringify(body);
  if (signal) init.signal = signal;
  const answer = await fetch(path, init);
  if (answer.status === 401) {
    for (const listener of sessionLostListeners) listener();
  }
  const text = await answer.text();
  if (!answer.ok) {
    let parsed: ErrorBody | null;
    try {
      parsed = JSON.parse(text) as ErrorBody;
    } catch {
      parsed = null;
    }
    throw new ApiFailure(
      answer.status,
      parsed?.error.code ?? "http",
      parsed?.error.message ?? `${answer.status} ${answer.statusText}`,
      parsed?.error.detail,
    );
  }
  return (text ? JSON.parse(text) : null) as T;
}

/**
 * GET helper.
 *
 * @param path - Path under `/api`.
 * @param signal - Abort signal.
 * @returns The decoded answer.
 */
export function apiGet<T>(path: string, signal?: AbortSignal): Promise<T> {
  return apiCall<T>("GET", path, undefined, signal);
}

/**
 * POST helper (also for changes without a body: sends `{}` so the request is JSON).
 *
 * @param path - Path under `/api`.
 * @param body - JSON body.
 * @returns The decoded answer.
 */
export function apiPost<T>(path: string, body: unknown = {}): Promise<T> {
  return apiCall<T>("POST", path, body);
}
