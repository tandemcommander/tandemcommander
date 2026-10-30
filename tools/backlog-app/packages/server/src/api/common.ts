// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Helpers every route module uses: body validation against the shared schemas, and the
 * conversion of errors into the API's error answers (contracts/http-api.md, *Conventions*).
 */

import type { Context } from "hono";
import { z, type ZodType } from "zod";
import { ApiError, ERROR_STATUS, type ErrorCode } from "@backlog-app/shared";

/**
 * Reads and validates a JSON request body.
 *
 * @param c - The request context.
 * @param schema - The schema of the body.
 * @returns The validated body.
 * @throws ApiError `invalid-request` with the validation issues.
 */
export async function readBody<T>(c: Context, schema: ZodType<T>): Promise<T> {
  let raw: unknown;
  try {
    raw = await c.req.json();
  } catch {
    throw new ApiError("invalid-request", "the body is not valid JSON");
  }
  const parsed = schema.safeParse(raw);
  if (!parsed.success) {
    throw new ApiError(
      "invalid-request",
      "the request does not match its schema",
      z.treeifyError(parsed.error),
    );
  }
  return parsed.data;
}

/**
 * Converts any error into an error answer. API errors keep their code; anything else is an
 * internal error whose message is shown (the user is the maintainer of this machine, so hiding
 * details would only hinder).
 *
 * @param error - The error thrown by a route.
 * @param c - The request context.
 * @returns The JSON error answer.
 */
export function errorAnswer(error: unknown, c: Context): Response {
  if (error instanceof ApiError) {
    return c.json(
      {
        error: {
          code: error.code,
          message: error.message,
          ...(error.detail === undefined ? {} : { detail: error.detail }),
        },
      },
      error.status as 400,
    );
  }
  const message = error instanceof Error ? error.message : String(error);
  return c.json({ error: { code: "internal", message } }, 500);
}

/**
 * The HTTP status of an error code.
 *
 * @param code - The code.
 * @returns The status.
 */
export function statusOf(code: ErrorCode): number {
  return ERROR_STATUS[code];
}

/**
 * Validates a path parameter against a pattern (contracts/security.md, rule 7).
 *
 * @param value - The parameter.
 * @param pattern - The allowed form.
 * @param what - Name for the error message.
 * @returns The value.
 * @throws ApiError `not-found` when it does not match.
 */
export function param(value: string | undefined, pattern: RegExp, what: string): string {
  if (value === undefined || !pattern.test(value)) throw new ApiError("not-found", `no such ${what}`);
  return value;
}

/** Form of a slug in a path. */
export const SLUG_PATTERN = /^[a-z0-9]+(-[a-z0-9]+)*$/;
