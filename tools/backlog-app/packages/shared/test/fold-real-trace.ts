// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Folds a real `trace.jsonl` into the story and the metrics of feature 415 and prints what a
 * reviewer checks (quickstart Q2; SC-001, SC-002, SC-004): entries per label, main-thread tool
 * calls without an entry, titles that are a raw command although the call had a description, the
 * price against claude's reported total, and the fold time.
 *
 * Run: `node packages/shared/test/fold-real-trace.ts <trace.jsonl> [--story N]`.
 */

import { readFileSync } from "node:fs";
import { normalizeTraceLine } from "../src/runs/trace-event.ts";
import { RunMetrics } from "../src/runs/run-metrics.ts";
import { RunStory, storyLine } from "../src/runs/run-story.ts";
import type { TraceEvent } from "../src/schemas/runs.ts";

/** The trace file. */
const path = process.argv[2];
if (!path) {
  console.error("usage: node fold-real-trace.ts <trace.jsonl> [--story N]");
  process.exit(2);
}
/** Story lines to print. */
const storyCount = Number(process.argv[process.argv.indexOf("--story") + 1] ?? "0") || 0;

/** The file's bytes. */
const bytes = readFileSync(path);
/** The events. */
const events: TraceEvent[] = [];
let start = 0;
for (let i = 0; i < bytes.length; i++) {
  if (bytes[i] !== 0x0a) continue;
  const text = bytes.subarray(start, i).toString("utf8").replace(/\r$/, "");
  events.push(...normalizeTraceLine(text, start, i + 1));
  start = i + 1;
}

/** Fold start. */
const t0 = performance.now();
/** The story. */
const story = new RunStory("item");
/** The metrics. */
const metrics = new RunMetrics();
/** `--no-results`: leave out claude's reported totals, as during a long turn (SC-002). */
const noResults = process.argv.includes("--no-results");
for (const event of events) {
  story.apply(event);
  if (noResults && event.kind === "result") continue;
  metrics.apply(event);
}
/** The views, as a page would take them. */
const entries = story.view();
const critical = story.critical();
/** Fold time. */
const ms = performance.now() - t0;

/** Entries per label. */
const labels: Record<string, number> = {};
for (const e of entries) labels[e.label] = (labels[e.label] ?? 0) + 1;

// Every main-thread tool call must be told; one with a description never by its raw command.
/** Tool calls of the main thread. */
const calls = events.filter((e) => e.kind === "tool-use" && e.parentToolUseId === null);
/** Tool-use ids told by an entry or a group line. */
const told = new Set<string>();
for (const e of entries) {
  if (e.toolUseId) told.add(e.toolUseId);
  for (const c of e.children) if (c.toolUseId) told.add(c.toolUseId);
}
/** Calls without an entry. */
const untold = calls.filter((c) => c.toolUseId && !told.has(c.toolUseId));
/** Entries showing a raw command although the call had a description. */
const rawTitles = entries.filter((e) => {
  if (e.tool !== "Bash" && e.tool !== "PowerShell") return false;
  const call = calls.find((c) => c.toolUseId === e.toolUseId);
  return Boolean(call?.info?.description) && e.title.startsWith("Runs `");
});
/** The last reported total. */
const lastResult = [...events].reverse().find((e) => e.kind === "result" && e.info?.costUsd !== undefined);
/** The figures. */
const snapshot = metrics.snapshot();

console.log(`events ${events.length}, entries ${entries.length}, critical ${critical.length}`);
console.log(`labels ${JSON.stringify(labels)}`);
console.log(
  `main-thread calls ${calls.length}, untold ${untold.length}, raw titles with a description ${rawTitles.length}`,
);
console.log(
  `price ${snapshot.costUsd?.toFixed(3) ?? "-"} (${snapshot.costBasis}) vs reported ${lastResult?.info?.costUsd?.toFixed(3) ?? "-"}; tokens ${JSON.stringify(snapshot.tokens)}; calibration ${snapshot.calibration}`,
);
console.log(`fold ${ms.toFixed(0)} ms`);
for (const e of critical.slice(0, 20))
  console.log(`CRITICAL${e.resolved ? " (resolved)" : ""} ${storyLine(e)} :: ${e.critical}`);
if (storyCount > 0) for (const e of entries.slice(0, storyCount)) console.log(storyLine(e));
