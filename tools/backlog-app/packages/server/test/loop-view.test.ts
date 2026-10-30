// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the loop-view derivation (data-model *Loop view*, analysis A2 §1.2): every shown
 * state from a `status --json` shaped like the loop's real output.
 */

import { describe, expect, it } from "vitest";
import { deriveLoopView, RawStatusSchema, type RawStatus } from "../src/loop/view.ts";

/** Now, for the derivation (2026-10-30 12:00:00 local). */
const NOW = Date.parse("2026-10-30T12:00:00");

/**
 * A raw status with no loop, no run, no lock - the state of a fresh machine.
 *
 * @param patch - Fields to override.
 * @returns The validated raw status.
 */
function status(patch: Partial<RawStatus> = {}): RawStatus {
  return RawStatusSchema.parse({
    loop: null,
    live: false,
    run: null,
    triage: null,
    paused: false,
    stop: false,
    lock: null,
    lock_text: "free",
    trace: null,
    traces_bytes: 0,
    kill: false,
    last: null,
    edit_lock: null,
    log: "x/loop.log",
    orphan: false,
    ...patch,
  });
}

/**
 * A live loop record in a given state.
 *
 * @param state - The loop's state.
 * @param extra - More fields of `loop.json`.
 * @returns The record.
 */
function loopRecord(state: string, extra: Record<string, unknown> = {}): RawStatus["loop"] {
  return {
    pid: 4242,
    started: "2026-10-30 09:00:00",
    state,
    detail: `${state} detail`,
    until: null,
    ctrl_c_safe: state !== "running",
    updated: "2026-10-30 11:59:59",
    slug: state === "running" ? "an-item" : null,
    trace: state === "running" ? ".agent-traces/20261030-090000-claude-an-item" : null,
    counts: { closed: 2, blocked: 1 },
    blocked_streak: 0,
    usage: null,
    auto_triage: false,
    ...extra,
  };
}

describe("deriveLoopView", () => {
  it("shows not-running on a fresh machine", () => {
    const view = deriveLoopView(status(), NOW);
    expect(view.shown).toBe("not-running");
    expect(view.lock).toBeNull();
    expect(view.interruptedRun).toBeNull();
    expect(view.counts).toEqual({});
  });

  it("shows each live state of the loop as it is", () => {
    for (const state of ["starting", "running", "triage", "waiting", "idle", "paused", "limit", "backoff"]) {
      const view = deriveLoopView(status({ loop: loopRecord(state), live: true }), NOW);
      expect(view.shown, state).toBe(state);
      expect(view.detail).toBe(`${state} detail`);
      expect(view.live).toBe(true);
    }
  });

  it("shows pause-pending and stop-pending only while an item or the triage runs", () => {
    expect(deriveLoopView(status({ loop: loopRecord("running"), live: true, paused: true }), NOW).shown).toBe(
      "pause-pending",
    );
    expect(deriveLoopView(status({ loop: loopRecord("triage"), live: true, stop: true }), NOW).shown).toBe(
      "stop-pending",
    );
    // A waiting loop with a pause flag simply pauses at once; no "pending".
    expect(deriveLoopView(status({ loop: loopRecord("paused"), live: true, paused: true }), NOW).shown).toBe(
      "paused",
    );
  });

  it("shows a requested hard stop above everything else", () => {
    const view = deriveLoopView(
      status({ loop: loopRecord("running"), live: true, paused: true, kill: true }),
      NOW,
    );
    expect(view.shown).toBe("kill-pending");
    expect(view.flags.kill).toBe(true);
  });

  it("shows a loop that died without cleanup as dead, with its interrupted run", () => {
    const view = deriveLoopView(
      status({
        loop: loopRecord("running"),
        live: false,
        run: { slug: "an-item", phase: "running", why: null, wait_until: null },
      }),
      NOW,
    );
    expect(view.shown).toBe("dead");
    expect(view.slug).toBeNull();
    expect(view.interruptedRun).toEqual({
      slug: "an-item",
      phase: "running",
      why: null,
      waitUntil: null,
      needsPerson: false,
    });
  });

  it("shows a failed or lost run as stopped for a person", () => {
    for (const phase of ["failed", "lost"]) {
      const view = deriveLoopView(status({ run: { slug: "x", phase, why: "no conversation found" } }), NOW);
      expect(view.shown).toBe("stopped-for-person");
      expect(view.interruptedRun?.needsPerson).toBe(true);
      expect(view.detail).toContain("no conversation found");
    }
  });

  it("shows a held lock without a loop and without a run record as a run outside the loop", () => {
    const view = deriveLoopView(
      status({
        lock: { started: "2026-10-30 10:00:00", slug: "manual-item", branch: "-", host: "pc" },
        lock_text: "held",
      }),
      NOW,
    );
    expect(view.shown).toBe("run-outside-loop");
    expect(view.lock).toEqual({
      slug: "manual-item",
      branch: "-",
      started: "2026-10-30T10:00:00",
      host: "pc",
      stale: false,
    });
  });

  it("marks a lock older than 24 hours as stale", () => {
    const view = deriveLoopView(
      status({
        lock: { started: "2026-10-29 11:00:00", slug: "x", branch: "344-a", host: "pc" },
        lock_text: "held",
      }),
      NOW,
    );
    expect(view.lock?.stale).toBe(true);
  });

  it("reads the usage windows and the reset time of the rate-limit record", () => {
    const usage = {
      status: "allowed_warning",
      resetsAt: 1_798_000_000,
      unifiedWindows: { five_hour: { utilization: 0.42 }, seven_day: { utilization: 0.18 } },
    };
    const view = deriveLoopView(status({ loop: loopRecord("running", { usage }), live: true }), NOW);
    expect(view.usage).toEqual({
      status: "allowed_warning",
      resetsAt: new Date(1_798_000_000 * 1000).toISOString(),
      fiveHour: 0.42,
      sevenDay: 0.18,
    });
  });

  it("shows a waiting loop whose heartbeat stopped as dead", () => {
    const view = deriveLoopView(
      status({ loop: loopRecord("waiting", { updated: "2026-10-30 11:58:00" }), live: true }),
      NOW,
    );
    expect(view.shown).toBe("dead");
    expect(view.heartbeatAge).toBe(120);
  });

  it("reports the orphan claude, the live edit lock and how the last loop ended", () => {
    const view = deriveLoopView(
      status({
        orphan: true,
        edit_lock: { pid: 1, started: "2026-10-30T11:59:00", purpose: "move an item", live: true },
        last: { ended: "2026-10-30 08:00:00", exit_code: 0, reason: "until-idle" },
      }),
      NOW,
    );
    expect(view.orphanClaude).toBe(true);
    expect(view.editLock).toEqual({ pid: 1, started: "2026-10-30T11:59:00", purpose: "move an item" });
    expect(view.lastEnd).toEqual({ ended: "2026-10-30T08:00:00", exitCode: 0, reason: "until-idle" });
    // A dead edit lock is no lock.
    const dead = deriveLoopView(
      status({ edit_lock: { pid: 1, started: "x", purpose: "p", live: false } }),
      NOW,
    );
    expect(dead.editLock).toBeNull();
  });

  it("accepts the real status of this repository's loop (shape check)", () => {
    // The shape `loop.py status --json` printed on 2026-10-30 with no loop on this machine.
    const real = {
      loop: null,
      live: false,
      run: null,
      triage: null,
      paused: false,
      stop: false,
      lock: null,
      lock_text: "free",
      trace: null,
      traces_bytes: 0,
      kill: false,
      last: null,
      edit_lock: null,
      log: "D:\\Projects\\tandemcommander\\.git\\tandem-backlog-loop\\loop.log",
      orphan: false,
    };
    expect(RawStatusSchema.safeParse(real).success).toBe(true);
  });
});
