// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The list prices of the Claude models (feature 415, research R3): what the tokens of a run
 * cost at the Claude API's list prices, in US dollars per million tokens. Prices of the
 * `claude-api` skill (cached 2026-10-06); a cache write lasting 5 minutes costs 1.25 times the
 * input price, one lasting an hour twice the input price. The table reproduces the cost claude
 * itself reports (fix-log of 415: $33.899 against $33.895).
 */

import type { TokenUsage } from "../schemas/runs.ts";

/** The prices of one model, in USD per million tokens. */
export interface ModelPrice {
  /** Uncached input. */
  input: number;
  /** Output. */
  output: number;
  /** Cache read. */
  cacheRead: number;
}

/**
 * Prices by model id prefix, most specific first (a dated suffix or `[1m]` still matches).
 * Only models the table knows are priced; anything else stays unpriced rather than guessed.
 */
export const MODEL_PRICES: readonly (readonly [string, ModelPrice])[] = [
  ["claude-fable-5-1", { input: 10, output: 50, cacheRead: 0.25 }],
  ["claude-mythos-5-1", { input: 10, output: 50, cacheRead: 0.25 }],
  ["claude-fable-5", { input: 10, output: 50, cacheRead: 1 }],
  ["claude-mythos-5", { input: 10, output: 50, cacheRead: 1 }],
  ["claude-opus-5-5", { input: 4, output: 20, cacheRead: 0.2 }],
  ["claude-opus-5", { input: 5, output: 25, cacheRead: 0.5 }],
  ["claude-opus-4-8", { input: 5, output: 25, cacheRead: 0.5 }],
  ["claude-opus-4-7", { input: 5, output: 25, cacheRead: 0.5 }],
  ["claude-opus-4-6", { input: 5, output: 25, cacheRead: 0.5 }],
  ["claude-sonnet-5-5", { input: 2, output: 10, cacheRead: 0.2 }],
  ["claude-sonnet-5", { input: 2, output: 10, cacheRead: 0.2 }],
  ["claude-sonnet-4-6", { input: 3, output: 15, cacheRead: 0.3 }],
  ["claude-haiku-5-5", { input: 0.1, output: 0.5, cacheRead: 0.01 }],
  ["claude-haiku-4-5", { input: 1, output: 5, cacheRead: 0.1 }],
];

/**
 * The prices of a model.
 *
 * @param model - A model id as claude reports it.
 * @returns The prices, or null for a model the table does not know.
 */
export function priceTable(model: string | null | undefined): ModelPrice | null {
  if (!model) return null;
  const id = model.toLowerCase().replace(/^(anthropic\.|us\.anthropic\.)/, "");
  for (const [prefix, price] of MODEL_PRICES) {
    if (
      id === prefix ||
      id.startsWith(`${prefix}-`) ||
      id.startsWith(`${prefix}[`) ||
      id.startsWith(`${prefix}@`)
    )
      return price;
  }
  return null;
}

/**
 * The cost of tokens at a model's list prices.
 *
 * @param model - The model id.
 * @param usage - The tokens.
 * @returns US dollars, or null for an unknown model.
 */
export function priceOf(model: string | null | undefined, usage: TokenUsage): number | null {
  const price = priceTable(model);
  if (!price) return null;
  return (
    (usage.input * price.input +
      usage.output * price.output +
      usage.cacheRead * price.cacheRead +
      usage.cacheWrite5m * price.input * 1.25 +
      usage.cacheWrite1h * price.input * 2) /
    1_000_000
  );
}
