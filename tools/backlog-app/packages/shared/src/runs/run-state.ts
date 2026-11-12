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
import { programsOf } from "./command-parse.ts";
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

/**
 * The later of two phases of one run (feature 426: the live page never shows a phase earlier than
 * the server's fold). The stop path wins (it is final); a phase outside the order (triage) loses
 * to one in it; of two such phases the first is kept.
 *
 * @param a - One phase (e.g. the page's own fold).
 * @param b - The other (e.g. the server's), or null.
 * @returns The later one.
 */
export function laterPhase(a: Phase, b: Phase | null | undefined): Phase {
  if (b === null || b === undefined || a === b) return a;
  if (a === "stopped" || b === "stopped") return "stopped";
  return PHASE_ORDER.indexOf(b) > PHASE_ORDER.indexOf(a) ? b : a;
}

/** Spec Kit skills and the phase each starts. */
const SKILL_PHASE: Record<string, Phase> = {
  "speckit-specify": "specify",
  "speckit-clarify": "clarify",
  "speckit-plan": "plan",
  "speckit-tasks": "tasks",
  "speckit-analyze": "analyze",
  "speckit-implement": "implement",
};

/**
 * Programs and backlog subcommands that start a phase (checked in this order; feature 415 review
 * 4: by what a command runs, never by its text - a note saying "block" or a `git merge-base`
 * moves no phase).
 */
const COMMAND_MARKERS: { program: string; phase: Phase }[] = [
  { program: "backlog lock release", phase: "done" },
  { program: "backlog lock acquire", phase: "selection" },
  { program: "backlog run-log", phase: "close" },
  { program: "backlog verify", phase: "measure" },
  { program: "backlog start", phase: "specify" },
  { program: "git merge", phase: "merge" },
];

/** Programs of the verification step (builds and saltests). */
const VERIFY_PROGRAMS = ["build.cmd", "rebuild.cmd", "saltests.exe"];

/** A GUI probe on the hidden desktop. */
const PROBE_MARKER = /run_on_hidden_desktop\.ps1/;

/**
 * Parses JSON, or gives an empty object for text that is not (an event text cut short).
 *
 * @param text - The text.
 * @returns The value, or `{}`.
 */
export function safeParse(text: string): unknown {
  try {
    return JSON.parse(text) as unknown;
  } catch {
    return {};
  }
}

/** First folders of the repository that hold no source: records, the backlog, build output. */
const NOT_SOURCE = new Set([
  "specs",
  "backlog",
  "build",
  "out",
  "dist",
  "node_modules",
  "test-results",
  ".agent-traces",
  ".specify",
  ".claude",
  ".git",
]);

/**
 * Whether a path is a source of the product or its tools (review 3 of 415): inside the session's
 * repository (when its root is known), not under the feature's records, the backlog, the build
 * output or the traces, and not a temporary file. A scratch probe script written into `build\`
 * or next to the repository is no source change.
 *
 * @param path - A file path, or null.
 * @param root - The repository root (the session's working directory), when known.
 * @returns True for a source file.
 */
export function isSourcePath(path: string | null, root: string | null = null): boolean {
  if (!path) return false;
  const p = path.replace(/\\/g, "/");
  let rel: string;
  if (root) {
    // Inside the repository its own folders decide (also for a repository in %TEMP%, as the
    // tests' fixtures are); outside it nothing is a source.
    const r = root.replace(/\\/g, "/").replace(/\/+$/, "");
    if (!p.toLowerCase().startsWith(`${r.toLowerCase()}/`))
      return /^[^/:]+\//.test(p) && !/^\.\.\//.test(p) ? isSourcePath(`${r}/${p}`, root) : false;
    rel = p.slice(r.length + 1);
  } else {
    if (/\/AppData\/Local\/Temp\//i.test(p)) return false;
    rel = p;
  }
  const parts = rel.split("/").filter(Boolean);
  if (parts.some((part) => part.toLowerCase() === "node_modules")) return false;
  if (root) return parts.length > 0 && !NOT_SOURCE.has(parts[0]!.toLowerCase());
  return !parts.some((part) => NOT_SOURCE.has(part.toLowerCase()));
}

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

  /** The repository root of the session (`system/init`), when known. */
  private root: string | null = null;

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
    // A triage has no Spec Kit phases: it is "triage" until the lock is released.
    if (this.kind === "triage") {
      if (next === "done") {
        this.phase = "done";
        this.timeline.push({ phase: "done", at });
      }
      return;
    }
    // Forward only: a run that re-runs a skill or verifies again must not make the view jump
    // back. The stop path may be taken from any phase.
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
    if (event.kind === "init" && event.info?.cwd) this.root = event.info.cwd;
    switch (event.kind) {
      case "attempt": {
        const info = event.text
          ? (safeParse(event.text) as { attempt?: number; kind?: string; reason?: string })
          : {};
        // An attempt still open when the next separator comes was cut off (killed, crashed, usage
        // limit): it ends where the next one starts.
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
        // Subagents' calls count, but only the main thread decides the phase and the current
        // tool: a review agent's `git merge` in an explanation must not move the run to "merge".
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
        // The cost in a result is cumulative within one claude process, so the last result of
        // each attempt is that attempt's cost; the run's cost is the sum (costUsd).
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
    // Phases are recognised from what the run does, never from what it says: a Spec Kit skill
    // call, a backlog tool command (lock, start, verify, run-log, block), a merge, a build, a probe.
    if (name === "Skill") {
      const skill = summary.trim().split(/\s+/)[0] ?? "";
      const phase = SKILL_PHASE[skill];
      if (phase) this.advance(phase, event.at);
      return;
    }
    // A run that implements without calling the implement skill (feature 415, review S-B):
    // its first change of a source file after the tasks are written starts implement.
    if (
      (name === "Edit" || name === "Write" || name === "MultiEdit" || name === "NotebookEdit") &&
      (this.phase === "tasks" || this.phase === "analyze") &&
      isSourcePath(event.info?.filePath ?? null, this.root)
    ) {
      this.advance("implement", event.at);
      return;
    }
    if (name === "Agent" || name === "Task") {
      if (PHASE_ORDER.indexOf(this.phase) >= PHASE_ORDER.indexOf("implement"))
        this.advance("review", event.at);
      return;
    }
    if (name === "Bash" || name === "PowerShell") {
      const programs = programsOf(event.info?.command ?? summary);
      // `block` ends the run on the stop path; `unblock` (of a dependent item) does not.
      if (programs.includes("backlog block")) {
        this.advance("stopped", event.at);
        return;
      }
      for (const marker of COMMAND_MARKERS) {
        if (programs.includes(marker.program)) {
          this.advance(marker.phase, event.at);
          return;
        }
      }
      if (
        (programs.some((p) => VERIFY_PROGRAMS.includes(p)) ||
          programs.includes("run_on_hidden_desktop.ps1")) &&
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
