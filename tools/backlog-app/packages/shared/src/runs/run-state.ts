// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The state of a run folded from its trace: phase, phase timeline, attempts, the tool call in
 * flight, recent messages, a running GUI probe and the cost (research R14, R15; analysis A2 §1.3,
 * §1.4).
 *
 * The phase is a monotonic state machine driven by markers of the main thread (events of
 * subagents, which carry a `parent_tool_use_id`, never move it):
 * - the backlog commands the implementation skill prescribes: `lock acquire` (selection), `verify`
 *   (measure), `start` (the item is started - specify), `run-log` (close), `block` (the stop path),
 *   `lock release` (done), and `git merge` (merge);
 * - the Spec Kit skills (`speckit-specify` ... `speckit-implement`);
 * - builds, `saltests` and GUI probes after implement (verify), and `Agent` calls after implement
 *   (review).
 * A phase never moves back: after a continued attempt the last phase holds until a new marker.
 * The cost of a run is the sum over its attempts of each attempt's last `result` (a `result` ends
 * every turn, several per attempt; the last one carries the attempt's totals).
 */

import type { Attempt, CurrentToolSchema, Phase, TraceEvent } from "../schemas/runs.ts";
import type { z } from "zod";

/** The implementation phases in order (the stop path and triage are outside the order). */
export const PHASE_ORDER: readonly Phase[] = [
  "starting",
  "selection",
  "measure",
  "specify",
  "clarify",
  "plan",
  "tasks",
  "analyze",
  "implement",
  "verify",
  "review",
  "close",
  "merge",
  "done",
];

/** Spec Kit skills and the phase each starts. */
const SKILL_PHASE: Record<string, Phase> = {
  "speckit-specify": "specify",
  "speckit-clarify": "clarify",
  "speckit-plan": "plan",
  "speckit-tasks": "tasks",
  "speckit-analyze": "analyze",
  "speckit-implement": "implement",
};

/** Shell command markers and the phase each starts (checked in this order). */
const COMMAND_MARKERS: { pattern: RegExp; phase: Phase }[] = [
  { pattern: /backlog(\.sh|\.py)?\b.*\block\s+release\b/, phase: "done" },
  { pattern: /backlog(\.sh|\.py)?\b.*\block\s+acquire\b/, phase: "selection" },
  { pattern: /backlog(\.sh|\.py)?\b.*\brun-log\b/, phase: "close" },
  { pattern: /backlog(\.sh|\.py)?\b.*\bverify\b/, phase: "measure" },
  { pattern: /backlog(\.sh|\.py)?\b.*\bstart\b.*--feature/, phase: "specify" },
  { pattern: /\bgit\s+merge\b/, phase: "merge" },
];

/** A blocked item ends the run on the stop path. */
const BLOCK_MARKER = /backlog(\.sh|\.py)?\b.*\bblock\s+[a-z0-9-]+/;

/** Build and test commands of the verification step. */
const VERIFY_MARKER = /\b(build\.cmd|rebuild\.cmd|saltests(\.exe)?)\b/;

/** A GUI probe on the hidden desktop. */
const PROBE_MARKER = /run_on_hidden_desktop\.ps1/;

/** The figures of one attempt's last `result`. */
interface AttemptCost {
  /** Total cost in US dollars. */
  usd: number;
}

/** The folded state of one run. */
export class RunState {
  /** `item` or `triage`. */
  readonly kind: "item" | "triage";

  /** The current phase. */
  phase: Phase;

  /** When each phase was first seen. */
  readonly timeline: { phase: Phase; at: string | null }[] = [];

  /** The attempts seen (from separator lines). */
  readonly attempts: Attempt[] = [];

  /** Main-thread tool calls without a result yet, by tool-use id. */
  private readonly open = new Map<string, z.infer<typeof CurrentToolSchema>>();

  /** The last main-thread assistant texts, oldest first. */
  readonly recentMessages: string[] = [];

  /** Last `result` per attempt number. */
  private readonly costs = new Map<number, AttemptCost>();

  /** The attempt the following events belong to. */
  private attemptNumber = 1;

  /** Number of tool calls seen (main thread and subagents). */
  toolCalls = 0;

  /** Number of failed tool calls. */
  toolErrors = 0;

  /** The offset after the last folded line. */
  offset = 0;

  /**
   * Creates an empty state.
   *
   * @param kind - `item` or `triage`.
   */
  constructor(kind: "item" | "triage") {
    this.kind = kind;
    this.phase = kind === "triage" ? "triage" : "starting";
    this.timeline.push({ phase: this.phase, at: null });
  }

  /**
   * Moves the phase forward (never back; the stop path and `done` are final).
   *
   * @param next - The phase a marker indicates.
   * @param at - When.
   */
  private advance(next: Phase, at: string | null): void {
    if (this.phase === "stopped" || this.phase === "done") return;
    if (this.kind === "triage") {
      if (next === "done") {
        this.phase = "done";
        this.timeline.push({ phase: "done", at });
      }
      return;
    }
    if (next !== "stopped" && PHASE_ORDER.indexOf(next) <= PHASE_ORDER.indexOf(this.phase)) return;
    this.phase = next;
    this.timeline.push({ phase: next, at });
  }

  /**
   * Folds one event into the state.
   *
   * @param event - A normalised trace event.
   */
  apply(event: TraceEvent): void {
    this.offset = Math.max(this.offset, event.end);
    switch (event.kind) {
      case "attempt": {
        const info = event.text
          ? (JSON.parse(event.text) as { attempt?: number; kind?: string; reason?: string })
          : {};
        const previous = this.attempts.at(-1);
        if (previous && previous.ended === null) {
          previous.ended = event.at;
          previous.ending = "interrupted";
        }
        this.attemptNumber = info.attempt ?? this.attempts.length + 1;
        this.attempts.push({
          n: this.attemptNumber,
          kind: info.kind ?? "start",
          reason: info.reason ?? "-",
          started: event.at,
          ended: null,
          ending: null,
        });
        // A new attempt starts a new process: nothing is in flight any more.
        this.open.clear();
        return;
      }
      case "tool-use": {
        this.toolCalls++;
        if (event.parentToolUseId !== null) return;
        if (event.toolUseId)
          this.open.set(event.toolUseId, {
            name: event.name ?? "?",
            summary: event.summary,
            since: event.at,
          });
        this.markers(event);
        return;
      }
      case "tool-result": {
        if (event.isError) this.toolErrors++;
        if (event.toolUseId) this.open.delete(event.toolUseId);
        return;
      }
      case "assistant-text": {
        if (event.parentToolUseId !== null) return;
        this.recentMessages.push(event.text ?? event.summary);
        if (this.recentMessages.length > 5) this.recentMessages.shift();
        return;
      }
      case "result": {
        const cost = event.summary.match(/\$(\d+(?:\.\d+)?)/);
        if (cost) this.costs.set(this.attemptNumber, { usd: Number(cost[1]) });
        const attempt = this.attempts.at(-1);
        if (attempt) attempt.ending = event.isError ? "error" : "result";
        return;
      }
      default:
        return;
    }
  }

  /**
   * Applies the phase markers of a main-thread tool call.
   *
   * @param event - The tool-use event.
   */
  private markers(event: TraceEvent): void {
    const name = event.name ?? "";
    const summary = event.summary;
    if (name === "Skill") {
      const skill = summary.trim().split(/\s+/)[0] ?? "";
      const phase = SKILL_PHASE[skill];
      if (phase) this.advance(phase, event.at);
      return;
    }
    if (name === "Agent" || name === "Task") {
      if (PHASE_ORDER.indexOf(this.phase) >= PHASE_ORDER.indexOf("implement"))
        this.advance("review", event.at);
      return;
    }
    if (name === "Bash" || name === "PowerShell") {
      if (BLOCK_MARKER.test(summary) && !/\bunblock\b/.test(summary)) {
        this.advance("stopped", event.at);
        return;
      }
      for (const marker of COMMAND_MARKERS) {
        if (marker.pattern.test(summary)) {
          this.advance(marker.phase, event.at);
          return;
        }
      }
      if (
        (VERIFY_MARKER.test(summary) || PROBE_MARKER.test(summary)) &&
        PHASE_ORDER.indexOf(this.phase) >= PHASE_ORDER.indexOf("implement")
      ) {
        this.advance("verify", event.at);
      }
    }
  }

  /**
   * The main-thread tool call in flight (the most recent one).
   *
   * @returns The call, or null.
   */
  currentTool(): z.infer<typeof CurrentToolSchema> | null {
    let last: z.infer<typeof CurrentToolSchema> | null = null;
    for (const call of this.open.values()) last = call;
    return last;
  }

  /**
   * Whether a GUI probe is running now (warn before a hard stop: its registry backup must be
   * restored, stop-rules 2.8).
   *
   * @returns True while a probe call is in flight.
   */
  guiProbeRunning(): boolean {
    for (const call of this.open.values()) if (PROBE_MARKER.test(call.summary)) return true;
    return false;
  }

  /**
   * The cost of the run so far: the sum of each attempt's last result.
   *
   * @returns US dollars, or null when no result was seen.
   */
  costUsd(): number | null {
    if (this.costs.size === 0) return null;
    let total = 0;
    for (const cost of this.costs.values()) total += cost.usd;
    return Math.round(total * 100) / 100;
  }
}
