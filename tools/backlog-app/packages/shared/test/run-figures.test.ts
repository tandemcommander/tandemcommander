// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the figures of feature 415: the event facts (`TraceEvent.info`), the time index,
 * the price table, the metrics fold and the progress estimate.
 */

import { describe, expect, it } from "vitest";
import { normalizeTraceLine } from "../src/runs/trace-event.ts";
import { TimeIndex } from "../src/runs/time-index.ts";
import { priceOf, priceTable } from "../src/runs/pricing.ts";
import { RunMetrics } from "../src/runs/run-metrics.ts";
import { DEFAULT_EXPECTED_SECONDS, estimateProgress, PHASE_WEIGHTS } from "../src/runs/run-progress.ts";
import { attempt, call, eventsOf, result, say, turnEnd } from "./helpers/trace.ts";

describe("TraceEvent.info", () => {
  it("carries the description, the file and the subagent type of a tool call", () => {
    const [bash] = eventsOf([call("t1", "Bash", { command: "build.cmd", description: "Build the program" })]);
    expect(bash?.summary).toBe("build.cmd");
    expect(bash?.info?.description).toBe("Build the program");
    const [edit] = eventsOf([call("t2", "Edit", { file_path: "E:\\r\\src\\a.cpp", old_string: "x" })]);
    expect(edit?.info?.filePath).toBe("E:\\r\\src\\a.cpp");
    const [agent] = eventsOf([
      call("t3", "Agent", { description: "Review", subagent_type: "general-purpose" }),
    ]);
    expect(agent?.info?.subagentType).toBe("general-purpose");
    const [skill] = eventsOf([call("t4", "Skill", { skill: "speckit-plan", args: "Autonomous" })]);
    expect(skill?.info?.description).toBe("speckit-plan Autonomous");
  });

  it("puts the message's usage, model and size on the first event of its line only", () => {
    const line = {
      type: "assistant",
      message: {
        id: "msg-1",
        model: "claude-opus-5-5",
        content: [
          { type: "text", text: "Hello" },
          { type: "tool_use", id: "t1", name: "Bash", input: { command: "ls" } },
        ],
        usage: {
          input_tokens: 3,
          output_tokens: 9,
          cache_read_input_tokens: 100,
          cache_creation_input_tokens: 30,
          cache_creation: { ephemeral_5m_input_tokens: 10, ephemeral_1h_input_tokens: 20 },
        },
      },
    };
    const events = normalizeTraceLine(JSON.stringify(line), 0, 10);
    expect(events).toHaveLength(2);
    expect(events[0]?.info).toMatchObject({
      messageId: "msg-1",
      model: "claude-opus-5-5",
      usage: { input: 3, output: 9, cacheRead: 100, cacheWrite5m: 10, cacheWrite1h: 20 },
      outputChars: 5 + JSON.stringify({ command: "ls" }).length,
    });
    expect(events[1]?.info?.usage).toBeUndefined();
    expect(events[1]?.info?.messageId).toBeUndefined();
  });

  it("reads a result's cost and totals, a rate limit's windows, a task's tool call", () => {
    const [res] = eventsOf([turnEnd(1.5, { input: 1, output: 2, read: 3, w5: 4, w1: 5 })]);
    expect(res?.info).toMatchObject({
      costUsd: 1.5,
      totals: { input: 1, output: 2, cacheRead: 3, cacheWrite5m: 4, cacheWrite1h: 5 },
    });
    const [limit] = eventsOf([
      {
        type: "rate_limit_event",
        rate_limit_info: {
          status: "allowed",
          resetsAt: 99,
          unifiedWindows: { five_hour: { utilization: 0.59 }, seven_day: { utilization: 0.68 } },
        },
      },
    ]);
    expect(limit?.info?.limits).toEqual({ status: "allowed", fiveHour: 0.59, sevenDay: 0.68, resetsAt: 99 });
    const [task] = eventsOf([
      { type: "system", subtype: "task_progress", tool_use_id: "a1", description: "Running tests" },
    ]);
    expect(task?.toolUseId).toBe("a1");
    expect(task?.info?.taskStatus).toBe("Running tests");
  });

  it("keeps the end of a long tool result (its verdict)", () => {
    const long = `${"x".repeat(5000)}\nBUILD SUCCEEDED`;
    const [res] = eventsOf([result("t1", long)]);
    expect(res?.text?.includes("BUILD SUCCEEDED")).toBe(false);
    expect(res?.info?.tail?.endsWith("BUILD SUCCEEDED")).toBe(true);
  });

  it("leaves events of other kinds without info", () => {
    const [init] = eventsOf([{ type: "system", subtype: "init", session_id: "s", model: "m" }]);
    expect(init?.info).toBeUndefined();
  });
});

describe("TimeIndex", () => {
  it("interpolates between anchors and clamps outside them", () => {
    const index = new TimeIndex([
      { offset: 0, ms: 1000 },
      { offset: 100, ms: 2000 },
    ]);
    expect(index.timeAt(50)).toBe(1500);
    expect(index.timeAt(-5)).toBe(1000);
    expect(index.timeAt(500)).toBe(2000);
    expect(new TimeIndex().timeAt(5)).toBeNull();
  });

  it("never lets a later offset get an earlier time, and keeps the first time of an offset", () => {
    const index = new TimeIndex();
    index.add(0, 5000);
    index.add(100, 4000); // the clock stepped back
    expect(index.timeAt(100)).toBe(5000);
    index.add(100, 9000);
    expect(index.timeAt(100)).toBe(5000);
    index.add(50, 7000); // between: limited by its neighbours
    expect(index.timeAt(50)).toBe(5000);
  });

  it("thins itself beyond 2000 anchors keeping both ends", () => {
    const index = new TimeIndex();
    for (let i = 0; i <= 3000; i++) index.add(i * 10, i * 1000);
    expect(index.size).toBeLessThanOrEqual(2000);
    expect(index.timeAt(0)).toBe(0);
    expect(index.timeAt(30_000)).toBe(3_000_000);
    expect(index.timeAt(15_000)).toBe(1_500_000);
  });
});

describe("prices", () => {
  it("match a model by its id prefix, never guess an unknown one", () => {
    expect(priceTable("claude-opus-5-5")?.output).toBe(20);
    expect(priceTable("claude-opus-5-5[1m]")?.input).toBe(4);
    expect(priceTable("claude-opus-5-20260101")?.input).toBe(5);
    expect(priceTable("claude-sonnet-5-5")?.input).toBe(2);
    expect(priceTable("fake-model")).toBeNull();
    expect(
      priceOf("fake-model", { input: 1, output: 1, cacheRead: 0, cacheWrite5m: 0, cacheWrite1h: 0 }),
    ).toBeNull();
  });

  it("reproduce claude's reported cost of the 414 run (fix-log Measure)", () => {
    const cost = priceOf("claude-opus-5-5", {
      input: 1202,
      output: 343_692,
      cacheRead: 97_653_679,
      cacheWrite5m: 833_484,
      cacheWrite1h: 414_817,
    });
    expect(cost).not.toBeNull();
    expect(Math.abs(cost! - 33.8953) / 33.8953).toBeLessThan(0.001);
  });
});

describe("RunMetrics", () => {
  it("counts a message once although it spans several lines, and estimates its price", () => {
    const metrics = new RunMetrics();
    const usage = { input_tokens: 10, output_tokens: 5, cache_read_input_tokens: 1_000_000 };
    for (const e of eventsOf([
      say("first block", { message: "m1", usage }),
      call("t1", "Bash", { command: "ls" }, { message: "m1", usage }),
    ]))
      metrics.apply(e);
    const s = metrics.snapshot();
    expect(s.messages).toBe(1);
    expect(s.tokens.input).toBe(10);
    expect(s.tokens.cacheRead).toBe(1_000_000);
    expect(s.costBasis).toBe("estimate");
    // 1 M cache reads at $0.20 plus a few tokens.
    expect(s.costUsd).toBeGreaterThan(0.2);
    expect(s.costUsd).toBeLessThan(0.21);
    expect(s.contextTokens).toBe(1_000_010);
    expect(s.toolCalls).toBe(1);
  });

  it("takes a result's totals as they are and adds only what came after", () => {
    const metrics = new RunMetrics();
    for (const e of eventsOf([
      say("a", { message: "m1", usage: { input_tokens: 1, output_tokens: 1, cache_read_input_tokens: 10 } }),
      turnEnd(2.5, { input: 100, output: 2000, read: 5000, w5: 0, w1: 0 }),
    ]))
      metrics.apply(e);
    let s = metrics.snapshot();
    expect(s.costUsd).toBe(2.5);
    expect(s.costBasis).toBe("reported");
    expect(s.tokens.output).toBe(2000);
    for (const e of eventsOf([
      say("b", {
        message: "m2",
        usage: { input_tokens: 0, output_tokens: 0, cache_read_input_tokens: 1_000_000 },
      }),
    ]))
      metrics.apply(e);
    s = metrics.snapshot();
    expect(s.costBasis).toBe("estimate");
    expect(s.costUsd).toBeGreaterThan(2.7);
    expect(s.reportedUsd).toBe(2.5);
  });

  it("calibrates the output estimate on what a result reports, and uses it afterwards", () => {
    const metrics = new RunMetrics();
    const words = (id: string, n: number) =>
      say("y".repeat(n), {
        message: id,
        usage: { input_tokens: 0, output_tokens: 0, cache_read_input_tokens: 0 },
      });
    // 36 000 characters = 10 000 estimated tokens before calibration (3.6 characters each).
    for (const e of eventsOf([words("m1", 36_000)])) metrics.apply(e);
    expect(metrics.snapshot().calibration).toBe(2.7);
    expect(metrics.snapshot().tokens.output).toBe(27_000);
    // The result says 40 000 were produced: the factor becomes 4.
    for (const e of eventsOf([turnEnd(1, { input: 0, output: 40_000, read: 0, w5: 0, w1: 0 })]))
      metrics.apply(e);
    expect(metrics.snapshot().calibration).toBe(4);
    expect(metrics.snapshot().tokens.output).toBe(40_000);
    // The next 3 600 characters count 4 000 output tokens beyond the reported ones.
    for (const e of eventsOf([words("m2", 3600)])) metrics.apply(e);
    expect(metrics.snapshot().tokens.output).toBe(44_000);
  });

  it("adds the attempts of a continued run (each process reports its own totals)", () => {
    const metrics = new RunMetrics();
    for (const e of eventsOf([
      attempt(1),
      turnEnd(1, { input: 1, output: 1, read: 1, w5: 0, w1: 0 }),
      attempt(2, "usage-limit"),
      turnEnd(3, { input: 2, output: 2, read: 2, w5: 0, w1: 0 }),
    ]))
      metrics.apply(e);
    expect(metrics.snapshot().costUsd).toBe(4);
    expect(metrics.snapshot().tokens.input).toBe(3);
  });

  it("names an unpriced model and keeps its tokens", () => {
    const metrics = new RunMetrics();
    for (const e of eventsOf([call("t1", "Bash", { command: "ls" }, { model: "fake-model" })]))
      metrics.apply(e);
    const s = metrics.snapshot();
    expect(s.unpricedModels).toEqual(["fake-model"]);
    expect(s.costUsd).toBeNull();
    expect(s.tokens.cacheRead).toBe(1000);
  });

  it("counts errors, subagents, changed files and the latest limits", () => {
    const metrics = new RunMetrics();
    for (const e of eventsOf([
      call("t1", "Agent", { description: "Review" }),
      call("t2", "Edit", { file_path: "a.ts" }),
      call("t3", "Write", { file_path: "a.ts" }),
      call("t4", "Write", { file_path: "b.ts" }),
      result("t2", "boom", true),
      { type: "rate_limit_event", rate_limit_info: { status: "allowed_warning" } },
    ]))
      metrics.apply(e);
    const s = metrics.snapshot();
    expect(s.subagents).toBe(1);
    expect(s.filesChanged).toBe(2);
    expect(s.toolErrors).toBe(1);
    expect(s.limits?.status).toBe("allowed_warning");
  });
});

describe("estimateProgress", () => {
  const base = {
    kind: "item" as const,
    phaseStartedMs: null,
    tasks: null,
    elapsedSeconds: 0,
    history: { medianSeconds: 7200, count: 5 },
    nowMs: 1_000_000,
  };

  it("has phase weights summing to one", () => {
    const sum = Object.values(PHASE_WEIGHTS).reduce((a, b) => a + (b ?? 0), 0);
    expect(Math.abs(sum - 1)).toBeLessThan(1e-9);
  });

  it("places implement with half its tasks halfway through its share", () => {
    const p = estimateProgress({
      ...base,
      phase: "implement",
      tasks: { done: 6, total: 12 },
      elapsedSeconds: 3600,
    });
    const before = 0.02 + 0.08 + 0.05 + 0.03 + 0.07 + 0.03 + 0.04;
    expect(p.fraction).toBeCloseTo(before + 0.38 * 0.5, 5);
    expect(p.basis).toContain("tasks 6/12");
    expect(p.remainingSeconds).toBeGreaterThan(0);
    expect(p.expectedEndMs).toBe(base.nowMs + p.remainingSeconds * 1000);
  });

  it("uses the default without history and says so", () => {
    const p = estimateProgress({ ...base, phase: "selection", history: { medianSeconds: null, count: 0 } });
    expect(p.expectedTotalSeconds).toBe(DEFAULT_EXPECTED_SECONDS);
    expect(p.basis).toContain("default");
  });

  it("never expects to end before now, and is 100 % when done", () => {
    const late = estimateProgress({ ...base, phase: "measure", elapsedSeconds: 50_000 });
    expect(late.expectedTotalSeconds).toBeGreaterThan(50_000);
    const done = estimateProgress({ ...base, phase: "done", elapsedSeconds: 100 });
    expect(done.fraction).toBe(1);
    expect(done.remainingSeconds).toBe(0);
    expect(done.finished).toBe(true);
  });

  it("moves forward with the time spent in a phase, at most 90 % of its share", () => {
    const early = estimateProgress({
      ...base,
      phase: "plan",
      phaseStartedMs: base.nowMs - 60_000,
      elapsedSeconds: 600,
    });
    const later = estimateProgress({
      ...base,
      phase: "plan",
      phaseStartedMs: base.nowMs - 6_000_000,
      elapsedSeconds: 7000,
    });
    expect(later.fraction).toBeGreaterThan(early.fraction);
    expect(later.phaseFraction).toBe(0.9);
  });
});
