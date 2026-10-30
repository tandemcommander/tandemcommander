// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Error codes of the HTTP API and the shape of an error answer (contracts/http-api.md,
 * *Conventions*).
 *
 * Two answers of the backlog tool must never be confused (analysis A1 §3): a *refused* change
 * wrote nothing (`422 refused`), while a change *written with check findings* succeeded and is a
 * `200` with findings - the client shows a warning and never offers a retry (FR-036).
 */

import { z } from "zod";

/** Every error code with its HTTP status. */
export const ERROR_STATUS = {
  "invalid-request": 400,
  unauthorized: 401,
  "forbidden-origin": 403,
  "not-found": 404,
  "changed-underneath": 409,
  "gate-closed": 409,
  busy: 409,
  "too-large": 413,
  "unsupported-media-type": 415,
  misdirected: 421,
  refused: 422,
  "tool-failed": 500,
  internal: 500,
} as const;

/** An error code of the API. */
export type ErrorCode = keyof typeof ERROR_STATUS;

/** The body of every error answer. */
export const ErrorBodySchema = z.object({
  /** The error. */
  error: z.object({
    /** One of {@link ERROR_STATUS}'s keys. */
    code: z.string(),
    /** Text for the maintainer; for `refused` the tool's text verbatim. */
    message: z.string(),
    /** Extra data: validation issues, the new revisions, the gate, stderr. */
    detail: z.unknown().optional(),
  }),
});

/** The body of an error answer. */
export type ErrorBody = z.infer<typeof ErrorBodySchema>;

/**
 * An error the server raises inside a request; the HTTP layer turns it into an error answer with
 * the code's status.
 */
export class ApiError extends Error {
  /** The API error code. */
  readonly code: ErrorCode;

  /** Extra data for the client. */
  readonly detail: unknown;

  /**
   * Creates an API error.
   *
   * @param code - The error code; decides the HTTP status.
   * @param message - Text for the maintainer.
   * @param detail - Optional extra data for the client.
   */
  constructor(code: ErrorCode, message: string, detail?: unknown) {
    super(message);
    this.name = "ApiError";
    this.code = code;
    this.detail = detail;
  }

  /**
   * The HTTP status of this error.
   *
   * @returns The status code from {@link ERROR_STATUS}.
   */
  get status(): number {
    return ERROR_STATUS[this.code];
  }
}
