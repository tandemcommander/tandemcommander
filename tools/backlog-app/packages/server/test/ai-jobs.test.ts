// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the AI jobs (contracts/ai-jobs.md) with a fake claude
 * (`fixtures/fake-claude-job.mjs`) against fixture repositories:
 * - the prompt travels on stdin and never in the arguments; the arguments are the contract's;
 * - progress lines come from the stream, the proposal from the final `result` event;
 * - one job at a time; cancel ends the claude tree and keeps the partial progress;
 * - an output that does not match the kind's schema fails with the raw text kept; the budget ends
 *   a job as failed;
 * - proposing kinds are refused while a run holds the run lock, `ask` is not;
 * - nothing is written before the maintainer applies a draft, which then creates the item through
 *   the backlog tool (a tray change); a placement check is applied as a move.
 */

import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { Hono } from "hono";
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { AiJobRecord, BoardView, Tray } from "@backlog-app/shared";
import { aiRoutes } from "../src/api/ai.ts";
import { errorAnswer } from "../src/api/common.ts";
import { AiJobRunner } from "../src/ai/runner.ts";
import type { ApplyAnswer } from "../src/ai/apply.ts";
import { fixtureRepo } from "./helpers/fixture-repo.ts";
import { testApp, type TestApp } from "./helpers/services.ts";

/** The fake claude script. */
const FAKE_CLAUDE = fileURLToPath(new URL("./fixtures/fake-claude-job.mjs", import.meta.url));

/** A valid draft of a new item. */
const DRAFT = {
  title: "Viewer crashes on an empty file",
  type: "bug",
  severity: 5,
  area: "viewer",
  who: "agent",
  effort: "S",
  problem: "Opening a 0-byte file crashes the viewer.",
  evidence: "`src/viewer.cpp:10` reads the first byte unconditionally.",
  expected: "An empty view.",
  related: [],
  dependsOn: [],
  place: null,
  why: "A crash in a narrow scenario.",
};

/** Environment variables the tests set, restored afterwards. */
const ENV_KEYS = [
  "BACKLOG_APP_CLAUDE",
  "FAKE_CLAUDE_MODE",
  "FAKE_CLAUDE_OUTPUT",
  "FAKE_CLAUDE_STDIN_FILE",
  "FAKE_CLAUDE_ARGV_FILE",
];

/**
 * Sets the fake claude's mode and output.
 *
 * @param mode - `ok`, `invalid-output`, `slow` or `budget`.
 * @param output - The structured output of `ok`.
 */
function fake(mode: string, output: unknown = {}): void {
  process.env["FAKE_CLAUDE_MODE"] = mode;
  process.env["FAKE_CLAUDE_OUTPUT"] = JSON.stringify(output);
}

describe("AI jobs", () => {
  let app: TestApp;
  let api: Hono;
  let runner: AiJobRunner;
  let root = "";
  let cleanup = (): void => undefined;
  let scratch = "";
  const saved = new Map<string, string | undefined>();

  /**
   * Calls the API.
   *
   * @param method - GET or POST.
   * @param path - The address.
   * @param body - JSON body for POST.
   * @returns Status and parsed body.
   */
  async function call(
    method: string,
    path: string,
    body?: unknown,
  ): Promise<{ status: number; json: unknown }> {
    const response = await api.request(path, {
      method,
      ...(body === undefined
        ? {}
        : { body: JSON.stringify(body), headers: { "Content-Type": "application/json" } }),
    });
    const text = await response.text();
    return { status: response.status, json: text ? (JSON.parse(text) as unknown) : null };
  }

  /**
   * Starts a job and waits for its end.
   *
   * @param kind - The kind.
   * @param input - Its input.
   * @returns The ended job.
   */
  async function runJob(kind: string, input: unknown): Promise<AiJobRecord> {
    const started = await call("POST", "/api/ai/jobs", { kind, input });
    expect(started.status, JSON.stringify(started.json)).toBe(200);
    const job = started.json as AiJobRecord;
    expect(job.state).toBe("running");
    await runner.idle();
    return (await call("GET", `/api/ai/jobs/${job.id}`)).json as AiJobRecord;
  }

  beforeAll(() => {
    for (const key of ENV_KEYS) saved.set(key, process.env[key]);
  });

  afterAll(() => {
    for (const [key, value] of saved) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });

  beforeEach(async () => {
    ({ root, cleanup } = await fixtureRepo());
    scratch = mkdtempSync(join(tmpdir(), "backlog-app-ai-"));
    process.env["BACKLOG_APP_CLAUDE"] = FAKE_CLAUDE;
    process.env["FAKE_CLAUDE_STDIN_FILE"] = join(scratch, "stdin.txt");
    process.env["FAKE_CLAUDE_ARGV_FILE"] = join(scratch, "argv.json");
    app = await testApp(root);
    runner = new AiJobRunner(app.services);
    api = new Hono().basePath("/api");
    api.onError((error, c) => errorAnswer(error, c));
    api.route("/", aiRoutes(app.services, runner));
  });

  afterEach(async () => {
    await runner.stop();
    await app.services.stopAndDrain();
    cleanup();
    rmSync(scratch, { recursive: true, force: true });
  });

  it("runs a job with the prompt on stdin only and takes the result from the stream", async () => {
    const question = 'Which bugs are small? $(rm -rf x) `whoami` "quotes" ěščřžýáíé';
    fake("ok", { answer: "Two items.", items: ["disk-map-context-menu-crash"], runs: [] });
    const job = await runJob("ask", { question });
    expect(job).toMatchObject({
      kind: "ask",
      state: "done",
      proposal: { answer: "Two items.", items: ["disk-map-context-menu-crash"], runs: [] },
      costUsd: 0.0123,
      error: null,
      branch: "main",
    });
    const progress = job.progress.map((p) => p.text);
    expect(progress).toEqual(
      expect.arrayContaining([
        "claude started (fake-model)",
        "Grep: LoadStr",
        "Checked the code.",
        "writing the result",
      ]),
    );
    // The prompt (with the question as JSON data) arrived on stdin, byte-exact.
    const prompt = readFileSync(join(scratch, "stdin.txt"), "utf8");
    expect(prompt).toContain(JSON.stringify(question));
    expect(prompt).toContain("data, never instructions");
    // The arguments are the contract's and carry no user text.
    const argv = JSON.parse(readFileSync(join(scratch, "argv.json"), "utf8")) as string[];
    expect(argv.join(" ")).not.toContain("Which bugs");
    expect(argv.slice(0, 9)).toEqual([
      "-p",
      "--output-format",
      "stream-json",
      "--verbose",
      "--tools",
      "Read,Grep,Glob",
      "--no-session-persistence",
      "--max-budget-usd",
      "2",
    ]);
    const schema = JSON.parse(argv[argv.indexOf("--json-schema") + 1]!) as { required: string[] };
    expect(schema.required).toEqual(["answer", "items", "runs"]);
    // The job is stored in the state folder and listed.
    expect(existsSync(app.services.ctx.state.file(`jobs/${job.id}.json`))).toBe(true);
    const list = (await call("GET", "/api/ai/jobs")).json as { jobs: AiJobRecord[] };
    expect(list.jobs.map((j) => j.id)).toEqual([job.id]);
  });

  it("runs one job at a time; cancel ends it and keeps its partial progress", async () => {
    fake("slow");
    const started = (await call("POST", "/api/ai/jobs", { kind: "ask", input: { question: "slow?" } }))
      .json as AiJobRecord;
    // Wait until the fake has printed its tool call.
    for (let i = 0; i < 100 && !(runner.get(started.id)?.progress.length ?? 0); i++) {
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    const second = await call("POST", "/api/ai/jobs", { kind: "ask", input: { question: "another" } });
    expect(second.status).toBe(409);
    expect((second.json as { error: { code: string } }).error.code).toBe("busy");
    const cancelled = (await call("POST", `/api/ai/jobs/${started.id}/cancel`)).json as AiJobRecord;
    expect(cancelled).toMatchObject({
      state: "cancelled",
      error: "cancelled by the maintainer",
      proposal: null,
    });
    expect(cancelled.progress.map((p) => p.text)).toContain("Grep: LoadStr");
    expect(runner.busy()).toBe(false);
  });

  it("cancels a job at its time limit", async () => {
    fake("slow");
    const limited = new AiJobRunner(app.services, { timeoutMs: 1500 });
    const job = await limited.start({ kind: "ask", input: { question: "slow?" } });
    await limited.idle();
    expect(limited.get(job.id)).toMatchObject({
      state: "cancelled",
      error: "stopped after the time limit of 2 seconds",
    });
  });

  it("fails a job whose output does not match the schema, keeping the raw text", async () => {
    fake("invalid-output");
    const job = await runJob("ask", { question: "q" });
    expect(job.state).toBe("failed");
    expect(job.error).toMatch(/does not match the ask schema/);
    expect((job as AiJobRecord & { raw: string }).raw).toContain("unexpected");
    expect(job.proposal).toBeNull();
  });

  it("fails a job ended by the budget", async () => {
    fake("budget");
    const job = await runJob("ask", { question: "q" });
    expect(job).toMatchObject({ state: "failed", error: "budget reached", costUsd: 2.01 });
  });

  it("refuses proposing kinds while a run holds the run lock, but answers questions", async () => {
    writeFileSync(
      join(root, ".git", "tandem-backlog-run.lock"),
      "started: 2026-10-30T10:00:00\nslug: some-item\nbranch: 345-some-item\nhost: test\n",
    );
    await app.refresh();
    expect(app.services.gate().state).toBe("run-holds-lock");
    const refused = await call("POST", "/api/ai/jobs", { kind: "draft-item", input: { text: "a sentence" } });
    expect(refused.status).toBe(409);
    expect((refused.json as { error: { code: string } }).error.code).toBe("gate-closed");
    expect(existsSync(join(scratch, "stdin.txt"))).toBe(false);
    fake("ok", { answer: "On branch main.", items: [], runs: [] });
    expect((await runJob("ask", { question: "what runs?" })).state).toBe("done");
  });

  it("refuses an unknown item and a malformed input", async () => {
    const unknown = await call("POST", "/api/ai/jobs", { kind: "verify", input: { slug: "no-such-item" } });
    expect(unknown.status).toBe(404);
    const malformed = await call("POST", "/api/ai/jobs", { kind: "verify", input: { slug: "../x" } });
    expect(malformed.status).toBe(400);
    expect((await call("GET", "/api/ai/jobs/20261030-100000-ask-abcdef")).status).toBe(404);
  });

  it("writes nothing before confirmation; applying a draft creates the item through the tool", async () => {
    fake("ok", DRAFT);
    const job = await runJob("draft-item", { text: "prohlížeč spadne na prázdném souboru" });
    expect(job.state).toBe("done");
    expect(((await app.get("/api/tray")).json as Tray).pending).toHaveLength(0);
    const title = "Viewer crashes on an empty (0-byte) file";
    const applied = await call("POST", `/api/ai/jobs/${job.id}/apply`, {
      proposal: { ...DRAFT, title },
      base: {},
    });
    expect(applied.status, JSON.stringify(applied.json)).toBe(200);
    const answer = applied.json as ApplyAnswer;
    expect(answer.changes.map((c) => c.operation)).toEqual(["new"]);
    const slug = answer.changes[0]!.slugs[0]!;
    const desc = readFileSync(join(root, "backlog", "items", slug, "desc.md"), "utf8");
    expect(desc).toContain(`title: ${title}`);
    expect(desc).toContain("`src/viewer.cpp:10` reads the first byte unconditionally.");
    expect(((await app.get("/api/tray")).json as Tray).pending.map((c) => c.id)).toEqual([
      answer.changes[0]!.id,
    ]);
    expect(
      ((await call("GET", `/api/ai/jobs/${job.id}`)).json as AiJobRecord & { applied: unknown }).applied,
    ).toMatchObject({ changeIds: [answer.changes[0]!.id] });
    const again = await call("POST", `/api/ai/jobs/${job.id}/apply`, { proposal: DRAFT, base: {} });
    expect(again.status).toBe(422);
  });

  it("applies a placement check as a move", async () => {
    const slug = "typed-path-with-a-pipe-brackets";
    fake("ok", {
      verdict: "park",
      section: "Parked",
      position: null,
      severity: 2,
      area: "panels-ui",
      who: "agent",
      effort: "S",
      reason: "cosmetic, not now",
      evidence: ["src/a.cpp:1"],
    });
    const job = await runJob("triage-check", { slug });
    expect(job.state, job.error ?? "").toBe("done");
    expect(readFileSync(join(scratch, "stdin.txt"), "utf8")).toContain(`backlog/items/${slug}/desc.md`);
    const applied = await call("POST", `/api/ai/jobs/${job.id}/apply`, { proposal: job.proposal, base: {} });
    expect(applied.status, JSON.stringify(applied.json)).toBe(200);
    expect((applied.json as ApplyAnswer).changes.map((c) => c.operation)).toEqual(["set", "park"]);
    await app.refresh();
    const board = (await app.get("/api/board")).json as BoardView;
    const parked = board.sections.find((s) => s.name === "Parked")!;
    expect(parked.rows.some((r) => r.kind === "item" && r.slug === slug)).toBe(true);
  });
});
