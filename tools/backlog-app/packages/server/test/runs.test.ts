// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the run history and notifications: the journal parser, the run list from
 * `index.jsonl` + `RUNS.md` (also without any `.agent-traces/`), an ended run's detail folded from
 * its trace, the trace pages, and the derived notification events.
 */

import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { z } from "zod";
import type { LoopView } from "@backlog-app/shared";
import { deriveEvents, type Observation, type WaitTracker } from "../src/events/notifications.ts";
import { isoWeek, parseJournal } from "../src/runs/service.ts";
import { fixtureRepo } from "./helpers/fixture-repo.ts";
import { testApp, type TestApp } from "./helpers/services.ts";

/** A journal with a header and two rows (the real format). */
const JOURNAL = [
  "# Backlog — run journal",
  "",
  "| Date | Item | Outcome | Feature | Branch | Inbox | Person steps | Note |",
  "|---|---|---|---|---|---|---|---|",
  "| 2026-10-24 12:49 | nrg-sessions | closed | 340 | 340-nrg-session-count | 2 | - | bounded by the track table |",
  "| 2026-10-24 15:46 | ftp-alias | blocked | - | - | 0 | - | waits for a | piped note |",
  "",
].join("\n");

describe("parseJournal", () => {
  it("reads the rows with dashes as nulls and keeps pipes inside the note", () => {
    const rows = parseJournal(JOURNAL);
    expect(rows).toHaveLength(2);
    expect(rows[0]).toMatchObject({
      n: 1,
      slug: "nrg-sessions",
      outcome: "closed",
      feature: "340",
      branch: "340-nrg-session-count",
    });
    expect(rows[1]).toMatchObject({
      outcome: "blocked",
      feature: null,
      branch: null,
      note: "waits for a | piped note",
    });
  });

  it("knows ISO weeks", () => {
    expect(isoWeek("2026-10-30T10:00:00")).toBe("2026-W44");
    expect(isoWeek(null)).toBe("unknown");
  });
});

describe("run history", () => {
  let app: TestApp;
  let root = "";
  let cleanup = (): void => undefined;

  beforeEach(async () => {
    ({ root, cleanup } = await fixtureRepo());
    writeFileSync(join(root, "backlog", "RUNS.md"), JOURNAL);
    app = await testApp(root);
  });
  afterEach(async () => {
    await app.services.stopAndDrain();
    cleanup();
  });

  it("lists journal rows when there is no .agent-traces folder at all", async () => {
    const runs = (await app.get("/api/runs")).json as {
      runs: { id: string; hasTrace: boolean; outcome: string }[];
    };
    expect(runs.runs.map((r) => [r.id, r.outcome, r.hasTrace])).toEqual([
      ["runs-md-2", "blocked", false],
      ["runs-md-1", "closed", false],
    ]);
  });

  it("joins an indexed run with its journal row and folds its trace for the detail", async () => {
    const dir = "20261024-120000-claude-nrg-sessions";
    const folder = join(root, ".agent-traces", dir);
    mkdirSync(folder, { recursive: true });
    const lines = [
      {
        type: "backlog_loop.attempt",
        attempt: 1,
        kind: "start",
        reason: "-",
        started: "2026-10-24 12:00:00",
      },
      {
        type: "assistant",
        message: {
          content: [{ type: "tool_use", id: "a", name: "Skill", input: { skill: "speckit-specify" } }],
        },
        parent_tool_use_id: null,
      },
      {
        type: "assistant",
        message: { content: [{ type: "text", text: "Done." }] },
        parent_tool_use_id: null,
      },
      { type: "result", subtype: "success", total_cost_usd: 3.5 },
    ];
    writeFileSync(join(folder, "trace.jsonl"), `${lines.map((l) => JSON.stringify(l)).join("\n")}\n`);
    writeFileSync(
      join(folder, "meta.json"),
      JSON.stringify({
        kind: "item",
        slug: "nrg-sessions",
        feature: "340",
        branch: "340-nrg-session-count",
        commits: [],
      }),
    );
    writeFileSync(
      join(root, ".agent-traces", "index.jsonl"),
      `${JSON.stringify({ dir, kind: "item", slug: "nrg-sessions", started: "2026-10-24T12:00:00", ended: "2026-10-24T12:49:00", outcome: "closed", feature: "340" })}\n`,
    );
    const runs = (await app.get("/api/runs")).json as { runs: { id: string; note: string | null }[] };
    expect(runs.runs.map((r) => r.id)).toEqual(["runs-md-2", dir]);
    expect(runs.runs[1]!.note).toBe("bounded by the track table");
    const detail = (await app.get(`/api/runs/${dir}`)).json as {
      phase: string;
      cost: { usd: number };
      recentMessages: string[];
      durationSeconds: number;
    };
    expect(detail.phase).toBe("specify");
    expect(detail.cost.usd).toBe(3.5);
    expect(detail.recentMessages).toEqual(["Done."]);
    expect(detail.durationSeconds).toBe(49 * 60);
    const page = (await app.get(`/api/runs/${dir}/events?from=0`)).json as {
      events: { kind: string }[];
      next: number;
    };
    expect(page.events.map((e) => e.kind)).toEqual(["attempt", "tool-use", "assistant-text", "result"]);
    // A path-like id is refused before anything is read.
    expect((await app.get("/api/runs/..%2F..%2Fbacklog")).status).toBe(404);
  });

  it("never reads meta.json of a run without an index line, nor caches its fold as final", async () => {
    // A run that just started: the loop replaces its meta.json atomically while it lives, and
    // only appends the index line after the final one (analysis A2 §5.1).
    const dir = "20261030-090000-claude-ftp-alias";
    const folder = join(root, ".agent-traces", dir);
    mkdirSync(folder, { recursive: true });
    writeFileSync(
      join(folder, "trace.jsonl"),
      `${JSON.stringify({ type: "backlog_loop.attempt", attempt: 1, kind: "start", reason: "-", started: "2026-10-30 09:00:00" })}\n`,
    );
    writeFileSync(join(folder, "meta.json"), JSON.stringify({ feature: "999", branch: "999-live-branch" }));
    const detail = (await app.get(`/api/runs/${dir}`)).json as {
      feature: string | null;
      branch: string | null;
    };
    expect(detail.feature).toBeNull();
    expect(detail.branch).toBeNull();
    const cached = app.services.ctx.state.readJson(`cache/runs/${dir}.json`, z.unknown(), null);
    expect(cached).toBeNull();
  });
});

/**
 * A loop view with defaults.
 *
 * @param patch - Fields to change.
 * @returns The view.
 */
function loop(patch: Partial<LoopView>): LoopView {
  return {
    shown: "idle",
    detail: "idle",
    until: null,
    live: true,
    heartbeatAge: 1,
    pid: 1,
    started: null,
    slug: null,
    trace: null,
    counts: {},
    blockedStreak: 0,
    usage: null,
    ctrlCSafe: true,
    flags: { pause: false, stop: false, kill: false },
    lock: null,
    interruptedRun: null,
    orphanClaude: false,
    tracesBytes: 0,
    lastEnd: null,
    editLock: null,
    autoTriage: false,
    ...patch,
  };
}

describe("deriveEvents", () => {
  /**
   * Derives the events of one transition.
   *
   * @param before - Previous observation fields.
   * @param after - New observation fields.
   * @param wait - Waiting detector.
   * @param now - Time.
   * @returns The event kinds.
   */
  const kinds = (
    before: Partial<Observation>,
    after: Partial<Observation>,
    wait: WaitTracker = { since: null, announced: false },
    now = 0,
  ): string[] =>
    deriveEvents(
      { loop: null, inbox: null, check: null, ...before },
      { loop: null, inbox: null, check: null, ...after },
      wait,
      now,
    ).map((e) => e.kind);

  it("announces a stop for a person once, as urgent", () => {
    expect(
      kinds(
        { loop: loop({ shown: "running" }) },
        { loop: loop({ shown: "stopped-for-person", live: false }) },
      ),
    ).toEqual(["stopped-for-person"]);
    expect(
      kinds(
        { loop: loop({ shown: "stopped-for-person", live: false }) },
        { loop: loop({ shown: "stopped-for-person", live: false }) },
      ),
    ).toEqual([]);
  });

  it("announces a usage-limit wait and its end", () => {
    expect(kinds({ loop: loop({ shown: "running" }) }, { loop: loop({ shown: "limit" }) })).toEqual([
      "usage-limit",
    ]);
    expect(kinds({ loop: loop({ shown: "limit" }) }, { loop: loop({ shown: "running" }) })).toEqual([
      "usage-limit-over",
    ]);
  });

  it("announces a precheck wait longer than ten minutes once per episode", () => {
    const wait: WaitTracker = { since: null, announced: false };
    const waiting = loop({ shown: "waiting", detail: "waiting: the working tree is not clean" });
    expect(kinds({ loop: waiting }, { loop: waiting }, wait, 0)).toEqual([]);
    expect(kinds({ loop: waiting }, { loop: waiting }, wait, 11 * 60_000)).toEqual(["precheck-wait"]);
    expect(kinds({ loop: waiting }, { loop: waiting }, wait, 20 * 60_000)).toEqual([]);
  });

  it("announces the loop's end, new Inbox items and new check findings", () => {
    expect(
      kinds({ loop: loop({ shown: "idle" }) }, { loop: loop({ shown: "not-running", live: false }) }),
    ).toEqual(["loop-ended"]);
    expect(kinds({ loop: loop({}), inbox: 2 }, { loop: loop({}), inbox: 4 })).toEqual(["inbox-added"]);
    expect(kinds({ check: 0 }, { check: 3 })).toEqual(["check-findings"]);
    expect(kinds({ check: 3 }, { check: 4 })).toEqual([]);
  });
});
