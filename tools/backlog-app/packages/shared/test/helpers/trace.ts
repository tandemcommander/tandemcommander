// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Builders of trace lines shaped like a real run's `trace.jsonl` (claude's `stream-json`
 * plus the loop's attempt separators), for the tests of feature 415.
 */

import { normalizeTraceLine } from "../../src/runs/trace-event.ts";
import type { TraceEvent } from "../../src/schemas/runs.ts";

/** A usage object as an assistant line carries it. */
export interface RawUsage {
  /** Input tokens. */
  input_tokens?: number;
  /** Output tokens at the start of the message. */
  output_tokens?: number;
  /** Cache read. */
  cache_read_input_tokens?: number;
  /** Cache write. */
  cache_creation_input_tokens?: number;
  /** The split of the cache write. */
  cache_creation?: { ephemeral_5m_input_tokens: number; ephemeral_1h_input_tokens: number };
}

/**
 * Normalises lines into events with byte offsets, each stamped one second after the previous.
 *
 * @param lines - Objects or raw strings.
 * @returns The events.
 */
export function eventsOf(lines: (object | string)[]): TraceEvent[] {
  let offset = 0;
  let second = 0;
  const events: TraceEvent[] = [];
  for (const line of lines) {
    const text = typeof line === "string" ? line : JSON.stringify(line);
    const end = offset + Buffer.byteLength(text) + 1;
    const at = new Date(Date.UTC(2026, 10, 7, 10, 0, second++)).toISOString();
    events.push(...normalizeTraceLine(text, offset, end, at));
    offset = end;
  }
  return events;
}

/**
 * An assistant line with one tool call.
 *
 * @param id - Tool-use id.
 * @param name - Tool.
 * @param input - Its input.
 * @param options - Parent (subagent), message id, model, usage.
 * @returns The line.
 */
export function call(
  id: string,
  name: string,
  input: object,
  options: { parent?: string | null; message?: string; model?: string; usage?: RawUsage } = {},
): object {
  return {
    type: "assistant",
    message: {
      id: options.message ?? `msg-${id}`,
      model: options.model ?? "claude-opus-5-5",
      content: [{ type: "tool_use", id, name, input }],
      usage: options.usage ?? { input_tokens: 2, output_tokens: 8, cache_read_input_tokens: 1000 },
    },
    parent_tool_use_id: options.parent ?? null,
  };
}

/**
 * The result of a tool call.
 *
 * @param id - Tool-use id.
 * @param text - Its text.
 * @param isError - A failure.
 * @param parent - Parent tool-use id (subagents).
 * @returns The line.
 */
export function result(id: string, text: string, isError = false, parent: string | null = null): object {
  return {
    type: "user",
    message: {
      role: "user",
      content: [{ type: "tool_result", tool_use_id: id, content: text, is_error: isError }],
    },
    parent_tool_use_id: parent,
  };
}

/**
 * An assistant text.
 *
 * @param text - The text.
 * @param options - Parent, message id, usage.
 * @returns The line.
 */
export function say(
  text: string,
  options: { parent?: string | null; message?: string; usage?: RawUsage } = {},
): object {
  return {
    type: "assistant",
    message: {
      id: options.message ?? `msg-${text.slice(0, 12)}`,
      model: "claude-opus-5-5",
      content: [{ type: "text", text }],
      usage: options.usage ?? { input_tokens: 1, output_tokens: 4, cache_read_input_tokens: 500 },
    },
    parent_tool_use_id: options.parent ?? null,
  };
}

/**
 * A `result` line ending a turn.
 *
 * @param cost - The cumulative cost.
 * @param totals - The cumulative tokens of the process.
 * @param isError - An error result.
 * @returns The line.
 */
export function turnEnd(
  cost: number,
  totals: { input: number; output: number; read: number; w5: number; w1: number },
  isError = false,
): object {
  return {
    type: "result",
    subtype: isError ? "error_during_execution" : "success",
    is_error: isError,
    total_cost_usd: cost,
    modelUsage: {
      "claude-opus-5-5": {
        inputTokens: totals.input,
        outputTokens: totals.output,
        cacheReadInputTokens: totals.read,
        cacheCreationInputTokens: totals.w5 + totals.w1,
        cacheCreationEphemeral5mInputTokens: totals.w5,
        cacheCreationEphemeral1hInputTokens: totals.w1,
      },
    },
  };
}

/**
 * The loop's attempt separator.
 *
 * @param n - Attempt number.
 * @param reason - Why it started.
 * @returns The line.
 */
export function attempt(n: number, reason = "-"): object {
  return {
    type: "backlog_loop.attempt",
    attempt: n,
    kind: n === 1 ? "start" : "continue",
    reason,
    started: `2026-11-07T1${n}:00:00+01:00`,
  };
}
