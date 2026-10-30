// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The live run (user story 2; FR-014): the run the loop works on now, updating while the page
 * is open - phase, tasks, the tool in flight, commits, attempts, cost, and the transcript following
 * its end. With no run, it says what the loop does and which item it would take.
 */

import { Link } from "@tanstack/react-router";
import type { ItemRowView } from "@backlog-app/shared";
import { Skeleton } from "@/components/ui/primitives.tsx";
import { useBoard, useLiveRun } from "@/lib/queries.ts";
import { useAppStore } from "@/app/store.ts";
import { loopLine } from "@/features/loop/loop-status.tsx";
import { RunSummary } from "@/features/runs/run-summary.tsx";
import { TraceView, useTraceStream } from "@/features/runs/trace-view.tsx";

/**
 * The live page.
 *
 * @returns The element.
 */
export function LivePage() {
  const live = useLiveRun();
  const loop = useAppStore((s) => s.state?.loop ?? null);
  const board = useBoard("");
  const run = live.data?.run ?? null;
  const trace = useTraceStream(run?.id ?? null);
  if (live.isLoading) return <Skeleton className="m-4 h-60" />;
  if (!run) {
    const next = board.data?.sections
      .flatMap((s) => s.rows)
      .find((r): r is ItemRowView => r.kind === "item" && r.slug === board.data?.next.slug);
    return (
      <div className="mx-auto flex w-full max-w-4xl flex-col gap-2 p-4">
        <h1 className="text-lg font-semibold">Live run</h1>
        <p className="text-sm">No run is in progress. {loop ? `${loopLine(loop)}: ${loop.detail}` : ""}</p>
        <p className="text-sm text-muted-foreground">
          The loop would take:{" "}
          {next ? (
            <Link
              to="/items/$slug"
              params={{ slug: next.slug }}
              search={{ tab: "" }}
              className="text-primary hover:underline"
            >
              {next.title}
            </Link>
          ) : (
            "nothing eligible in Next"
          )}
          .{" "}
          <Link to="/runs" search={{ outcome: "", q: "" }} className="text-primary hover:underline">
            Run history
          </Link>
        </p>
      </div>
    );
  }
  return (
    <div className="flex min-h-0 w-full flex-col gap-3 p-4">
      <h1 className="text-lg font-semibold">Live run</h1>
      <RunSummary run={run} />
      <TraceView events={trace.events} follow />
      {!trace.connected ? <p className="text-xs text-muted-foreground">Connecting to the trace…</p> : null}
    </div>
  );
}
