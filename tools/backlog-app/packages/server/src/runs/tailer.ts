// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Reading a growing `trace.jsonl` from a byte offset (research R15; analysis A2 §3.2).
 *
 * claude appends to the trace while a run lives. Every read opens the file, reads from the offset
 * to its current end and closes it again - a handle is never kept open (an open handle of another
 * process made the loop's atomic replaces fail, analysis A2 §5.1). Only complete lines are
 * returned; a trailing line without its newline stays for the next read, so a JSON object or a
 * multi-byte character split between two writes is never cut. A file that became shorter than the
 * offset (deleted and recreated by hand) is read again from the start.
 */

import { closeSync, fstatSync, openSync, readSync } from "node:fs";

/** One complete line of the trace. */
export interface TraceLine {
  /** The line's text (UTF-8, without the newline). */
  text: string;
  /** Byte offset of its start. */
  offset: number;
  /** Byte offset just after its newline. */
  end: number;
}

/** The result of one read. */
export interface TailRead {
  /** The complete lines read. */
  lines: TraceLine[];
  /** The offset to read from next time (after the last complete line). */
  offset: number;
  /** True when the file shrank and was read from the start again. */
  restarted: boolean;
}

/** Largest number of bytes read at once (a large trace is read in several reads). */
const CHUNK = 4 * 1024 * 1024;

/**
 * Reads the complete lines after an offset.
 *
 * @param path - The trace file.
 * @param offset - Where the previous read stopped.
 * @param maxBytes - Most bytes to read now (the rest comes with the next call).
 * @returns The lines and the next offset; no lines when the file does not exist (yet).
 */
export function readTraceLines(path: string, offset: number, maxBytes = CHUNK): TailRead {
  let fd: number;
  try {
    fd = openSync(path, "r");
  } catch {
    return { lines: [], offset, restarted: false };
  }
  try {
    const size = fstatSync(fd).size;
    let start = offset;
    let restarted = false;
    if (size < start) {
      start = 0;
      restarted = true;
    }
    const length = Math.min(size - start, maxBytes);
    if (length <= 0) return { lines: [], offset: start, restarted };
    const buffer = Buffer.alloc(length);
    let read = 0;
    while (read < length) {
      const n = readSync(fd, buffer, read, length - read, start + read);
      if (n === 0) break;
      read += n;
    }
    const lines: TraceLine[] = [];
    let lineStart = 0;
    for (let i = 0; i < read; i++) {
      if (buffer[i] !== 0x0a) continue;
      // Decode whole lines only: a multi-byte character is never split.
      const text = buffer.subarray(lineStart, i).toString("utf8").replace(/\r$/, "");
      lines.push({ text, offset: start + lineStart, end: start + i + 1 });
      lineStart = i + 1;
    }
    // A single line longer than the chunk: read it whole next time with a bigger window.
    if (lines.length === 0 && read === maxBytes && read < size - start) {
      return readTraceLines(path, start, maxBytes * 2);
    }
    return { lines, offset: start + lineStart, restarted };
  } finally {
    closeSync(fd);
  }
}
