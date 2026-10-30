// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The per-start session token and the one-time bootstrap codes (contracts/security.md,
 * *Token and bootstrap*; research R18).
 *
 * Why a bearer token and not a cookie: cookies are not port-isolated on 127.0.0.1 - a cookie of
 * this app would be sent to every server any user runs on any loopback port - and a cookie is
 * attached automatically, which reintroduces cross-site request forgery. A bearer header is
 * never attached by the browser on its own.
 *
 * The token is never written to disk and never appears in a URL. The browser gets it once, by
 * exchanging a single-use bootstrap code from the address the server opened.
 */

import { randomBytes, timingSafeEqual } from "node:crypto";

/** How long a bootstrap code stays valid, in milliseconds. */
export const BOOT_CODE_LIFETIME_MS = 120_000;

/** The session secrets of one server start. */
export class SessionAuth {
  /** The bearer token of this start (32 random bytes, base64url). */
  readonly token: string;

  /**
   * Secret a second launch of the app uses to ask this instance for a new bootstrap address; it
   * is written to the instance file in the git common directory (data-model *Instance*).
   */
  readonly launcherSecret: string;

  /** Outstanding bootstrap codes and their expiry times. */
  private readonly bootCodes = new Map<string, number>();

  /** The clock (injectable for tests). */
  private readonly now: () => number;

  /**
   * Creates the secrets of a new start.
   *
   * @param now - Clock in milliseconds; defaults to `Date.now`.
   */
  constructor(now: () => number = Date.now) {
    this.now = now;
    this.token = randomBytes(32).toString("base64url");
    this.launcherSecret = randomBytes(32).toString("base64url");
  }

  /**
   * Creates a new single-use bootstrap code, valid for {@link BOOT_CODE_LIFETIME_MS}.
   *
   * @returns The code (16 random bytes, base64url).
   */
  mintBootCode(): string {
    this.dropExpired();
    const code = randomBytes(16).toString("base64url");
    this.bootCodes.set(code, this.now() + BOOT_CODE_LIFETIME_MS);
    return code;
  }

  /**
   * Exchanges a bootstrap code for the token. A code works once; an unknown or expired code
   * yields nothing.
   *
   * @param code - The code from the opened address.
   * @returns The token, or null.
   */
  claim(code: string): string | null {
    this.dropExpired();
    if (!this.bootCodes.has(code)) return null;
    this.bootCodes.delete(code);
    return this.token;
  }

  /**
   * Checks an `Authorization` header in constant time.
   *
   * @param header - The header value (`Bearer <token>`), possibly absent.
   * @returns True when it carries this start's token.
   */
  verifyBearer(header: string | undefined): boolean {
    if (!header?.startsWith("Bearer ")) return false;
    return safeEqual(header.slice("Bearer ".length), this.token);
  }

  /**
   * Checks the launcher secret in constant time.
   *
   * @param value - The secret a second launch sent.
   * @returns True when it matches.
   */
  verifyLauncherSecret(value: string | undefined): boolean {
    return value !== undefined && safeEqual(value, this.launcherSecret);
  }

  /** Forgets expired bootstrap codes. */
  private dropExpired(): void {
    const now = this.now();
    for (const [code, expires] of this.bootCodes) {
      if (expires <= now) this.bootCodes.delete(code);
    }
  }
}

/**
 * Compares two strings in time independent of where they differ (no timing side channel on the
 * token).
 *
 * @param a - First string.
 * @param b - Second string.
 * @returns True when equal.
 */
function safeEqual(a: string, b: string): boolean {
  const left = Buffer.from(a, "utf8");
  const right = Buffer.from(b, "utf8");
  // timingSafeEqual needs equal lengths; comparing against itself keeps the time constant.
  if (left.length !== right.length) {
    timingSafeEqual(right, right);
    return false;
  }
  return timingSafeEqual(left, right);
}
