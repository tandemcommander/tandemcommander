// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the write gate (research R9 of 344; redefined by feature 371, data-model *Write
 * gate*): one case per row of the decision table - unknown state, degraded read, merge, stale
 * lock, the loop's edit lock (`run-starting`), another process's edit lock (but not the app's
 * own), a run lock with HEAD on `main` (`run-on-main`) and on a branch (`main-ref`), the loop's
 * finishing steps, not on `main`, an interrupted run (frozen item), a live loop (`commit`), no loop
 * (`tray`) - and the frozen slug and channel in each.
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

/** The pid of a live loop in these tests. */
const LOOP_PID = 4242;

describe("computeGate", () => {
  it("is open on a clean main with no loop: the tray channel, nothing frozen", () => {
    expect(gateOf()).toMatchObject({
      state: "free",
      writable: true,
      channel: "tray",
      frozenSlug: null,
      reason: "",
      headIsMain: true,
    });
  });

  it("is closed while the loop or the repository is not known yet", () => {
    expect(gateOf({ loop: null })).toMatchObject({ state: "degraded", writable: false, channel: null });
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

  it("offers a stale lock only when no loop lives", () => {
    const stale = { ...LOCK, stale: true };
    expect(gateOf({ loop: loop({ lock: stale }) })).toMatchObject({ state: "stale-lock", writable: false });
    // A live loop with a stale lock: the run is on its branch - writable through main.
    expect(
      gateOf({
        loop: loop({ live: true, shown: "running", lock: stale }),
        repo: repo({ branch: "345-an-item" }),
      }),
    ).toMatchObject({ state: "free", channel: "main-ref", frozenSlug: "an-item" });
  });

  it("is read-only while the loop holds the edit lock (a run starts or returns), naming the frozen item", () => {
    const starting = { pid: LOOP_PID, started: "2026-10-30T10:00:00", purpose: "loop: starting a run" };
    expect(
      gateOf({ loop: loop({ live: true, pid: LOOP_PID, shown: "running", editLock: starting }) }),
    ).toMatchObject({ state: "run-starting", writable: false, frozenSlug: null });
    const withLock = gateOf({
      loop: loop({ live: true, pid: LOOP_PID, shown: "running", editLock: starting, lock: LOCK }),
      repo: repo({ branch: "main" }),
    });
    expect(withLock).toMatchObject({ state: "run-starting", frozenSlug: "an-item" });
    expect(withLock.reason).toContain("the run of an-item is on main");
    const returning = { ...starting, purpose: "loop: the run of an-item returns to main" };
    expect(
      gateOf({
        loop: loop({ live: true, pid: LOOP_PID, shown: "running", editLock: returning, lock: LOCK }),
        repo: repo({ branch: "345-an-item" }),
      }),
    ).toMatchObject({ state: "run-starting", writable: false, frozenSlug: "an-item" });
  });

  it("is closed while another process holds the edit lock, but not for the app's own", () => {
    const other = { pid: process.pid + 1, started: "2026-10-30T10:00:00", purpose: "move x" };
    expect(gateOf({ loop: loop({ editLock: other }) })).toMatchObject({
      state: "edit-in-progress",
      writable: false,
    });
    expect(gateOf({ loop: loop({ editLock: { ...other, pid: process.pid } }) }).state).toBe("free");
  });

  it("is read-only while a run holds the lock and the primary tree is on main (a run outside the loop)", () => {
    const gate = gateOf({ loop: loop({ lock: LOCK }) });
    expect(gate).toMatchObject({
      state: "run-on-main",
      writable: false,
      frozenSlug: "an-item",
      channel: null,
    });
    expect(gate.reason).toContain("is on main");
  });

  it("writes through main while a run holds the lock on its branch, with the item frozen", () => {
    for (const shown of ["running", "pause-pending", "stop-pending"] as const) {
      expect(
        gateOf({ loop: loop({ live: true, shown, lock: LOCK }), repo: repo({ branch: "345-an-item" }) }),
        shown,
      ).toMatchObject({ state: "free", writable: true, channel: "main-ref", frozenSlug: "an-item" });
    }
    // Also for a run of a dead loop or a manual run: the lock and the branch decide.
    expect(gateOf({ loop: loop({ lock: LOCK }), repo: repo({ branch: "345-an-item" }) })).toMatchObject({
      state: "free",
      channel: "main-ref",
      frozenSlug: "an-item",
    });
  });

  it("is closed while the loop's auto-triage runs or a hard stop is handled", () => {
    for (const shown of ["triage", "kill-pending"] as const) {
      expect(gateOf({ loop: loop({ live: true, shown }) }), shown).toMatchObject({
        state: "auto-triage",
        writable: false,
      });
    }
  });

  it("is closed off main without a run", () => {
    expect(gateOf({ repo: repo({ branch: "345-feature" }) })).toMatchObject({
      state: "not-on-main",
      writable: false,
      headIsMain: false,
    });
  });

  it("commits at once while a live loop is between runs, in every such state", () => {
    for (const shown of ["starting", "waiting", "idle", "limit", "backoff", "paused", "dead"] as const) {
      expect(gateOf({ loop: loop({ live: true, shown }) }), shown).toMatchObject({
        state: "free",
        writable: true,
        channel: "commit",
        frozenSlug: null,
      });
    }
  });

  it("uses the tray once the loop is gone", () => {
    expect(gateOf({ loop: loop({ live: false, shown: "dead" }) })).toMatchObject({
      state: "free",
      channel: "tray",
    });
  });

  it("freezes the item of an interrupted run that waits to be continued, not one that needs a person", () => {
    const interrupted = {
      slug: "an-item",
      phase: "implement",
      why: null,
      waitUntil: null,
      needsPerson: false,
    };
    expect(gateOf({ loop: loop({ interruptedRun: interrupted }) })).toMatchObject({
      state: "free",
      writable: true,
      channel: "tray",
      frozenSlug: "an-item",
    });
    expect(gateOf({ loop: loop({ interruptedRun: { ...interrupted, needsPerson: true } }) })).toMatchObject({
      state: "free",
      frozenSlug: null,
    });
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
