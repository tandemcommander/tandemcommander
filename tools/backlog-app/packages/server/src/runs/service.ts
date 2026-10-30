// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Runs of the backlog loop: the live run followed as it happens, and the history of every
 * run (research R14 - R16; user stories 2 and 6).
 *
 * Sources:
 * - the loop's run record (through `loop.py status --json`): which run is live and where its trace
 *   folder is;
 * - `.agent-traces/<dir>/trace.jsonl` (append-only, read with the tailer) and, for ended runs,
 *   `meta.json` and `.agent-traces/index.jsonl` (feature 342; the folder is ignored by git and may
 *   not exist at all);
 * - the `RUNS.md` journal (complete since 2026-10-18; from `main`'s git objects during a run) for
 *   runs without a trace;
 * - for the live run's progress: `specs/<branch>/tasks.md` of the working tree (read at most every
 *   three seconds, tolerating its absence) and the branch's commits after the run's base.
 * A `meta.json` is read only after its run ended: the loop replaces it atomically while the run
 * lives, and a reader could make that replace fail (analysis A2 §5.1).
 */

import { existsSync, readFileSync, statSync } from "node:fs";
import { basename, join } from "node:path";
import { z } from "zod";
import {
  ApiError,
  normalizeTraceLine,
  RunState,
  type Outcome,
  type Run,
  type RunStats,
  type StateView,
  type TraceEvent,
} from "@backlog-app/shared";
import type { Services } from "../services.ts";
import { git, showFile } from "../repo/git.ts";
import { readTraceLines } from "./tailer.ts";

/** Interval of reading the live run's `tasks.md` and commits. */
const PROGRESS_MS = 3000;

/** Form of a trace folder name. */
export const RUN_ID_PATTERN = /^\d{8}-\d{6}-claude-[a-z0-9-]+$/;

/** Form of the id of a journal row without a trace. */
const JOURNAL_ID_PATTERN = /^runs-md-\d+$/;

/** A line of `index.jsonl` (feature 342). */
const IndexLineSchema = z.looseObject({
  dir: z.string(),
  kind: z.string().optional(),
  slug: z.string().nullable().optional(),
  started: z.string().nullable().optional(),
  ended: z.string().nullable().optional(),
  phase: z.string().nullable().optional(),
  outcome: z.string().nullable().optional(),
  feature: z.string().nullable().optional(),
  attempts: z.number().nullable().optional(),
});

/** The fields of `meta.json` the history uses. */
const MetaSchema = z.looseObject({
  kind: z.string().optional(),
  slug: z.string().nullable().optional(),
  started: z.string().nullable().optional(),
  ended: z.string().nullable().optional(),
  outcome: z.string().nullable().optional(),
  feature: z.string().nullable().optional(),
  branch: z.string().nullable().optional(),
  why: z.string().nullable().optional(),
  commits: z
    .array(
      z.union([
        z.string(),
        z.object({ hash: z.string().optional(), subject: z.string().optional() }).loose(),
      ]),
    )
    .optional(),
});

/** A row of the `RUNS.md` journal. */
interface JournalRow {
  /** 1-based row number. */
  n: number;
  /** `YYYY-MM-DD HH:MM`. */
  date: string;
  /** The item. */
  slug: string;
  /** The outcome. */
  outcome: string;
  /** Feature number or null. */
  feature: string | null;
  /** Branch or null. */
  branch: string | null;
  /** The note. */
  note: string;
}

/** The cached summary of an ended run (never changes). */
const CachedRunSchema = z.object({
  phase: z.string(),
  timeline: z.array(z.object({ phase: z.string(), at: z.string().nullable() })),
  attempts: z.array(z.record(z.string(), z.unknown())),
  cost: z.number().nullable(),
  offset: z.number(),
});

/** Outcomes the schema knows; anything else becomes `unknown`. */
const KNOWN_OUTCOMES = new Set<string>([
  "running",
  "closed",
  "blocked",
  "not-reproduced",
  "split",
  "nothing-to-do",
  "triaged",
  "killed",
  "failed",
  "lost",
]);

/**
 * Converts any outcome text to an outcome of the schema.
 *
 * @param value - The text.
 * @returns The outcome.
 */
function outcomeOf(value: string | null | undefined): Outcome {
  return value && KNOWN_OUTCOMES.has(value) ? (value as Outcome) : "unknown";
}

/**
 * Parses the rows of the `RUNS.md` journal.
 *
 * @param text - The file content.
 * @returns The rows, oldest first.
 */
export function parseJournal(text: string): JournalRow[] {
  const rows: JournalRow[] = [];
  for (const line of text.replace(/\r\n/g, "\n").split("\n")) {
    if (!line.startsWith("| ") || line.startsWith("| Date") || line.startsWith("|---")) continue;
    const cells = line
      .slice(1, line.endsWith("|") ? -1 : undefined)
      .split(" | ")
      .map((c) => c.trim());
    if (cells.length < 8 || !/^\d{4}-\d{2}-\d{2}/.test(cells[0]!)) continue;
    /**
     * A cell with `-` as null.
     *
     * @param v - The cell.
     * @returns The text or null.
     */
    const dash = (v: string): string | null => (v === "-" || v === "" ? null : v);
    rows.push({
      n: rows.length + 1,
      date: cells[0]!,
      slug: cells[1]!,
      outcome: cells[2]!,
      feature: dash(cells[3]!),
      branch: dash(cells[4]!),
      note: cells.slice(7).join(" | "),
    });
  }
  return rows;
}

/** A listener of live trace events. */
export type TraceListener = (id: string, events: TraceEvent[]) => void;

/** The live run being followed. */
interface LiveRun {
  /** The trace folder name (the run id). */
  id: string;
  /** Absolute path of `trace.jsonl`. */
  path: string;
  /** The folded state. */
  state: RunState;
  /** Read offset. */
  offset: number;
  /** The item (null for a triage). */
  slug: string | null;
  /** When it started (local stamp of the loop). */
  started: string | null;
  /** HEAD at the run's start (for its commits). */
  base: string | null;
  /** Task progress from `tasks.md`. */
  tasks: { done: number; total: number } | null;
  /** Commits of the branch after the base. */
  commits: { hash: string; subject: string }[];
  /** When progress and commits were last read. */
  progressAt: number;
  /** The last published summary (to publish only changes). */
  published: string;
}

/** The runs service. */
export class RunsService {
  /** The server's services. */
  private readonly services: Services;

  /** The live run, if any. */
  private live: LiveRun | null = null;

  /** Subscribers of live trace events. */
  private readonly listeners = new Set<TraceListener>();

  /** The follow timer. */
  private timer: NodeJS.Timeout | null = null;

  /** Ids of runs whose end was announced (for notifications). */
  private readonly ended = new Set<string>();

  /** Called when the live run ended (for notifications), with the id. */
  onEnded: ((id: string) => void) | null = null;

  /**
   * Creates the service.
   *
   * @param services - The server's services.
   */
  constructor(services: Services) {
    this.services = services;
  }

  /**
   * The `.agent-traces` folder of the repository.
   *
   * @returns Its absolute path.
   */
  private get tracesRoot(): string {
    return join(this.services.ctx.repo.root, ".agent-traces");
  }

  /** Starts following the live run (every second). */
  start(): void {
    this.timer = setInterval(() => this.follow(), 1000);
  }

  /** Stops following. */
  stop(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  /**
   * Subscribes to live trace events.
   *
   * @param listener - Called with the run id and the new events.
   * @returns The unsubscribe function.
   */
  subscribe(listener: TraceListener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  /**
   * The id of the live run, if any.
   *
   * @returns The id or null.
   */
  liveId(): string | null {
    return this.live?.id ?? null;
  }

  /**
   * The summary of the live run for the top bar of every tab.
   *
   * @returns The summary or null.
   */
  summary(): StateView["run"] {
    const live = this.live;
    if (!live) return null;
    return { id: live.id, slug: live.slug, phase: live.state.phase, tasks: live.tasks, outcome: "running" };
  }

  /** Reads what is new for the live run and publishes changes (called every second). */
  follow(): void {
    const raw = this.services.loop.raw;
    const runRecord = raw?.run ?? null;
    const tracePath =
      typeof runRecord?.trace === "string" ? runRecord.trace : raw?.live ? (raw.loop?.trace ?? null) : null;
    const id = tracePath ? basename(tracePath) : null;
    if (!id || !RUN_ID_PATTERN.test(id)) {
      if (this.live) this.endLive();
      return;
    }
    if (!this.live || this.live.id !== id) {
      // A new run (the next item, or a triage before it): announce the end of the previous one
      // and fold the new trace from its first byte.
      if (this.live) this.endLive();
      this.live = {
        id,
        path: join(this.tracesRoot, id, "trace.jsonl"),
        state: new RunState(
          id.endsWith("-claude-triage") || /-claude-triage-\d+$/.test(id) ? "triage" : "item",
        ),
        offset: 0,
        slug: runRecord?.slug ?? raw?.loop?.slug ?? null,
        started: runRecord?.started ?? null,
        base: runRecord?.base ?? null,
        tasks: null,
        commits: [],
        progressAt: 0,
        published: "",
      };
    }
    const live = this.live;
    // Read everything new (a large trace in several chunks on the first follow).
    const events: TraceEvent[] = [];
    for (let i = 0; i < 50; i++) {
      const read = readTraceLines(live.path, live.offset);
      // The file is shorter than what was already read: it was truncated or replaced. Fold again
      // from the start rather than show a state mixed from two files.
      if (read.restarted) live.state = new RunState(live.state.kind);
      for (const line of read.lines) {
        for (const event of normalizeTraceLine(line.text, line.offset, line.end, new Date().toISOString())) {
          live.state.apply(event);
          events.push(event);
        }
      }
      if (read.offset === live.offset) break;
      live.offset = read.offset;
    }
    if (events.length > 0) for (const listener of this.listeners) listener(live.id, events);
    // Every 3 s: with the 1 s follow tick a ticked task shows within about 4 s (SC-004: 5 s).
    if (Date.now() - live.progressAt >= PROGRESS_MS) {
      live.progressAt = Date.now();
      void this.readProgress(live);
    }
    this.publishSummary();
  }

  /** Publishes the live summary when it changed. */
  private publishSummary(): void {
    const summary = this.summary();
    const key = JSON.stringify(summary);
    if (this.live && key === this.live.published) return;
    if (this.live) this.live.published = key;
    this.services.ctx.hub.publish(
      "run.changed",
      summary ?? { id: null, slug: null, phase: null, tasks: null },
    );
  }

  /** Marks the live run as ended. */
  private endLive(): void {
    const id = this.live?.id;
    this.live = null;
    this.services.ctx.hub.publish("run.changed", { id: null, slug: null, phase: null, tasks: null });
    if (id && !this.ended.has(id)) {
      this.ended.add(id);
      this.onEnded?.(id);
    }
  }

  /**
   * Reads the live run's task progress and commits.
   *
   * @param live - The live run.
   */
  private async readProgress(live: LiveRun): Promise<void> {
    const branch = this.services.loop.view?.lock?.branch;
    // A feature branch is `NNN-name` (the run's spec folder has the same name); anything else,
    // `..` included, is never joined into a path.
    if (!branch || !/^\d{3}-[a-z0-9][a-z0-9.-]*$/.test(branch) || branch.includes("..")) return;
    try {
      // The working tree is on the run's branch; tasks.md exists only from the tasks phase on.
      const text = readFileSync(join(this.services.ctx.repo.root, "specs", branch, "tasks.md"), "utf8");
      const done = (text.match(/^- \[[xX]\]/gm) ?? []).length;
      const open = (text.match(/^- \[ \]/gm) ?? []).length;
      live.tasks = done + open > 0 ? { done, total: done + open } : null;
    } catch {
      live.tasks = null;
    }
    // `base` comes from the loop's run record; only a plain commit hash goes to git (a value
    // starting with `-` would be read as an option).
    if (live.base && /^[0-9a-f]{7,64}$/.test(live.base)) {
      try {
        const out = await git(this.services.ctx.repo.root, [
          "log",
          "--format=%h%x00%s",
          `${live.base}..${branch}`,
        ]);
        live.commits = out
          .split("\n")
          .filter(Boolean)
          .map((line) => {
            const [hash = "", subject = ""] = line.split("\0");
            return { hash, subject };
          });
      } catch {
        // The branch may not exist yet.
      }
    }
  }

  /**
   * The journal rows (from `main` during a run, else the working tree).
   *
   * @returns The rows.
   */
  private async journal(): Promise<JournalRow[]> {
    const root = this.services.ctx.repo.root;
    const text =
      this.services.source() === "main"
        ? await showFile(root, "main", "backlog/RUNS.md")
        : (() => {
            try {
              return readFileSync(join(root, "backlog", "RUNS.md"), "utf8");
            } catch {
              return null;
            }
          })();
    return text ? parseJournal(text) : [];
  }

  /**
   * The lines of `index.jsonl`.
   *
   * @returns The ended runs with traces, oldest first.
   */
  private index(): z.infer<typeof IndexLineSchema>[] {
    let text: string;
    try {
      text = readFileSync(join(this.tracesRoot, "index.jsonl"), "utf8");
    } catch {
      return [];
    }
    const lines: z.infer<typeof IndexLineSchema>[] = [];
    for (const line of text.split("\n")) {
      if (!line.trim()) continue;
      try {
        const parsed = IndexLineSchema.safeParse(JSON.parse(line));
        if (parsed.success && RUN_ID_PATTERN.test(parsed.data.dir)) lines.push(parsed.data);
      } catch {
        // A damaged line is skipped.
      }
    }
    return lines;
  }

  /**
   * Every run, newest first: the live one, the ended ones with traces, and journal rows without a
   * trace.
   *
   * @param filter - Outcome, item or kind to keep.
   * @returns The runs.
   */
  async list(filter: { outcome?: string; slug?: string; kind?: string } = {}): Promise<Run[]> {
    const runs: Run[] = [];
    const journal = await this.journal();
    const indexed = this.index();
    const usedRows = new Set<number>();
    // Pair each traced run with its journal row (the journal has the branch and the note). The
    // journal has no run id, so the first unused row of the same item (and feature) is taken; both
    // lists are in start order, so repeated runs of one item pair up in order.
    for (const line of indexed) {
      const row = journal.find(
        (r) =>
          !usedRows.has(r.n) && r.slug === line.slug && (line.feature ? r.feature === line.feature : true),
      );
      if (row) usedRows.add(row.n);
      runs.push(this.fromIndex(line, row ?? null));
    }
    for (const row of journal) {
      if (usedRows.has(row.n)) continue;
      runs.push({
        id: `runs-md-${row.n}`,
        kind: "item",
        slug: row.slug,
        title: null,
        started: row.date.replace(" ", "T"),
        ended: row.date.replace(" ", "T"),
        durationSeconds: null,
        phase: row.outcome === "blocked" ? "stopped" : "done",
        phaseTimeline: [],
        attempts: [],
        outcome: outcomeOf(row.outcome),
        feature: row.feature,
        branch: row.branch,
        commits: [],
        tasks: null,
        currentTool: null,
        recentMessages: [],
        guiProbeRunning: false,
        cost: null,
        note: row.note,
        hasTrace: false,
      });
    }
    const live = this.liveRun();
    if (live) runs.push(live);
    runs.sort((a, b) => (b.started ?? "").localeCompare(a.started ?? ""));
    return runs.filter(
      (run) =>
        (!filter.outcome || run.outcome === filter.outcome) &&
        (!filter.slug || run.slug === filter.slug) &&
        (!filter.kind || run.kind === filter.kind),
    );
  }

  /**
   * A run of the index as a run summary (figures from the cache when present).
   *
   * @param line - The index line.
   * @param row - Its journal row, if found.
   * @returns The run.
   */
  private fromIndex(line: z.infer<typeof IndexLineSchema>, row: JournalRow | null): Run {
    const cached = this.services.ctx.state.readJson(
      `cache/runs/${line.dir}.json`,
      CachedRunSchema.nullable(),
      null,
    );
    const started = line.started ?? null;
    const ended = line.ended ?? null;
    const duration = started && ended ? (Date.parse(ended) - Date.parse(started)) / 1000 : null;
    return {
      id: line.dir,
      kind: line.kind === "triage" ? "triage" : "item",
      slug: line.slug ?? null,
      title: null,
      started,
      ended,
      durationSeconds: duration !== null && Number.isFinite(duration) ? duration : null,
      // Without the cache (the run was never opened) an indexed run is at least over.
      phase: (cached?.phase as Run["phase"] | undefined) ?? "done",
      phaseTimeline: (cached?.timeline as Run["phaseTimeline"] | undefined) ?? [],
      attempts: [],
      outcome: outcomeOf(line.outcome),
      feature: line.feature ?? row?.feature ?? null,
      branch: row?.branch ?? null,
      commits: [],
      tasks: null,
      currentTool: null,
      recentMessages: [],
      guiProbeRunning: false,
      cost:
        cached?.cost !== null && cached?.cost !== undefined
          ? { usd: cached.cost, inputTokens: 0, outputTokens: 0, cacheRead: 0, cacheWrite: 0 }
          : null,
      note: row?.note ?? null,
      hasTrace: true,
    };
  }

  /**
   * The live run as a run.
   *
   * @returns The run, or null when none is live.
   */
  liveRun(): Run | null {
    const live = this.live;
    if (!live) return null;
    const state = live.state;
    const startedEpoch = this.services.loop.raw?.run?.started_epoch;
    return {
      id: live.id,
      kind: state.kind,
      slug: live.slug,
      title: null,
      started: live.started ? live.started.replace(" ", "T") : null,
      ended: null,
      durationSeconds: typeof startedEpoch === "number" ? Date.now() / 1000 - startedEpoch : null,
      phase: state.phase,
      phaseTimeline: state.timeline,
      attempts: state.attempts,
      outcome: "running",
      feature: null,
      branch: this.services.loop.view?.lock?.branch ?? null,
      commits: live.commits,
      tasks: live.tasks,
      currentTool: state.currentTool(),
      recentMessages: [...state.recentMessages],
      guiProbeRunning: state.guiProbeRunning(),
      cost:
        state.costUsd() === null
          ? null
          : { usd: state.costUsd()!, inputTokens: 0, outputTokens: 0, cacheRead: 0, cacheWrite: 0 },
      note: null,
      hasTrace: true,
    };
  }

  /**
   * One run in full. An ended run's trace is folded once and its figures cached.
   *
   * @param id - The run id (validated here).
   * @returns The run.
   * @throws ApiError `not-found` for an unknown id.
   */
  async detail(id: string): Promise<Run> {
    if (this.live?.id === id) return this.liveRun()!;
    if (JOURNAL_ID_PATTERN.test(id)) {
      const run = (await this.list()).find((r) => r.id === id);
      if (!run) throw new ApiError("not-found", "no such run");
      return run;
    }
    if (!RUN_ID_PATTERN.test(id)) throw new ApiError("not-found", "no such run");
    const folder = join(this.tracesRoot, id);
    if (!existsSync(folder)) throw new ApiError("not-found", "no such run");
    const line = this.index().find((l) => l.dir === id);
    const journal = await this.journal();
    const row = line
      ? (journal.find((r) => r.slug === line.slug && (line.feature ? r.feature === line.feature : true)) ??
        null)
      : null;
    const base = line ? this.fromIndex(line, row) : this.fromIndex({ dir: id }, null);
    // Fold the whole trace (the run ended: it never changes again).
    const state = new RunState(base.kind);
    let offset = 0;
    for (let i = 0; i < 100_000; i++) {
      const read = readTraceLines(join(folder, "trace.jsonl"), offset);
      for (const traceLine of read.lines)
        for (const event of normalizeTraceLine(traceLine.text, traceLine.offset, traceLine.end))
          state.apply(event);
      if (read.offset === offset) break;
      offset = read.offset;
    }
    // The loop appends a run's index line only after its final `meta.json` is written
    // (`loop.py` finish_trace). A run without one is still running (it started a moment ago and the
    // follower has not picked it up) or was cut off: its `meta.json` may be replaced atomically
    // at any time, and an open handle here could make that replace fail (analysis A2 §5.1). So
    // `meta.json` is read, and the fold cached as final, only for an indexed run.
    let meta: z.infer<typeof MetaSchema> | null = null;
    if (line) {
      try {
        meta = MetaSchema.parse(JSON.parse(readFileSync(join(folder, "meta.json"), "utf8")));
      } catch {
        meta = null;
      }
    }
    const cost = state.costUsd();
    if (line) {
      this.services.ctx.state.writeJson(`cache/runs/${id}.json`, {
        phase: state.phase,
        timeline: state.timeline,
        attempts: state.attempts,
        cost,
        offset,
      });
    }
    return {
      ...base,
      phase: state.phase,
      phaseTimeline: state.timeline,
      attempts: state.attempts,
      recentMessages: [...state.recentMessages],
      cost:
        cost === null ? null : { usd: cost, inputTokens: 0, outputTokens: 0, cacheRead: 0, cacheWrite: 0 },
      feature: meta?.feature ?? base.feature,
      branch: meta?.branch ?? base.branch,
      note: base.note ?? meta?.why ?? null,
      commits: (meta?.commits ?? []).map((c) =>
        typeof c === "string"
          ? { hash: c.split(" ")[0] ?? c, subject: c.split(" ").slice(1).join(" ") }
          : { hash: c.hash ?? "", subject: c.subject ?? "" },
      ),
    };
  }

  /**
   * A page of a run's trace events from a byte offset (replay and the stream's catch-up).
   *
   * @param id - The run id.
   * @param from - Byte offset.
   * @param maxBytes - Most bytes to read.
   * @returns The events and the offset to continue from.
   * @throws ApiError `not-found` for an unknown run.
   */
  events(
    id: string,
    from: number,
    maxBytes = 1024 * 1024,
  ): { events: TraceEvent[]; next: number; size: number } {
    if (!RUN_ID_PATTERN.test(id)) throw new ApiError("not-found", "no such run");
    const path = join(this.tracesRoot, id, "trace.jsonl");
    if (!existsSync(path)) throw new ApiError("not-found", "the run has no trace");
    const read = readTraceLines(path, from, maxBytes);
    const events = read.lines.flatMap((line) => normalizeTraceLine(line.text, line.offset, line.end));
    let size: number;
    try {
      size = statSync(path).size;
    } catch {
      size = 0;
    }
    return { events, next: read.offset, size };
  }

  /**
   * Aggregates over the runs for the statistics panel.
   *
   * @param from - Earliest start (ISO date), inclusive.
   * @returns The statistics.
   */
  async stats(from: string | null): Promise<RunStats> {
    const runs = (await this.list()).filter(
      (r) => r.outcome !== "running" && (!from || (r.started ?? "") >= from),
    );
    const byOutcome: Record<string, number> = {};
    const byArea: Record<string, number> = {};
    const byWeekMap = new Map<string, Record<string, number>>();
    const board = this.services.read.peek()?.board;
    const areaOf = new Map<string, string>();
    for (const section of board?.sections ?? [])
      for (const row of section.rows) if (row.kind === "item") areaOf.set(row.slug, row.area);
    const closed = await this.services.history.closedItems().catch(() => []);
    for (const item of closed) if (!areaOf.has(item.slug)) areaOf.set(item.slug, item.area);
    let cost = 0;
    const durations: number[] = [];
    for (const run of runs) {
      byOutcome[run.outcome] = (byOutcome[run.outcome] ?? 0) + 1;
      const area = run.slug ? (areaOf.get(run.slug) ?? "unknown") : "triage";
      byArea[area] = (byArea[area] ?? 0) + 1;
      const week = isoWeek(run.started);
      const counts = byWeekMap.get(week) ?? {};
      counts[run.outcome] = (counts[run.outcome] ?? 0) + 1;
      byWeekMap.set(week, counts);
      if (run.cost) cost += run.cost.usd;
      if (run.durationSeconds !== null && run.durationSeconds > 0) durations.push(run.durationSeconds);
    }
    durations.sort((a, b) => a - b);
    return {
      byOutcome,
      byArea,
      byWeek: [...byWeekMap]
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([week, counts]) => ({ week, counts })),
      costUsd: Math.round(cost * 100) / 100,
      durations: {
        median: durations.length ? durations[Math.floor(durations.length / 2)]! : null,
        mean: durations.length ? durations.reduce((a, b) => a + b, 0) / durations.length : null,
      },
    };
  }
}

/**
 * The ISO week (`2026-W44`) of a time.
 *
 * @param value - An ISO or `YYYY-MM-DD HH:MM` time.
 * @returns The week, or `unknown`.
 */
export function isoWeek(value: string | null): string {
  if (!value) return "unknown";
  const date = new Date(value.replace(" ", "T"));
  if (Number.isNaN(date.getTime())) return "unknown";
  const day = (date.getDay() + 6) % 7;
  const thursday = new Date(date);
  thursday.setDate(date.getDate() - day + 3);
  const firstThursday = new Date(thursday.getFullYear(), 0, 4);
  const week =
    1 +
    Math.round(
      ((thursday.getTime() - firstThursday.getTime()) / 86_400_000 - 3 + ((firstThursday.getDay() + 6) % 7)) /
        7,
    );
  return `${thursday.getFullYear()}-W${String(week).padStart(2, "0")}`;
}
