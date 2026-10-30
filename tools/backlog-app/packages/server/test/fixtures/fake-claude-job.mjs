// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file A fake `claude -p --output-format stream-json` for the AI job tests (run with Node through
 * `BACKLOG_APP_CLAUDE`).
 *
 * It reads the prompt from stdin, writes the prompt and its own arguments to the files named by
 * `FAKE_CLAUDE_STDIN_FILE` and `FAKE_CLAUDE_ARGV_FILE`, and prints stream-json lines shaped like
 * claude 2.1.314's: `system/init`, an assistant `tool_use` (Grep), an assistant text, the
 * `StructuredOutput` tool call and a final `result`. `FAKE_CLAUDE_MODE` chooses the ending:
 * - `ok` (default): a successful result whose `structured_output` is `FAKE_CLAUDE_OUTPUT` (JSON);
 * - `invalid-output`: a successful result whose output does not match any schema;
 * - `slow`: stops after the tool call and waits a minute (for cancel and timeout tests);
 * - `budget`: an `error_max_budget_usd` result and exit code 1.
 */

import { writeFileSync } from "node:fs";

/** The ending chosen by the test. */
const mode = process.env.FAKE_CLAUDE_MODE ?? "ok";

/**
 * Prints one stream-json line.
 *
 * @param value - The event object.
 */
function emit(value) {
  process.stdout.write(`${JSON.stringify(value)}\n`);
}

/**
 * The final result event.
 *
 * @param fields - Fields that differ from a success.
 * @returns The event.
 */
function result(fields) {
  return {
    type: "result",
    subtype: "success",
    is_error: false,
    num_turns: 3,
    total_cost_usd: 0.0123,
    session_id: "fake-session",
    ...fields,
  };
}

/** Collected stdin chunks. */
const chunks = [];
process.stdin.on("data", (chunk) => chunks.push(chunk));
process.stdin.on("end", () => {
  const prompt = Buffer.concat(chunks).toString("utf8");
  if (process.env.FAKE_CLAUDE_STDIN_FILE) writeFileSync(process.env.FAKE_CLAUDE_STDIN_FILE, prompt, "utf8");
  if (process.env.FAKE_CLAUDE_ARGV_FILE) {
    writeFileSync(process.env.FAKE_CLAUDE_ARGV_FILE, JSON.stringify(process.argv.slice(2)), "utf8");
  }
  emit({
    type: "system",
    subtype: "init",
    session_id: "fake-session",
    model: "fake-model",
    tools: ["Read", "Grep", "Glob"],
  });
  emit({
    type: "assistant",
    message: { content: [{ type: "tool_use", id: "toolu_1", name: "Grep", input: { pattern: "LoadStr" } }] },
  });
  emit({
    type: "user",
    message: { content: [{ type: "tool_result", tool_use_id: "toolu_1", content: "src/a.cpp:1: LoadStr" }] },
  });
  if (mode === "slow") {
    // Wait to be cancelled.
    setTimeout(() => process.exit(0), 60_000);
    return;
  }
  emit({ type: "assistant", message: { content: [{ type: "text", text: "Checked the code." }] } });
  if (mode === "budget") {
    emit(
      result({
        subtype: "error_max_budget_usd",
        is_error: true,
        result: undefined,
        errors: ["Reached maximum budget ($2)"],
        total_cost_usd: 2.01,
      }),
    );
    process.exit(1);
  }
  const output =
    mode === "invalid-output" ? { unexpected: true } : JSON.parse(process.env.FAKE_CLAUDE_OUTPUT ?? "{}");
  emit({
    type: "assistant",
    message: { content: [{ type: "tool_use", id: "toolu_2", name: "StructuredOutput", input: output }] },
  });
  emit(result({ result: JSON.stringify(output), structured_output: output }));
  process.exit(0);
});
