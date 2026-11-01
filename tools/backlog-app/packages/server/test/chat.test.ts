// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the conversation about an item (feature 371, contracts/chat.md) with the fake
 * `fake-claude-chat.mjs`: a turn streams deltas and ends done with its cost; the second message
 * reuses the process; after `reset` a new session id; after the idle end the next message
 * resumes the session (`--resume`); `busy` while a turn runs; `stop` ends the turn `stopped`; a
 * crash ends it `failed` with the transcript kept; the context block goes on stdin and names the
 * item's data, never on the command line; an unknown item is refused.
 */

import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { Conversation, Turn } from "@backlog-app/shared";
import { ChatService, chatArgs, readChatLine, type ChatEvent } from "../src/chat/service.ts";
import { fixtureRepo } from "./helpers/fixture-repo.ts";
import { testApp, type TestApp } from "./helpers/services.ts";

/** The fake claude of the conversation tests. */
const FAKE = fileURLToPath(new URL("./fixtures/fake-claude-chat.mjs", import.meta.url));

/** The fixture's open item of Next. */
const FTP = "ftp-per-server-encoding-flag";

/**
 * Waits until a condition holds.
 *
 * @param condition - The condition.
 * @param timeoutMs - The limit.
 */
async function until(condition: () => boolean, timeoutMs = 10_000): Promise<void> {
  const end = Date.now() + timeoutMs;
  while (!condition()) {
    if (Date.now() > end) throw new Error("timed out");
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
}

describe("conversation", () => {
  let app: TestApp;
  let root = "";
  let cleanup = (): void => undefined;
  let scratch = "";
  let chat: ChatService;
  let events: ChatEvent[] = [];
  let unsubscribe = (): void => undefined;

  beforeAll(() => {
    scratch = mkdtempSync(join(tmpdir(), "backlog-app-chat-"));
    process.env["BACKLOG_APP_CLAUDE"] = FAKE;
    process.env["FAKE_CHAT_STDIN_FILE"] = join(scratch, "stdin.txt");
    process.env["FAKE_CHAT_ARGV_FILE"] = join(scratch, "argv.json");
  });

  afterAll(() => {
    delete process.env["BACKLOG_APP_CLAUDE"];
    delete process.env["FAKE_CHAT_STDIN_FILE"];
    delete process.env["FAKE_CHAT_ARGV_FILE"];
    rmSync(scratch, { recursive: true, force: true });
  });

  beforeEach(async () => {
    ({ root, cleanup } = await fixtureRepo());
    app = await testApp(root);
    chat = new ChatService(app.services, { idleMs: 400, turnTimeoutMs: 3000, maxLive: 2 });
    events = [];
    unsubscribe = chat.subscribe((e) => events.push(e));
    rmSync(join(scratch, "stdin.txt"), { force: true });
    delete process.env["FAKE_CHAT_MODE"];
  });

  afterEach(async () => {
    unsubscribe();
    await chat.stopAll();
    await app.services.stopAndDrain();
    cleanup();
  });

  /**
   * The conversation's turns as the service has them now.
   *
   * @returns The turns.
   */
  const turns = (): Turn[] => chat.get(FTP).turns;

  it("streams a reply, keeps the process for the next message, and records the cost", async () => {
    const turn = await chat.send(FTP, "What is this about?");
    expect(turn).toMatchObject({ id: 1, state: "running", user: "What is this about?" });
    await until(() => turns()[0]?.state === "done");
    expect(turns()[0]).toMatchObject({ assistant: "You asked: What is this about?", costUsd: 0.01 });
    expect(events.filter((e) => e.kind === "delta").length).toBeGreaterThanOrEqual(2);
    expect(events.some((e) => e.kind === "progress" && e.text.startsWith("Grep:"))).toBe(true);
    expect(events.at(-1)).toMatchObject({ kind: "done", turn: 1 });
    // The context block went on stdin: the item's data, never the command line.
    const stdin = readFileSync(join(scratch, "stdin.txt"), "utf8");
    expect(stdin).toContain(`"slug": "${FTP}"`);
    expect(stdin).toContain("FTP per-server encoding flag");
    expect(stdin).toContain("# The maintainer's message");
    const argv = JSON.parse(readFileSync(join(scratch, "argv.json"), "utf8")) as string[];
    expect(argv).toContain("--session-id");
    expect(argv.join(" ")).not.toContain(FTP);
    expect(argv.join(" ")).not.toContain("What is this about");
    expect(argv).toContain("--allowedTools");
    expect(argv[argv.indexOf("--allowedTools") + 1]).toContain("Bash(git log:*)");
    expect(argv).not.toContain("--no-session-persistence");
    // The second message reuses the live process (the same session, no new argv file write).
    const liveBefore = chat.liveSlugs();
    expect(liveBefore).toEqual([FTP]);
    await chat.send(FTP, "And the second?");
    await until(() => turns()[1]?.state === "done");
    expect(turns()[1]?.assistant).toBe("You asked: And the second?");
    expect(readFileSync(join(scratch, "stdin.txt"), "utf8").split("---").length).toBe(3);
    expect(chat.get(FTP).costUsd).toBeCloseTo(0.03, 3);
    // The transcript is on disk and survives a new service.
    const stored = app.services.ctx.state.readJson(`chats/${FTP}.json`, (await import("@backlog-app/shared")).ConversationSchema.nullable(), null);
    expect(stored?.turns.length).toBe(2);
  });

  it("resumes the session with a new process after the idle end, and starts afresh after reset", async () => {
    await chat.send(FTP, "one");
    await until(() => turns()[0]?.state === "done");
    const session = chat.get(FTP).sessionId;
    await until(() => chat.liveSlugs().length === 0, 5000);
    await chat.send(FTP, "two");
    await until(() => turns()[1]?.state === "done");
    const argv = JSON.parse(readFileSync(join(scratch, "argv.json"), "utf8")) as string[];
    expect(argv).toContain("--resume");
    expect(argv[argv.indexOf("--resume") + 1]).toBe(session);
    const fresh = await chat.reset(FTP);
    expect(fresh.turns).toEqual([]);
    expect(fresh.sessionId).not.toBe(session);
    expect(chat.liveSlugs()).toEqual([]);
    const archived = existsSync(app.services.ctx.state.file("chats"))
      ? (await import("node:fs")).readdirSync(app.services.ctx.state.file("chats")).filter((n) => n.startsWith(`${FTP}.`))
      : [];
    expect(archived.length).toBe(1);
  });

  it("refuses a second message while a reply is being written, and stop ends it as stopped", async () => {
    process.env["FAKE_CHAT_MODE"] = "slow";
    await chat.send(FTP, "slow one");
    await expect(chat.send(FTP, "too early")).rejects.toMatchObject({ code: "busy" });
    await until(() => (turns()[0]?.assistant.length ?? 0) > 0 || events.some((e) => e.kind === "delta"));
    const stopped = await chat.stop(FTP);
    expect(stopped).toMatchObject({ id: 1, state: "stopped" });
    expect(turns()[0]?.error).toBe("stopped by the maintainer");
    expect(chat.liveSlugs()).toEqual([]);
    // The next message resumes.
    delete process.env["FAKE_CHAT_MODE"];
    await chat.send(FTP, "after the stop");
    await until(() => turns()[1]?.state === "done");
    const argv = JSON.parse(readFileSync(join(scratch, "argv.json"), "utf8")) as string[];
    expect(argv).toContain("--resume");
  });

  it("ends a turn failed when claude crashes or reaches its budget, keeping the transcript", async () => {
    process.env["FAKE_CHAT_MODE"] = "crash";
    await chat.send(FTP, "crash");
    await until(() => turns()[0]?.state === "failed");
    expect(turns()[0]?.error).toMatch(/exit code 3/);
    expect(turns()[0]?.assistant).toBe("You ");
    process.env["FAKE_CHAT_MODE"] = "budget";
    await chat.send(FTP, "budget");
    await until(() => turns()[1]?.state === "failed");
    expect(turns()[1]?.error).toMatch(/budget reached/);
    expect(chat.get(FTP).turns.length).toBe(2);
  });

  it("stops a turn after its time limit", async () => {
    process.env["FAKE_CHAT_MODE"] = "hang";
    await chat.send(FTP, "hang");
    await until(() => turns()[0]?.state === "stopped", 8000);
    expect(turns()[0]?.error).toMatch(/time limit/);
  });

  it("refuses an unknown item and more live conversations than the limit", async () => {
    await expect(chat.send("no-such-item", "x")).rejects.toMatchObject({ code: "not-found" });
    process.env["FAKE_CHAT_MODE"] = "slow";
    await chat.send(FTP, "a");
    await chat.send("disk-map-context-menu-crash", "b");
    await expect(chat.send("ship-network-plugin", "c")).rejects.toMatchObject({ code: "busy" });
  });

  it("serves the routes: transcript, context, message, stop, reset", async () => {
    const empty = (await app.get(`/api/items/${FTP}/chat`)).json as Conversation;
    expect(empty.turns).toEqual([]);
    const context = (await app.get(`/api/items/${FTP}/chat/context`)).json as { item: { slug: string }; branch: string };
    expect(context.item.slug).toBe(FTP);
    expect(context.branch).toBe("main");
    const sent = await app.post(`/api/items/${FTP}/chat/messages`, { text: "hello" });
    expect(sent.status, JSON.stringify(sent.json)).toBe(200);
    await until(() => (app.services.chat.get(FTP).turns[0]?.state ?? "") === "done");
    const after = (await app.get(`/api/items/${FTP}/chat`)).json as Conversation;
    expect(after.turns[0]).toMatchObject({ state: "done", assistant: "You asked: hello" });
    expect((await app.post(`/api/items/${FTP}/chat/messages`, { text: "" })).status).toBe(400);
    expect((await app.post(`/api/items/${FTP}/chat/reset`, {})).status).toBe(200);
    expect(((await app.get(`/api/items/${FTP}/chat`)).json as Conversation).turns).toEqual([]);
    expect((await app.get("/api/items/no-such-item/chat/context")).status).toBe(404);
    await app.services.chat.stopAll();
  });
});

describe("chat line reading and arguments", () => {
  it("reads deltas, texts, tool uses and results", () => {
    expect(
      readChatLine(JSON.stringify({ type: "stream_event", event: { type: "content_block_delta", delta: { type: "text_delta", text: "Hi" } } })),
    ).toEqual({ delta: "Hi" });
    expect(readChatLine(JSON.stringify({ type: "assistant", message: { content: [{ type: "text", text: "Full" }] } }))).toEqual({ text: "Full" });
    expect(
      readChatLine(JSON.stringify({ type: "assistant", message: { content: [{ type: "tool_use", id: "t", name: "Grep", input: { pattern: "x" } }] } })),
    ).toMatchObject({ progress: expect.stringContaining("Grep") });
    expect(readChatLine(JSON.stringify({ type: "result", subtype: "success", is_error: false, result: "ok", total_cost_usd: 0.5 }))).toEqual({
      result: { subtype: "success", isError: false, text: "ok", errors: [], cost: 0.5 },
    });
    expect(readChatLine("not json")).toBeNull();
  });

  it("builds the arguments without user text, read-only tools, session or resume", () => {
    const fresh = chatArgs("abc", false, 5, null);
    expect(fresh).toContain("--session-id");
    expect(fresh).toContain("--include-partial-messages");
    expect(fresh[fresh.indexOf("--tools") + 1]).toBe("Read,Grep,Glob,Bash");
    expect(fresh[fresh.indexOf("--allowedTools") + 1]).not.toContain("Edit");
    expect(fresh).not.toContain("--no-session-persistence");
    const later = chatArgs("abc", true, 5, "claude-haiku-5-5");
    expect(later).toContain("--resume");
    expect(later).toContain("--model");
  });
});
