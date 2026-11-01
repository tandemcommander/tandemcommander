// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file A fake `claude -p --input-format stream-json --output-format stream-json` for the
 * conversation tests (feature 371; run with Node through `BACKLOG_APP_CLAUDE`).
 *
 * It reads user messages as JSON lines from stdin and answers each one with the lines a real
 * claude 2.1.316 prints in bidirectional mode: `system/init` once (with the session id from
 * `--session-id` or `--resume`), three `stream_event` text deltas, one assistant `tool_use`
 * (Grep), its `user` tool result, the assembled `assistant` text and a `result` (success, cost
 * 0.01). The process stays alive between messages and exits when stdin ends.
 *
 * Every received message is appended to the file named by `FAKE_CHAT_STDIN_FILE`, and the
 * arguments are written to `FAKE_CHAT_ARGV_FILE`. `FAKE_CHAT_MODE` chooses the behaviour:
 * - `ok` (default): a reply "You asked: <text>" with the echo of the message's first line;
 * - `slow`: the deltas arrive 300 ms apart and the result after 2 s (for stop tests);
 * - `budget`: the first result is `error_max_budget_usd` and the process exits 1;
 * - `crash`: exits 3 after the first delta without a result;
 * - `hang`: never answers (for the turn time limit).
 */

import { appendFileSync, writeFileSync } from "node:fs";
import { createInterface } from "node:readline";

/** The mode chosen by the test. */
const mode = process.env.FAKE_CHAT_MODE ?? "ok";

/** The arguments after the script's own path. */
const argv = process.argv.slice(2);

/**
 * The value after a flag.
 *
 * @param flag - The flag.
 * @returns The value or null.
 */
function argOf(flag) {
  const at = argv.indexOf(flag);
  return at >= 0 && at + 1 < argv.length ? argv[at + 1] : null;
}

/** The session id the app chose (or resumed). */
const session = argOf("--session-id") ?? argOf("--resume") ?? "fake-session";

/**
 * Prints one stream-json line.
 *
 * @param value - The event object.
 */
function emit(value) {
  process.stdout.write(`${JSON.stringify(value)}\n`);
}

/**
 * Waits.
 *
 * @param ms - Milliseconds.
 * @returns Resolves after the wait.
 */
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * The text delta event of claude's `--include-partial-messages`.
 *
 * @param text - The text piece.
 * @returns The event.
 */
function delta(text) {
  return {
    type: "stream_event",
    event: { type: "content_block_delta", index: 0, delta: { type: "text_delta", text } },
    session_id: session,
  };
}

if (process.env.FAKE_CHAT_ARGV_FILE)
  writeFileSync(process.env.FAKE_CHAT_ARGV_FILE, JSON.stringify(argv), "utf8");

emit({
  type: "system",
  subtype: "init",
  session_id: session,
  model: "fake-model",
  tools: ["Read", "Grep", "Glob"],
});

/** Messages answered so far. */
let turns = 0;
/** Messages are answered one after the other; a later one waits for the earlier answer. */
let chain = Promise.resolve();

/**
 * Answers one message.
 *
 * @param text - The message's text.
 */
async function answer(text) {
  turns++;
  if (process.env.FAKE_CHAT_STDIN_FILE)
    appendFileSync(process.env.FAKE_CHAT_STDIN_FILE, `${text}\n---\n`, "utf8");
  if (mode === "hang") return;
  const pause = mode === "slow" ? 300 : 0;
  const firstLine = text.split("\n").find((line) => line.trim() !== "") ?? "";
  const reply = `You asked: ${firstLine.slice(0, 120)}`;
  emit(delta("You "));
  if (mode === "crash") {
    process.exit(3);
  }
  await sleep(pause);
  emit(delta("asked: "));
  await sleep(pause);
  emit({
    type: "assistant",
    message: {
      content: [{ type: "tool_use", id: `toolu_${turns}`, name: "Grep", input: { pattern: "LoadStr" } }],
    },
    session_id: session,
  });
  emit({
    type: "user",
    message: {
      content: [{ type: "tool_result", tool_use_id: `toolu_${turns}`, content: "src/a.cpp:1: LoadStr" }],
    },
    session_id: session,
  });
  await sleep(pause);
  emit(delta(firstLine.slice(0, 120)));
  emit({ type: "assistant", message: { content: [{ type: "text", text: reply }] }, session_id: session });
  if (mode === "slow") await sleep(2000);
  if (mode === "budget") {
    emit({
      type: "result",
      subtype: "error_max_budget_usd",
      is_error: true,
      errors: ["Reached maximum budget ($5)"],
      total_cost_usd: 5.01,
      session_id: session,
    });
    process.exit(1);
  }
  emit({
    type: "result",
    subtype: "success",
    is_error: false,
    num_turns: turns,
    total_cost_usd: 0.01 * turns,
    result: reply,
    session_id: session,
  });
}

/** Reads the maintainer's messages line by line. */
const lines = createInterface({ input: process.stdin });
lines.on("line", (line) => {
  if (!line.trim()) return;
  let message;
  try {
    message = JSON.parse(line);
  } catch {
    return;
  }
  const content = message?.message?.content;
  const text =
    typeof content === "string"
      ? content
      : Array.isArray(content)
        ? content.map((c) => c.text ?? "").join("")
        : "";
  chain = chain.then(() => answer(text));
});
lines.on("close", () => {
  void chain.then(() => process.exit(0));
});
