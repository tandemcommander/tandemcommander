// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Normalisation of one line of a run's `trace.jsonl` into the events the views show
 * (data-model *Trace event*; analysis A2 §1.4).
 *
 * A trace holds claude's `stream-json` output unchanged plus one `backlog_loop.attempt` separator
 * line before every attempt (feature 342). One line may carry several content blocks (an assistant
 * message with text and tool calls), so a line becomes zero or more events. A line that is not
 * JSON (a claude killed mid-write) becomes an `unparsable` event - shown, never fatal.
 */

import type { TraceEvent, TraceEventKind } from "../schemas/runs.ts";

/** Longest text kept in an event (the full line is available on demand). */
const MAX_TEXT = 4000;

/** A raw object of the stream. */
type Raw = Record<string, unknown>;

/**
 * A value as text for a summary: strings and numbers as they are, anything else the fallback (an
 * object of an unexpected shape is never turned into `[object Object]`).
 *
 * @param value - Any value of the stream.
 * @param fallback - Text for anything else.
 * @returns The text.
 */
function str(value: unknown, fallback: string): string {
  return typeof value === "string" || typeof value === "number" ? String(value) : fallback;
}

/**
 * Shortens a text for an event.
 *
 * @param text - Any text.
 * @param max - Most characters kept.
 * @returns The text, cut with an ellipsis when longer.
 */
export function clip(text: string, max = MAX_TEXT): string {
  return text.length > max ? `${text.slice(0, max)}…` : text;
}

/**
 * A one-line summary of a tool call's input: the command, the file, the description or the skill.
 *
 * @param name - The tool's name.
 * @param input - Its input object.
 * @returns The summary.
 */
export function toolSummary(name: string, input: unknown): string {
  const data = (input ?? {}) as Raw;
  /**
   * A string field of the input.
   *
   * @param key - The field.
   * @returns Its text, or null when it is not a string.
   */
  const pick = (key: string): string | null => {
    const value = data[key];
    return typeof value === "string" ? value : null;
  };
  const text =
    pick("command") ??
    pick("file_path") ??
    pick("skill") ??
    pick("description") ??
    pick("pattern") ??
    pick("url") ??
    pick("prompt") ??
    `${name} ${JSON.stringify(data)}`;
  return clip(text.replace(/\s+/g, " ").trim(), 300);
}

/**
 * Text of a tool result's content (a string or a list of text blocks).
 *
 * @param content - The `content` of a `tool_result` block.
 * @returns The text.
 */
function resultText(content: unknown): string {
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .map((part) =>
        part && typeof part === "object" && typeof (part as Raw)["text"] === "string"
          ? ((part as Raw)["text"] as string)
          : "",
      )
      .join("\n");
  }
  return "";
}

/**
 * Builds one event.
 *
 * @param base - Offsets, time and thread of the line.
 * @param kind - The kind.
 * @param fields - The rest.
 * @returns The event.
 */
function event(
  base: Pick<TraceEvent, "offset" | "end" | "at" | "parentToolUseId">,
  kind: TraceEventKind,
  fields: Partial<Omit<TraceEvent, "offset" | "end" | "at" | "parentToolUseId" | "kind">>,
): TraceEvent {
  return {
    ...base,
    kind,
    toolUseId: fields.toolUseId ?? null,
    name: fields.name ?? null,
    summary: fields.summary ?? "",
    text: fields.text ?? null,
    isError: fields.isError ?? false,
  };
}

/**
 * Normalises one line of `trace.jsonl` (claude's `stream-json` output plus the loop's attempt
 * separators, feature 342) into the events the live and replay views show. One line can carry
 * several events (an assistant message with text and tool calls), or none (bookkeeping lines).
 * Every event keeps the byte offsets of its line, so a view can resume a stream exactly there and
 * the server can name an event by its offset. Texts are clipped; nothing of the line is ever run
 * or rendered as HTML.
 *
 * @param line - The line without its newline.
 * @param offset - Byte offset of the line's start.
 * @param end - Byte offset just after the line's newline.
 * @param receivedAt - Time to use when the event has no timestamp of its own.
 * @returns The events of the line (empty for lines the views do not show).
 */
export function normalizeTraceLine(
  line: string,
  offset: number,
  end: number,
  receivedAt: string | null = null,
): TraceEvent[] {
  if (!line.trim()) return [];
  // A line that is not JSON (a half line cannot reach here: the tailer passes complete lines
  // only) is shown as it is, marked, rather than dropped - it is evidence of a broken stream.
  let raw: Raw;
  try {
    raw = JSON.parse(line) as Raw;
  } catch {
    return [
      event({ offset, end, at: receivedAt, parentToolUseId: null }, "unparsable", {
        summary: clip(line, 200),
        isError: true,
      }),
    ];
  }
  const type = typeof raw["type"] === "string" ? raw["type"] : "";
  // claude's lines carry no time of their own; the live view stamps them on arrival, a replay
  // leaves them without one (receivedAt null) rather than inventing a time.
  const at = typeof raw["timestamp"] === "string" ? raw["timestamp"] : receivedAt;
  // Lines of a subagent name the Task call that started it: the views indent them under it.
  const parentToolUseId = typeof raw["parent_tool_use_id"] === "string" ? raw["parent_tool_use_id"] : null;
  const base = { offset, end, at, parentToolUseId };

  switch (type) {
    case "backlog_loop.attempt":
      // The loop's separator before every attempt (start, retry after a limit, continuation):
      // its own `started` stamp is the attempt's time.
      return [
        event({ ...base, at: typeof raw["started"] === "string" ? raw["started"] : at }, "attempt", {
          name: str(raw["kind"], "start"),
          summary: `attempt ${str(raw["attempt"], "?")} (${str(raw["kind"], "?")}, ${str(raw["reason"], "-")})`,
          text: JSON.stringify({ attempt: raw["attempt"], kind: raw["kind"], reason: raw["reason"] }),
        }),
      ];
    case "system": {
      const subtype = str(raw["subtype"], "");
      if (subtype === "init") {
        return [
          event(base, "init", {
            name: str(raw["model"], ""),
            summary: `session ${str(raw["session_id"], "?")} · ${str(raw["model"], "")}`,
          }),
        ];
      }
      // `system/init` repeats at every turn of one claude process (342 trap), so it is shown as a
      // plain session line, never as the start of an attempt. Token counters are noise.
      if (subtype === "thinking_tokens") return [];
      if (subtype.startsWith("task_")) {
        return [
          event(base, "task", {
            name: subtype,
            summary: clip(str(raw["description"], str(raw["status"], subtype)), 200),
          }),
        ];
      }
      return [event(base, "system", { name: subtype, summary: subtype })];
    }
    case "assistant": {
      const message = (raw["message"] ?? {}) as Raw;
      const content = Array.isArray(message["content"]) ? (message["content"] as Raw[]) : [];
      const events: TraceEvent[] = [];
      for (const block of content) {
        const blockType = str(block["type"], "");
        if (blockType === "text" && typeof block["text"] === "string" && block["text"].trim()) {
          const text = block["text"];
          events.push(
            event(base, "assistant-text", {
              summary: clip(text.replace(/\s+/g, " "), 200),
              text: clip(text),
            }),
          );
        } else if (blockType === "tool_use") {
          const name = str(block["name"], "?");
          events.push(
            event(base, "tool-use", {
              name,
              toolUseId: typeof block["id"] === "string" ? block["id"] : null,
              summary: toolSummary(name, block["input"]),
              text: clip(JSON.stringify(block["input"] ?? {}, null, 1)),
            }),
          );
        } else if (blockType === "thinking") {
          // The thinking text itself is not shown (it can be long); only that it happened.
          events.push(event(base, "thinking", { summary: "thinking" }));
        }
      }
      return events;
    }
    case "user": {
      // In stream-json the tool results come back as "user" messages; anything else in them
      // (the prompt itself) is not part of the run's story.
      const message = (raw["message"] ?? {}) as Raw;
      const content = Array.isArray(message["content"]) ? (message["content"] as Raw[]) : [];
      return content
        .filter((block) => block["type"] === "tool_result")
        .map((block) => {
          const text = resultText(block["content"]);
          return event(base, "tool-result", {
            toolUseId: typeof block["tool_use_id"] === "string" ? block["tool_use_id"] : null,
            summary: clip(text.replace(/\s+/g, " "), 200),
            text: clip(text),
            isError: block["is_error"] === true,
          });
        });
    }
    case "result":
      return [
        event(base, "result", {
          name: str(raw["subtype"], ""),
          summary: `turn ended (${str(raw["subtype"], "?")})${typeof raw["total_cost_usd"] === "number" ? ` · $${raw["total_cost_usd"].toFixed(2)}` : ""}`,
          text: typeof raw["result"] === "string" ? clip(raw["result"]) : null,
          isError: raw["is_error"] === true,
        }),
      ];
    case "rate_limit_event": {
      const info = (raw["rate_limit_info"] ?? {}) as Raw;
      return [
        event(base, "rate-limit", {
          name: str(info["status"], ""),
          summary: `usage limit: ${str(info["status"], "?")}`,
        }),
      ];
    }
    default:
      // Unknown line types (newer claude versions) are skipped, not errors: the run goes on.
      return [];
  }
}
