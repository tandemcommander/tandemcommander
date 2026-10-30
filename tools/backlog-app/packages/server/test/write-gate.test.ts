// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the write gate (research R9, FR-023; review M3): every rule of `computeGate` -
 * unknown state, degraded read, merge, run lock (live and stale), the loop's finishing steps, not
 * on `main`, another process's edit lock (but not the app's own), a loop between runs in each of
 * its states, a live loop that stopped answering, an interrupted run - and the states in which the
 * gate is open.
 */

import { describe, expect, it } from "vitest";
import type { LoopView } from "@backlog-app/shared";
import { computeGate, type GateInputs } from "../src/backlog/write-gate.ts";
import type { RepoState } from "../src/repo/monitor.ts";

/**
 * A loop view of a loop that does not run, with fields changed.
 *
 * @param patch - Fields to change.
 * @returns The view.
 */
function loop(patch: Partial<LoopView> = {}): LoopView {
  return {
    shown: "not-running",
    detail: "not running",
    until: null,
    live: false,
    heartbeatAge: null,
    pid: null,
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

/**
 * A clean repository on `main`, with fields changed.
 *
 * @param patch - Fields to change.
 * @returns The state.
 */
function repo(patch: Partial<RepoState> = {}): RepoState {
  return { branch: "main", mainCommit: "a".repeat(40), merging: false, dirty: [], ...patch };
}

/**
 * The gate for inputs with defaults (no loop, clean `main`, readable, no findings).
 *
 * @param patch - Inputs to change.
 * @returns The gate.
 */
function gateOf(patch: Partial<GateInputs> = {}) {
  return computeGate({ loop: loop(), repo: repo(), degraded: false, checkTotal: 0, ...patch });
}

/** A held run lock. */
const LOCK = {
  slug: "an-item",
  branch: "345-an-item",
  started: "2026-10-30T10:00:00",
  host: "h",
  stale: false,
};

describe("computeGate", () => {
  it("is open on a clean main with no loop", () => {
    expect(gateOf()).toMatchObject({ state: "free", writable: true, reason: "", headIsMain: true });
  });

  it("is closed while the loop or the repository is not known yet", () => {
    expect(gateOf({ loop: null })).toMatchObject({ state: "degraded", writable: false });
    expect(gateOf({ repo: null })).toMatchObject({ state: "degraded", writable: false });
  });

  it("is closed while the backlog cannot be read", () => {
    expect(gateOf({ degraded: true })).toMatchObject({ state: "degraded", writable: false });
  });

  it("is closed during a merge", () => {
    expect(gateOf({ repo: repo({ merging: true }) })).toMatchObject({
      state: "merge-in-progress",
      writable: false,
    });
  });

  it("is closed while a run holds the run lock, also without a live loop", () => {
    expect(gateOf({ loop: loop({ lock: LOCK }) })).toMatchObject({
      state: "run-holds-lock",
      writable: false,
    });
    expect(gateOf({ loop: loop({ live: true, shown: "running", lock: LOCK }) }).state).toBe("run-holds-lock");
  });

  it("offers a stale lock only when no loop lives", () => {
    const stale = { ...LOCK, stale: true };
    expect(gateOf({ loop: loop({ lock: stale }) })).toMatchObject({ state: "stale-lock", writable: false });
    expect(gateOf({ loop: loop({ live: true, shown: "running", lock: stale }) }).state).toBe(
      "run-holds-lock",
    );
  });

  it("is closed while the loop's current step finishes", () => {
    for (const shown of ["triage", "pause-pending", "stop-pending", "kill-pending"] as const) {
      expect(gateOf({ loop: loop({ live: true, shown }) }), shown).toMatchObject({
        state: "auto-triage",
        writable: false,
      });
    }
  });

  it("is closed off main", () => {
    expect(gateOf({ repo: repo({ branch: "345-feature" }) })).toMatchObject({
      state: "not-on-main",
      writable: false,
      headIsMain: false,
    });
  });

  it("is closed while another process holds the edit lock, but not for the app's own", () => {
    const other = { pid: process.pid + 1, started: "2026-10-30T10:00:00", purpose: "move x" };
    expect(gateOf({ loop: loop({ editLock: other }) })).toMatchObject({
      state: "edit-in-progress",
      writable: false,
    });
    expect(gateOf({ loop: loop({ editLock: { ...other, pid: process.pid } }) }).state).toBe("free");
  });

  it("is closed while a live loop is between runs, in every such state", () => {
    for (const shown of ["starting", "waiting", "idle", "limit", "backoff", "running"] as const) {
      expect(gateOf({ loop: loop({ live: true, shown }) }), shown).toMatchObject({
        state: "loop-between-runs",
        writable: false,
      });
    }
  });

  it("is closed while a live loop has stopped answering, open once it is gone", () => {
    expect(gateOf({ loop: loop({ live: true, shown: "dead" }) })).toMatchObject({
      state: "loop-between-runs",
      writable: false,
    });
    expect(gateOf({ loop: loop({ live: false, shown: "dead" }) }).state).toBe("free");
  });

  it("is open while the loop is paused", () => {
    expect(gateOf({ loop: loop({ live: true, shown: "paused" }) }).state).toBe("free");
  });

  it("is closed while an interrupted run waits to be continued, open when it needs a person", () => {
    const interrupted = {
      slug: "an-item",
      phase: "implement",
      why: null,
      waitUntil: null,
      needsPerson: false,
    };
    expect(gateOf({ loop: loop({ interruptedRun: interrupted }) })).toMatchObject({
      state: "run-holds-lock",
      writable: false,
    });
    expect(gateOf({ loop: loop({ interruptedRun: { ...interrupted, needsPerson: true } }) }).state).toBe(
      "free",
    );
  });

  it("reports check findings and dirty files outside backlog/ without closing", () => {
    const gate = gateOf({
      checkTotal: 2,
      repo: repo({
        dirty: [
          { path: "backlog/BACKLOG.md", code: " M" },
          { path: "src/x.cpp", code: " M" },
        ],
      }),
    });
    expect(gate).toMatchObject({ state: "free", checkClean: false, dirtyOutsideBacklog: ["src/x.cpp"] });
  });
});
