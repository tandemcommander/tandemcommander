// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The live run (user story 2; FR-014; feature 415): the run the loop works on now as a
 * dashboard a person reads - progress and the expected end, what happens now, live figures and
 * price, the story in words, critical entries, decisions, screenshots, diagrams, documents, the raw
 * transcript, and the chat about the item. With no run, it says what the loop does and which item
 * it would take.
 */

import { Link } from "@tanstack/react-router";
import type { ItemRowView } from "@backlog-app/shared";
import { Skeleton } from "@/components/ui/primitives.tsx";
import { useBoard, useLiveRun } from "@/lib/queries.ts";
import { useAppStore } from "@/app/store.ts";
import { loopLine } from "@/features/loop/loop-status.tsx";
import { useTraceStream } from "@/features/runs/trace-view.tsx";
import { RunDashboard } from "./run-dashboard.tsx";

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
      <RunDashboard run={run} events={trace.events} connected={trace.connected} live />
    </div>
  );
}
