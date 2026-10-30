// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the trace normalisation and the run state machine (research R14, R15) on lines
 * shaped like a real run's trace (analysis A2 §1.3, measured on a 342-format trace).
 */

import { describe, expect, it } from "vitest";
import { normalizeTraceLine } from "../src/runs/trace-event.ts";
import { RunState } from "../src/runs/run-state.ts";

/** Byte offset counter for the synthetic trace. */
let offset = 0;

/**
 * Turns objects into trace lines and folds them into a fresh state.
 *
 * @param kind - Run kind.
 * @param lines - Objects (or raw strings) of the trace.
 * @returns The state.
 */
function fold(kind: "item" | "triage", lines: (object | string)[]): RunState {
  offset = 0;
  const state = new RunState(kind);
  for (const line of lines) {
    const text = typeof line === "string" ? line : JSON.stringify(line);
    const end = offset + Buffer.byteLength(text) + 1;
    for (const event of normalizeTraceLine(text, offset, end, "2026-10-30T10:00:00")) state.apply(event);
    offset = end;
  }
  return state;
}

/**
 * A main-thread tool call.
 *
 * @param id - Tool-use id.
 * @param name - Tool name.
 * @param input - Tool input.
 * @param parent - Parent tool-use id (subagents).
 * @returns The assistant line.
 */
function tool(id: string, name: string, input: object, parent: string | null = null): object {
  return {
    type: "assistant",
    message: { id: `msg-${id}`, content: [{ type: "tool_use", id, name, input }] },
    parent_tool_use_id: parent,
    timestamp: "2026-10-30T10:00:01Z",
  };
}

/**
 * The result of a tool call.
 *
 * @param id - Tool-use id.
 * @param text - Result text.
 * @param isError - Failed.
 * @returns The user line.
 */
function result(id: string, text = "ok", isError = false): object {
  return {
    type: "user",
    message: { content: [{ type: "tool_result", tool_use_id: id, content: text, is_error: isError }] },
    parent_tool_use_id: null,
  };
}

/**
 * The separator line of an attempt.
 *
 * @param n - Attempt number.
 * @param kind - `start` or `continue`.
 * @param reason - Why it started.
 * @returns The separator object.
 */
const attempt = (n: number, kind = "start", reason = "-"): object => ({
  type: "backlog_loop.attempt",
  attempt: n,
  kind,
  reason,
  started: `2026-10-30 1${n}:00:00`,
  harness: "claude",
  session_id: "s",
});

describe("normalizeTraceLine", () => {
  it("splits an assistant message into its text and tool calls", () => {
    const events = normalizeTraceLine(
      JSON.stringify({
        type: "assistant",
        message: {
          content: [
            { type: "text", text: "Building now." },
            { type: "tool_use", id: "t1", name: "Bash", input: { command: "cmd /c build.cmd" } },
          ],
        },
        parent_tool_use_id: null,
      }),
      0,
      100,
    );
    expect(events.map((e) => e.kind)).toEqual(["assistant-text", "tool-use"]);
    expect(events[1]!.summary).toBe("cmd /c build.cmd");
  });

  it("turns a cut line into an unparsable event instead of failing", () => {
    const [event] = normalizeTraceLine('{"type":"assistant","message":{"con', 10, 50);
    expect(event!.kind).toBe("unparsable");
    expect(event!.isError).toBe(true);
  });

  it("skips thinking-token noise and keeps results with their cost", () => {
    expect(normalizeTraceLine(JSON.stringify({ type: "system", subtype: "thinking_tokens" }), 0, 1)).toEqual(
      [],
    );
    const [event] = normalizeTraceLine(
      JSON.stringify({ type: "result", subtype: "success", total_cost_usd: 1.234 }),
      0,
      1,
    );
    expect(event!.summary).toContain("$1.23");
  });
});

describe("RunState", () => {
  it("follows the phases of a full run in order", () => {
    const state = fold("item", [
      attempt(1),
      { type: "system", subtype: "init", session_id: "s", model: "m" },
      tool("a", "Bash", { command: "bin/backlog.sh lock acquire --slug x" }),
      result("a"),
      tool("b", "Bash", { command: "bin/backlog.sh verify x --commit abc" }),
      result("b"),
      tool("c", "Skill", { skill: "speckit-specify" }),
      tool("d", "Bash", { command: "bin/backlog.sh start x --feature 345" }),
      tool("e", "Skill", { skill: "speckit-clarify" }),
      tool("f", "Skill", { skill: "speckit-plan" }),
      tool("g", "Skill", { skill: "speckit-tasks" }),
      tool("h", "Skill", { skill: "speckit-analyze" }),
      tool("i", "Skill", { skill: "speckit-implement" }),
      tool("j", "PowerShell", { command: "& .\\build.cmd rebuild" }),
      result("j"),
      tool("k", "Agent", { description: "Independent review" }),
      result("k"),
      tool("l", "Bash", { command: "bin/backlog.sh run-log --outcome closed --slug x" }),
      tool("m", "Bash", { command: "git merge --ff-only 345-x" }),
      tool("n", "Bash", { command: "bin/backlog.sh lock release --slug x" }),
    ]);
    expect(state.timeline.map((t) => t.phase)).toEqual([
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
    ]);
  });

  it("never moves back, and ignores subagents' markers", () => {
    const state = fold("item", [
      tool("a", "Skill", { skill: "speckit-plan" }),
      tool("b", "Skill", { skill: "speckit-specify" }),
      tool("c", "Skill", { skill: "speckit-implement" }, "parent-agent"),
    ]);
    expect(state.phase).toBe("plan");
  });

  it("does not take a review for an Agent call before implement", () => {
    const state = fold("item", [
      tool("a", "Skill", { skill: "speckit-specify" }),
      tool("b", "Agent", { description: "research" }),
    ]);
    expect(state.phase).toBe("specify");
  });

  it("ends on the stop path when the item is blocked, but not on unblock", () => {
    expect(fold("item", [tool("a", "Bash", { command: "bin/backlog.sh block x --reason y" })]).phase).toBe(
      "stopped",
    );
    expect(fold("item", [tool("a", "Bash", { command: "bin/backlog.sh unblock x" })]).phase).toBe("starting");
  });

  it("keeps the phase over a continued attempt and records the attempts", () => {
    const state = fold("item", [
      attempt(1),
      tool("a", "Skill", { skill: "speckit-tasks" }),
      tool("b", "Bash", { command: "sleep" }),
      attempt(2, "continue", "usage-limit"),
      tool("c", "Bash", { command: "ls" }),
    ]);
    expect(state.phase).toBe("tasks");
    expect(state.attempts.map((a) => [a.n, a.kind, a.reason])).toEqual([
      [1, "start", "-"],
      [2, "continue", "usage-limit"],
    ]);
    expect(state.attempts[0]!.ending).toBe("interrupted");
    // The open call of attempt 1 died with its process.
    expect(state.currentTool()?.summary).toBe("ls");
  });

  it("knows the tool in flight and a running GUI probe", () => {
    const state = fold("item", [
      tool("a", "PowerShell", { command: "tools/run_on_hidden_desktop.ps1 probe.ps1" }),
    ]);
    expect(state.currentTool()?.name).toBe("PowerShell");
    expect(state.guiProbeRunning()).toBe(true);
    const after = fold("item", [
      tool("a", "PowerShell", { command: "tools/run_on_hidden_desktop.ps1 x" }),
      result("a"),
    ]);
    expect(after.guiProbeRunning()).toBe(false);
    expect(after.currentTool()).toBeNull();
  });

  it("sums the last result of each attempt as the cost", () => {
    const state = fold("item", [
      attempt(1),
      { type: "result", subtype: "success", total_cost_usd: 0.5 },
      { type: "result", subtype: "success", total_cost_usd: 1.25 },
      attempt(2, "continue", "error"),
      { type: "result", subtype: "success", total_cost_usd: 0.75 },
    ]);
    expect(state.costUsd()).toBe(2);
  });

  it("keeps the last five main-thread messages", () => {
    const lines = Array.from({ length: 7 }, (_, i) => ({
      type: "assistant",
      message: { content: [{ type: "text", text: `m${i}` }] },
      parent_tool_use_id: null,
    }));
    expect(fold("item", lines).recentMessages).toEqual(["m2", "m3", "m4", "m5", "m6"]);
  });

  it("runs a triage from triage to done", () => {
    const state = fold("triage", [
      tool("a", "Skill", { skill: "speckit-plan" }),
      tool("b", "Bash", { command: "bin/backlog.sh lock release" }),
    ]);
    expect(state.timeline.map((t) => t.phase)).toEqual(["triage", "done"]);
  });
});
