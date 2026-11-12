// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Test of the trace stream's catch-up (feature 426, contracts/trace-stream.md): a trace
 * larger than one page reaches the client whole - every event of every line, also the second and
 * later events of a line - and its fold gives the phase the whole trace gives. Before 426 the
 * catch-up stopped after the first 1 MB page (the live page of a run showed "Specify").
 */

import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { normalizeTraceLine, RunStory, type TraceEvent } from "@backlog-app/shared";
import { fixtureRepo } from "./helpers/fixture-repo.ts";
import { testApp, type TestApp } from "./helpers/services.ts";

/** The run's id (a trace folder). */
const DIR = "20261112-140713-claude-some-item";

/**
 * A main-thread assistant line.
 *
 * @param content - Its content parts.
 * @returns The line's object.
 */
function assistant(content: unknown[]): unknown {
  return { type: "assistant", message: { content }, parent_tool_use_id: null };
}

/**
 * The lines of a run that goes through every phase, padded with long tool results so that the
 * file is about 2.5 MB; some assistant lines hold a text and a tool call (two events).
 *
 * @returns The lines.
 */
function traceLines(): string[] {
  const lines: unknown[] = [
    { type: "backlog_loop.attempt", attempt: 1, kind: "start", reason: "-", started: "2026-11-12 14:07:13" },
  ];
  const pad = "x".repeat(2000);
  let id = 0;
  /**
   * A tool call (with a text before it in the same line) and a long result.
   *
   * @param name - The tool.
   * @param input - Its input.
   */
  const call = (name: string, input: unknown): void => {
    id++;
    lines.push(
      assistant([
        { type: "text", text: `step ${id}` },
        { type: "tool_use", id: `t${id}`, name, input },
      ]),
    );
    lines.push({
      type: "user",
      message: { content: [{ type: "tool_result", tool_use_id: `t${id}`, content: pad }] },
      parent_tool_use_id: null,
    });
  };
  call("Bash", { command: "bin/backlog.sh lock acquire --slug some-item" });
  call("Skill", { skill: "speckit-specify" });
  // The first megabyte ends during specify, as in run 425.
  for (let i = 0; i < 500; i++) call("Read", { file_path: `E:/r/f${i}.md` });
  for (const skill of [
    "speckit-clarify",
    "speckit-plan",
    "speckit-tasks",
    "speckit-analyze",
    "speckit-implement",
  ])
    call("Skill", { skill });
  for (let i = 0; i < 500; i++) call("Read", { file_path: `E:/r/g${i}.md` });
  call("Agent", { description: "Independent review", prompt: "review" });
  return lines.map((l) => JSON.stringify(l));
}

/**
 * The SSE messages of a finished stream.
 *
 * @param text - The body.
 * @returns The messages: event name, id and parsed data.
 */
function parseSse(text: string): { event: string; id: string | null; data: unknown }[] {
  const out: { event: string; id: string | null; data: unknown }[] = [];
  for (const block of text.split(/\r?\n\r?\n/)) {
    if (!block.trim()) continue;
    let event = "message";
    let id: string | null = null;
    const data: string[] = [];
    for (const line of block.split(/\r?\n/)) {
      if (line.startsWith("event:")) event = line.slice(6).trim();
      else if (line.startsWith("id:")) id = line.slice(3).trim();
      else if (line.startsWith("data:")) data.push(line.slice(5).trimStart());
    }
    out.push({ event, id, data: data.length ? JSON.parse(data.join("\n")) : null });
  }
  return out;
}

describe("the trace stream", () => {
  let app: TestApp;
  let root = "";
  let cleanup = (): void => undefined;

  beforeEach(async () => {
    ({ root, cleanup } = await fixtureRepo());
    app = await testApp(root);
  });
  afterEach(async () => {
    await app.services.stopAndDrain();
    cleanup();
  });

  it("sends every event of a trace larger than one page, every event of a line too", async () => {
    const folder = join(root, ".agent-traces", DIR);
    mkdirSync(folder, { recursive: true });
    const lines = traceLines();
    const text = `${lines.join("\n")}\n`;
    writeFileSync(join(folder, "trace.jsonl"), text);
    expect(Buffer.byteLength(text)).toBeGreaterThan(2 * 1024 * 1024);
    // What the file holds, folded the way the server folds it.
    const expected: TraceEvent[] = [];
    let offset = 0;
    for (const line of lines) {
      const end = offset + Buffer.byteLength(line) + 1;
      expected.push(...normalizeTraceLine(line, offset, end, null));
      offset = end;
    }
    const whole = new RunStory("item");
    for (const e of expected) whole.apply(e);
    expect(whole.state.phase).toBe("review");

    const response = await app.api.request(`/api/runs/${DIR}/stream`);
    expect(response.status).toBe(200);
    const messages = parseSse(await response.text());
    const events = messages
      .filter((m) => m.event === "trace" || m.event === "attempt")
      .map((m) => m.data as TraceEvent);
    expect(messages.at(-1)?.event).toBe("ended");
    expect(events).toHaveLength(expected.length);
    expect(events.map((e) => [e.offset, e.kind])).toEqual(expected.map((e) => [e.offset, e.kind]));
    const story = new RunStory("item");
    for (const e of events) story.apply(e);
    expect(story.state.phase).toBe("review");
    // Only the last event of a line carries the id (a resume never skips the rest of a line).
    const withId = messages.filter((m) => m.id !== null && (m.event === "trace" || m.event === "attempt"));
    expect(withId).toHaveLength(lines.length);
    expect(new Set(withId.map((m) => m.id)).size).toBe(lines.length);
  });

  it("resumes after the last whole line it sent", async () => {
    const folder = join(root, ".agent-traces", DIR);
    mkdirSync(folder, { recursive: true });
    const lines = traceLines().slice(0, 20);
    writeFileSync(join(folder, "trace.jsonl"), `${lines.join("\n")}\n`);
    const first = parseSse(await (await app.api.request(`/api/runs/${DIR}/stream`)).text());
    const ids = first.filter((m) => m.id !== null).map((m) => m.id!);
    const resumeAt = ids[5]!;
    const rest = parseSse(
      await (
        await app.api.request(`/api/runs/${DIR}/stream`, { headers: { "Last-Event-ID": resumeAt } })
      ).text(),
    ).filter((m) => m.event === "trace" || m.event === "attempt");
    const all = first.filter((m) => m.event === "trace" || m.event === "attempt");
    const after = all.slice(all.findIndex((m) => m.id === resumeAt) + 1);
    expect(rest.map((m) => (m.data as TraceEvent).offset)).toEqual(
      after.map((m) => (m.data as TraceEvent).offset),
    );
  });
});
