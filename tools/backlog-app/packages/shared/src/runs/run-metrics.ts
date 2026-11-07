// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The live figures of a run folded from its trace events (feature 415, research R3): tokens,
 * the price at list prices, the context in use, counts and the usage limits.
 *
 * Measured on the run of feature 414: one assistant message spans several lines with the same id
 * and the same `usage`; counted once per id, input, cache read and cache write add up exactly to
 * what claude reports at the end; the output count of a line is only the count when the message
 * started streaming. So per attempt (one claude process, whose `result` totals are cumulative):
 * the last result's totals and cost are taken as they are; what came after is counted from the
 * messages, the output estimated from the characters of text and tool input and multiplied by a
 * calibration factor (thinking is not visible in the stream), and priced at the model's list
 * prices. Every result replaces the estimate of its attempt. In the 414 run the first result came
 * after almost three hours - before it, today's page knew no cost at all.
 */

import type { LimitInfo, TokenUsage, TraceEvent } from "../schemas/runs.ts";
import { priceOf } from "./pricing.ts";

/** Characters per output token of the streamed text and tool input. */
const CHARS_PER_TOKEN = 3.6;

/** Output tokens per estimated token before a result calibrates it (measured on 414: 2.7). */
const DEFAULT_CALIBRATION = 2.7;

/** Tools that change files. */
const EDIT_TOOLS = new Set(["Edit", "Write", "MultiEdit", "NotebookEdit"]);

/** The figures of a run at one moment. */
export interface RunMetricsSnapshot {
  /** Tokens: input, output (partly estimated), cache read, cache write (both durations). */
  tokens: { input: number; output: number; cacheRead: number; cacheWrite: number };
  /** The price in USD at list prices, or null when nothing is known. */
  costUsd: number | null;
  /** `reported` (claude's own total), `estimate` (tokens since the last total priced), `none`. */
  costBasis: "reported" | "estimate" | "none";
  /** The part of the price that is claude's reported total. */
  reportedUsd: number;
  /** Models seen without a known price. */
  unpricedModels: string[];
  /** The main model (of the latest main-thread message). */
  model: string | null;
  /** Input plus cache tokens of the latest main-thread message (the context in use). */
  contextTokens: number | null;
  /** Tool calls (main thread and subagents). */
  toolCalls: number;
  /** Failed tool calls. */
  toolErrors: number;
  /** Agent calls of the main thread. */
  subagents: number;
  /** Files the run changed (Edit, Write, ...). */
  filesChanged: number;
  /** Distinct assistant messages. */
  messages: number;
  /** The latest usage-limit information. */
  limits: LimitInfo | null;
  /** Output calibration factor in use. */
  calibration: number;
}

/** Tokens and characters counted since the last result of an attempt, per model. */
interface Since {
  /** Exact parts (input, cache) and the streamed output count. */
  usage: TokenUsage;
  /** Characters of text and tool input. */
  chars: number;
}

/** The accounts of one attempt. */
interface AttemptAccount {
  /** The last result's cumulative cost, or null. */
  reportedUsd: number | null;
  /** The last result's cumulative tokens. */
  reported: TokenUsage | null;
  /** What came after it, per model. */
  since: Map<string, Since>;
  /** Raw estimated output tokens since the result before the last (for calibration). */
  estimatedSinceReport: number;
}

/**
 * An empty token count.
 *
 * @returns Zeros.
 */
function zero(): TokenUsage {
  return { input: 0, output: 0, cacheRead: 0, cacheWrite5m: 0, cacheWrite1h: 0 };
}

/** The live metrics fold of one run. */
export class RunMetrics {
  /** Accounts per attempt number. */
  private readonly attempts = new Map<number, AttemptAccount>();

  /** The attempt the following events belong to. */
  private attempt = 1;

  /** Message ids already counted. */
  private readonly seen = new Set<string>();

  /** Output calibration. */
  private calibration = DEFAULT_CALIBRATION;

  /** Files changed. */
  private readonly files = new Set<string>();

  /** Counters. */
  private counts = { toolCalls: 0, toolErrors: 0, subagents: 0 };

  /** The latest main-thread model and context. */
  private main: { model: string | null; context: number | null } = { model: null, context: null };

  /** The latest limits. */
  private limits: LimitInfo | null = null;

  /**
   * The account of the current attempt.
   *
   * @returns It (created on first use).
   */
  private account(): AttemptAccount {
    let account = this.attempts.get(this.attempt);
    if (!account) {
      account = { reportedUsd: null, reported: null, since: new Map(), estimatedSinceReport: 0 };
      this.attempts.set(this.attempt, account);
    }
    return account;
  }

  /**
   * Folds one event.
   *
   * @param event - A normalised trace event.
   */
  apply(event: TraceEvent): void {
    const info = event.info;
    switch (event.kind) {
      case "attempt": {
        const parsed = event.text ? (JSON.parse(event.text) as { attempt?: unknown }) : {};
        this.attempt = typeof parsed.attempt === "number" ? parsed.attempt : this.attempt + 1;
        return;
      }
      case "rate-limit":
        if (info?.limits) this.limits = info.limits;
        return;
      case "tool-result":
        if (event.isError) this.counts.toolErrors++;
        return;
      case "result": {
        if (info?.costUsd === undefined && !info?.totals) return;
        const account = this.account();
        // Calibrate the output estimate on what the result says was produced since the last one.
        if (info.totals && account.estimatedSinceReport > 500) {
          const grown = info.totals.output - (account.reported?.output ?? 0);
          if (grown > 0) {
            const factor = grown / account.estimatedSinceReport;
            this.calibration = Math.min(8, Math.max(1, factor));
          }
        }
        if (info.costUsd !== undefined) account.reportedUsd = info.costUsd;
        if (info.totals) account.reported = info.totals;
        account.since.clear();
        account.estimatedSinceReport = 0;
        return;
      }
      default:
        break;
    }
    if (event.kind === "tool-use") {
      this.counts.toolCalls++;
      if (event.parentToolUseId === null && (event.name === "Agent" || event.name === "Task"))
        this.counts.subagents++;
      if (event.name && EDIT_TOOLS.has(event.name) && info?.filePath) this.files.add(info.filePath);
    }
    if (!info?.messageId && !info?.usage && info?.outputChars === undefined) return;
    // The facts of an assistant line (on its first event only).
    const model = info.model ?? "unknown";
    const account = this.account();
    let since = account.since.get(model);
    if (!since) {
      since = { usage: zero(), chars: 0 };
      account.since.set(model, since);
    }
    const chars = info.outputChars ?? 0;
    since.chars += chars;
    account.estimatedSinceReport += chars / CHARS_PER_TOKEN;
    const fresh = info.messageId ? !this.seen.has(info.messageId) : true;
    if (info.messageId) this.seen.add(info.messageId);
    if (fresh && info.usage) {
      since.usage.input += info.usage.input;
      since.usage.output += info.usage.output;
      since.usage.cacheRead += info.usage.cacheRead;
      since.usage.cacheWrite5m += info.usage.cacheWrite5m;
      since.usage.cacheWrite1h += info.usage.cacheWrite1h;
      if (event.parentToolUseId === null) {
        this.main = {
          model: info.model ?? this.main.model,
          context:
            info.usage.input + info.usage.cacheRead + info.usage.cacheWrite5m + info.usage.cacheWrite1h,
        };
      }
    }
  }

  /**
   * The figures now.
   *
   * @returns The snapshot.
   */
  snapshot(): RunMetricsSnapshot {
    const tokens = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };
    let reportedUsd = 0;
    let estimatedUsd = 0;
    let anyReported = false;
    let anySince = false;
    const unpriced = new Set<string>();
    for (const account of this.attempts.values()) {
      if (account.reported) {
        tokens.input += account.reported.input;
        tokens.output += account.reported.output;
        tokens.cacheRead += account.reported.cacheRead;
        tokens.cacheWrite += account.reported.cacheWrite5m + account.reported.cacheWrite1h;
      }
      if (account.reportedUsd !== null) {
        reportedUsd += account.reportedUsd;
        anyReported = true;
      }
      for (const [model, since] of account.since) {
        const output = Math.max(since.usage.output, (since.chars / CHARS_PER_TOKEN) * this.calibration);
        const usage: TokenUsage = { ...since.usage, output: Math.round(output) };
        tokens.input += usage.input;
        tokens.output += usage.output;
        tokens.cacheRead += usage.cacheRead;
        tokens.cacheWrite += usage.cacheWrite5m + usage.cacheWrite1h;
        if (usage.input + usage.output + usage.cacheRead + usage.cacheWrite5m + usage.cacheWrite1h === 0)
          continue;
        anySince = true;
        const price = priceOf(model, usage);
        if (price === null) unpriced.add(model);
        else estimatedUsd += price;
      }
    }
    const known = anyReported || (anySince && estimatedUsd > 0);
    return {
      tokens,
      costUsd: known ? reportedUsd + estimatedUsd : null,
      costBasis: anySince && estimatedUsd > 0 ? "estimate" : anyReported ? "reported" : "none",
      reportedUsd,
      unpricedModels: [...unpriced],
      model: this.main.model,
      contextTokens: this.main.context,
      toolCalls: this.counts.toolCalls,
      toolErrors: this.counts.toolErrors,
      subagents: this.counts.subagents,
      filesChanged: this.files.size,
      messages: this.seen.size,
      limits: this.limits,
      calibration: Math.round(this.calibration * 100) / 100,
    };
  }
}
