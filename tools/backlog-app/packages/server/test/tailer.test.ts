// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the trace tailer (research R15): partial lines wait for their newline, a
 * multi-byte character split between writes stays whole, a shrunk file restarts, a missing file is
 * no error - and the file is never held open (a Python writer replacing a file next to it while
 * a writer appending to the trace while the tailer reads in a tight loop is never disturbed).
 */

import { appendFileSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { readTraceLines } from "../src/runs/tailer.ts";
import { pythonExecutable, runProcess } from "../src/proc/spawn.ts";

describe("readTraceLines", () => {
  let dir = "";
  let file = "";

  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "backlog-app-tail-"));
    file = join(dir, "trace.jsonl");
  });
  afterEach(() => rmSync(dir, { recursive: true, force: true }));

  it("returns nothing for a missing file", () => {
    expect(readTraceLines(file, 0)).toEqual({ lines: [], offset: 0, restarted: false });
  });

  it("keeps a partial last line for the next read", () => {
    writeFileSync(file, '{"a":1}\n{"b":');
    const first = readTraceLines(file, 0);
    expect(first.lines.map((l) => l.text)).toEqual(['{"a":1}']);
    expect(first.offset).toBe(8);
    appendFileSync(file, "2}\n");
    const second = readTraceLines(file, first.offset);
    expect(second.lines).toEqual([{ text: '{"b":2}', offset: 8, end: 16 }]);
  });

  it("never cuts a multi-byte character written in two parts", () => {
    const text = '{"t":"žluťoučký kůň"}\n';
    const bytes = Buffer.from(text, "utf8");
    // Cut inside the two bytes of "ž".
    writeFileSync(file, bytes.subarray(0, 7));
    const first = readTraceLines(file, 0);
    expect(first.lines).toEqual([]);
    appendFileSync(file, bytes.subarray(7));
    const second = readTraceLines(file, first.offset);
    expect(second.lines[0]!.text).toBe(text.trimEnd());
    expect(second.offset).toBe(bytes.length);
  });

  it("starts again when the file became shorter than the offset", () => {
    writeFileSync(file, "x\ny\n");
    const first = readTraceLines(file, 0);
    writeFileSync(file, "z\n");
    const second = readTraceLines(file, first.offset);
    expect(second.restarted).toBe(true);
    expect(second.lines.map((l) => l.text)).toEqual(["z"]);
  });

  it("reads a large trace in chunks with exact offsets", () => {
    const lines = Array.from({ length: 2000 }, (_, i) => JSON.stringify({ i, pad: "p".repeat(100) }));
    writeFileSync(file, `${lines.join("\n")}\n`);
    const got: string[] = [];
    let offset = 0;
    for (let reads = 0; reads < 100; reads++) {
      const result = readTraceLines(file, offset, 16 * 1024);
      if (result.lines.length === 0) break;
      got.push(...result.lines.map((l) => l.text));
      offset = result.offset;
    }
    expect(got).toEqual(lines);
  });

  it("never disturbs a writer appending to the trace, and gets every line in order", async () => {
    // claude appends to trace.jsonl (it is never replaced); the tailer reads it in a tight loop.
    // Measured fact kept in the fix-log: reads in a tight loop DO collide with an atomic replace
    // of the same file (WinError 5), which is why the app never reads replaced files of a live run.
    writeFileSync(file, "");
    const script = [
      "import json, sys",
      "path = sys.argv[1]",
      "for i in range(2000):",
      "    with open(path, 'a', encoding='utf-8') as f:",
      "        f.write(json.dumps({'i': i, 't': 'žluť'}) + chr(10))",
      "print('ok')",
    ].join("\n");
    const writer = runProcess(pythonExecutable(), ["-c", script, file], { cwd: dir, timeoutMs: 60_000 });
    let done = false;
    void writer.finally(() => (done = true));
    const got: number[] = [];
    let offset = 0;
    /** Reads what is new. */
    const drain = (): void => {
      const result = readTraceLines(file, offset);
      for (const line of result.lines) got.push((JSON.parse(line.text) as { i: number }).i);
      offset = result.offset;
    };
    while (!done) {
      drain();
      await new Promise((resolve) => setImmediate(resolve));
    }
    drain();
    const result = await writer;
    expect(result.stderr).toBe("");
    expect(result.stdout.trim()).toBe("ok");
    expect(got).toEqual(Array.from({ length: 2000 }, (_, i) => i));
  });
});
