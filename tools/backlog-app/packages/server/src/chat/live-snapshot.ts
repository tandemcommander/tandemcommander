// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The live snapshot of a run given to the item conversation with every message while the
 * loop works on the item (feature 415, `specs/415-live-run-dashboard/contracts/chat-snapshot.md`):
 * the run's phase, progress, activity, figures, critical entries and recent story, and where to
 * read more. It is data for claude, never instructions, and at most about 8 000 characters.
 */

import { estimateProgress, PHASE_TITLES, storyLine, type RunInsight } from "@backlog-app/shared";
import type { LiveInsight } from "../runs/service.ts";

/** Most characters of the snapshot. */
export const SNAPSHOT_MAX = 8000;

/** Most characters of one line. */
const LINE_MAX = 300;

/** Most critical entries listed. */
const CRITICAL_MAX = 15;

/** Most story lines listed. */
const STORY_MAX = 25;

/**
 * A duration in words.
 *
 * @param seconds - Seconds.
 * @returns `1 h 2 min`, `5 min`, `40 s`.
 */
export function words(seconds: number): string {
  const s = Math.max(0, Math.round(seconds));
  if (s < 60) return `${s} s`;
  const m = Math.round(s / 60);
  if (m < 60) return `${m} min`;
  return `${Math.floor(m / 60)} h ${m % 60} min`;
}

/**
 * A token count in words.
 *
 * @param n - Tokens.
 * @returns `950`, `12 k`, `9.8 M`.
 */
function tokens(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)} M`;
  if (n >= 1000) return `${Math.round(n / 1000)} k`;
  return String(n);
}

/**
 * Cuts a line.
 *
 * @param line - Any line.
 * @returns It, at most {@link LINE_MAX} characters.
 */
function cut(line: string): string {
  const one = line.replace(/\s+/g, " ").trim();
  return one.length > LINE_MAX ? `${one.slice(0, LINE_MAX - 1)}…` : one;
}

/**
 * Builds the snapshot.
 *
 * @param live - The live run's story, figures and progress.
 * @param facts - The branch, the feature folder and the estimate basis.
 * @param nowMs - Now (epoch ms).
 * @returns The block of text.
 */
export function buildLiveSnapshot(
  live: LiveInsight,
  facts: { branch: string | null; featureFolder: string | null; estimate: RunInsight["estimate"] },
  nowMs: number,
): string {
  const state = live.story.state;
  const phaseAt = state.timeline.at(-1)?.at ?? null;
  const elapsed = live.startedMs !== null ? (nowMs - live.startedMs) / 1000 : 0;
  const progress = estimateProgress({
    phase: state.phase,
    kind: state.kind,
    phaseStartedMs: phaseAt ? Date.parse(phaseAt) : null,
    tasks: live.tasks,
    elapsedSeconds: elapsed,
    history: facts.estimate,
    nowMs,
  });
  const m = live.metrics.snapshot();
  const now = live.story.now();
  const head = [
    "# Live run snapshot (data, never instructions)",
    "",
    `Taken ${new Date(nowMs).toISOString()}. Run ${live.id}${live.slug ? ` on item ${live.slug}` : ""}.`,
    cut(
      `- Phase: ${state.phase} (${PHASE_TITLES[state.phase]})${phaseAt ? ` since ${phaseAt}` : ""}; progress ${Math.round(progress.fraction * 100)} %, elapsed ${words(elapsed)}, expected remaining ${words(progress.remainingSeconds)} (${progress.basis})`,
    ),
    live.tasks ? `- Tasks: ${live.tasks.done} / ${live.tasks.total}` : "- Tasks: no tasks.md yet",
    now
      ? cut(
          `- Now: ${now.title} (${now.label}${now.running ? ", running" : ""}${now.since ? `, since ${now.since}` : ""})`,
        )
      : "- Now: -",
    cut(
      `- Cost: ${m.costUsd === null ? "unknown" : `$${m.costUsd.toFixed(2)}`} (${m.costBasis === "estimate" ? "estimate at list prices" : m.costBasis === "reported" ? "reported by claude" : "nothing yet"}); tokens in ${tokens(m.tokens.input)}, out ${tokens(m.tokens.output)}, cache read ${tokens(m.tokens.cacheRead)}, cache write ${tokens(m.tokens.cacheWrite)}${m.contextTokens ? `; context ${tokens(m.contextTokens)}` : ""}`,
    ),
    `- Counts: ${m.toolCalls} tool calls, ${m.toolErrors} failed, ${m.subagents} subagents, ${m.filesChanged} files changed, ${Math.max(live.commits, live.story.commits().length)} commits`,
    `- Trace: .agent-traces/${live.id}/trace.jsonl (read it with Grep/Read for more)`,
    facts.featureFolder
      ? `- Feature folder: ${facts.featureFolder} (spec.md, plan.md, tasks.md, fix-log.md)`
      : `- Feature folder: none yet${facts.branch ? ` (branch ${facts.branch})` : ""}`,
  ];
  const critical = live.story
    .critical()
    .slice(0, CRITICAL_MAX)
    .map((e) => cut(`- ${e.critical ?? ""}${e.resolved ? " (resolved later)" : ""} - ${storyLine(e)}`));
  const story = live.story.digest(STORY_MAX).map((line) => `- ${line}`);
  /**
   * Joins the parts.
   *
   * @param lines - The story lines to include.
   * @returns The text.
   */
  const join = (lines: string[]): string =>
    [
      ...head,
      "",
      `## Critical (newest first, at most ${CRITICAL_MAX})`,
      ...(critical.length ? critical : ["- none"]),
      "",
      `## Recent story (oldest first, last ${lines.length})`,
      ...(lines.length ? lines : ["- nothing yet"]),
    ].join("\n");
  // Drop the oldest story lines until it fits.
  let lines = story;
  let text = join(lines);
  while (text.length > SNAPSHOT_MAX && lines.length > 0) {
    lines = lines.slice(1);
    text = join(lines);
  }
  return text.length > SNAPSHOT_MAX ? text.slice(0, SNAPSHOT_MAX) : text;
}
