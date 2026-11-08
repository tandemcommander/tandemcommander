// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The live run (user story 2; FR-014; features 415 and 419): the run the loop works on now
 * as a dashboard a person reads - one view at a time (the overview with progress, the expected end
 * and live figures, the story in words, critical entries, decisions, screenshots, diagrams,
 * documents, the raw transcript, the chat about the item), the chosen one in the address
 * (`?view=`). The page fills the window and never scrolls; each view scrolls by itself. With no
 * run, it says what the loop does and which item it would take.
 */

import { getRouteApi, Link } from "@tanstack/react-router";
import type { ItemRowView } from "@backlog-app/shared";
import { Skeleton } from "@/components/ui/primitives.tsx";
import { useBoard, useLiveRun } from "@/lib/queries.ts";
import { useAppStore } from "@/app/store.ts";
import { loopLine } from "@/features/loop/loop-status.tsx";
import { useTraceStream } from "@/features/runs/trace-view.tsx";
import { RunDashboard } from "./run-dashboard.tsx";

/** The route (its `view` search parameter). */
const route = getRouteApi("/live");

/**
 * The live page.
 *
 * @returns The element.
 */
export function LivePage() {
  const live = useLiveRun();
  const { view } = route.useSearch();
  const navigate = route.useNavigate();
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
    // Exactly as tall as the frame leaves: the page never scrolls (feature 419); below the
    // smallest supported window (820x640) it scrolls rather than cut its views off.
    <div className="flex min-h-0 w-full flex-1 flex-col overflow-y-auto p-4" data-run-page>
      <RunDashboard
        run={run}
        events={trace.events}
        connected={trace.connected}
        live
        heading="Live run"
        view={view}
        onViewChange={(next) => void navigate({ search: { view: next }, replace: true })}
      />
    </div>
  );
}
