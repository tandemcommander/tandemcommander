// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The transcript of a run (FR-014, FR-019; analysis A4 §3.8, §3.9): the trace's events from
 * the server's stream, in a virtualised list that follows the end while the run lives. Attempts
 * split the list, tool calls show their summary and result, subagent work is folded under its
 * Agent call, and a click shows the full text of an event.
 */

import {
  BotIcon,
  ChevronRightIcon,
  CircleAlertIcon,
  MessageSquareTextIcon,
  TerminalIcon,
  WrenchIcon,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { Virtuoso } from "react-virtuoso";
import type { TraceEvent } from "@backlog-app/shared";
import { Input } from "@/components/ui/primitives.tsx";
import { Dialog, DialogContent } from "@/components/ui/overlays.tsx";
import { openStream } from "@/lib/sse.ts";
import { cn } from "@/lib/utils.ts";

/** Most events kept in the page (older ones of a huge run are dropped from the top). */
const MAX_EVENTS = 50_000;

/**
 * Follows a run's trace stream.
 *
 * @param id - The run id (a trace folder), or null.
 * @returns The events so far, whether the stream ended, and whether it is connected.
 */
export function useTraceStream(id: string | null) {
  const [events, setEvents] = useState<TraceEvent[]>([]);
  const [ended, setEnded] = useState(false);
  const [connected, setConnected] = useState(false);
  const [streamOf, setStreamOf] = useState(id);
  // Another run: start from an empty transcript (adjusted during render).
  if (id !== streamOf) {
    setStreamOf(id);
    setEvents([]);
    setEnded(false);
  }
  useEffect(() => {
    if (!id || id.startsWith("runs-md-")) return;
    // Events arrive in bursts; they are batched into one state update per animation frame.
    let batch: TraceEvent[] = [];
    let frame = 0;
    /** Hands the batch to React. */
    const flush = (): void => {
      frame = 0;
      const add = batch;
      batch = [];
      setEvents((previous) => {
        const next = previous.concat(add);
        return next.length > MAX_EVENTS ? next.slice(next.length - MAX_EVENTS) : next;
      });
    };
    const close = openStream(`/api/runs/${id}/stream`, {
      onConnection: setConnected,
      onEvent: ({ event, data }) => {
        if (event === "trace" || event === "attempt") {
          batch.push(data as TraceEvent);
          if (!frame) frame = window.requestAnimationFrame(flush);
        } else if (event === "ended") {
          setEnded(true);
          close();
        }
      },
    });
    return () => {
      close();
      if (frame) window.cancelAnimationFrame(frame);
    };
  }, [id]);
  return { events, ended, connected };
}

/** Icons per event kind. */
const ICON: Partial<Record<TraceEvent["kind"], typeof BotIcon>> = {
  "assistant-text": MessageSquareTextIcon,
  "tool-use": WrenchIcon,
  "tool-result": TerminalIcon,
  task: BotIcon,
  unparsable: CircleAlertIcon,
};

/**
 * The transcript.
 *
 * @param props - The events and whether to follow the end.
 * @returns The element.
 */
export function TraceView({
  events,
  follow,
}: {
  /** The events. */ events: TraceEvent[];
  /** Follow the end (live). */ follow: boolean;
}) {
  const [filter, setFilter] = useState("");
  const [showSubagents, setShowSubagents] = useState(false);
  const [open, setOpen] = useState<TraceEvent | null>(null);
  const visible = useMemo(() => {
    const needle = filter.trim().toLowerCase();
    return events.filter(
      (e) =>
        e.kind !== "thinking" &&
        (showSubagents || e.parentToolUseId === null) &&
        (!needle ||
          e.summary.toLowerCase().includes(needle) ||
          (e.name ?? "").toLowerCase().includes(needle)),
    );
  }, [events, filter, showSubagents]);
  const subagentCount = useMemo(() => events.filter((e) => e.parentToolUseId !== null).length, [events]);
  return (
    <div className="flex min-h-0 flex-1 flex-col gap-2">
      <div className="flex flex-wrap items-center gap-2">
        <Input
          aria-label="Filter the transcript"
          placeholder="Filter the transcript"
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          className="max-w-xs"
        />
        <label className="flex items-center gap-1.5 text-xs">
          <input
            type="checkbox"
            checked={showSubagents}
            onChange={(e) => setShowSubagents(e.target.checked)}
          />
          Show subagent work ({subagentCount})
        </label>
        <span className="ml-auto text-xs text-muted-foreground">{visible.length} events</span>
      </div>
      <div className="h-[60vh] min-h-64 rounded-md border">
        <Virtuoso
          data={visible}
          followOutput={follow ? "smooth" : false}
          initialTopMostItemIndex={follow ? Math.max(0, visible.length - 1) : 0}
          computeItemKey={(_, e) => `${e.offset}-${e.kind}-${e.toolUseId ?? ""}`}
          itemContent={(_, event) => {
            if (event.kind === "attempt") {
              return <div className="border-y bg-muted px-3 py-1 text-xs font-medium">{event.summary}</div>;
            }
            const Icon = ICON[event.kind] ?? ChevronRightIcon;
            return (
              <button
                type="button"
                onClick={() => setOpen(event)}
                className={cn(
                  "flex w-full items-start gap-2 px-3 py-1 text-left text-xs hover:bg-accent/50",
                  event.parentToolUseId !== null && "pl-8 text-muted-foreground",
                  event.isError && "text-bad",
                )}
              >
                <Icon className="mt-0.5 size-3.5 shrink-0" aria-hidden />
                <span className="w-16 shrink-0 text-muted-foreground tabular-nums">
                  {event.at ? event.at.slice(11, 19) : ""}
                </span>
                {event.name ? <span className="shrink-0 font-medium">{event.name}</span> : null}
                <span
                  className={cn(
                    "min-w-0 flex-1 truncate",
                    event.kind === "assistant-text" && "text-foreground",
                  )}
                >
                  {event.summary}
                </span>
              </button>
            );
          }}
        />
      </div>
      <Dialog open={open !== null} onOpenChange={(o) => !o && setOpen(null)}>
        <DialogContent title={open ? `${open.kind}${open.name ? `: ${open.name}` : ""}` : ""} wide>
          <pre className="max-h-[60vh] overflow-auto rounded bg-muted p-3 font-mono text-xs whitespace-pre-wrap">
            {open?.text ?? open?.summary}
          </pre>
        </DialogContent>
      </Dialog>
    </div>
  );
}
