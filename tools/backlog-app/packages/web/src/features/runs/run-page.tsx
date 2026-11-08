// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file One run with its full transcript (FR-019; analysis A4 §3.9; features 415 and 419): the run
 * dashboard of the live view, one view at a time, the chosen one in the address (`?view=`) - progress, figures, the story in words, critical entries, decisions,
 * screenshots, diagrams, documents and the trace replayed from the server's stream. A journal row
 * without a trace shows what the journal records.
 */

import { getRouteApi } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import type { Run } from "@backlog-app/shared";
import { Alert, Skeleton } from "@/components/ui/primitives.tsx";
import { apiGet } from "@/lib/api.ts";
import { RunDashboard } from "@/features/live/run-dashboard.tsx";
import { RunSummary } from "./run-summary.tsx";
import { useTraceStream } from "./trace-view.tsx";

/** The route. */
const route = getRouteApi("/runs/$id");

/**
 * The run page.
 *
 * @returns The element.
 */
export function RunPage() {
  const { id } = route.useParams();
  const { view } = route.useSearch();
  const navigate = route.useNavigate();
  const run = useQuery({
    queryKey: ["run", id],
    queryFn: ({ signal }) => apiGet<Run>(`/api/runs/${id}`, signal),
  });
  const trace = useTraceStream(run.data?.hasTrace ? id : null);
  if (run.isLoading) return <Skeleton className="m-4 h-60" />;
  if (run.error || !run.data) return <Alert tone="bad">{String(run.error ?? "no such run")}</Alert>;
  if (run.data.hasTrace)
    return (
      // Exactly as tall as the frame leaves: the page never scrolls (feature 419).
      <div className="flex min-h-0 w-full flex-1 flex-col overflow-hidden p-4">
        <RunDashboard
          run={run.data}
          events={trace.events}
          connected={trace.connected}
          live={run.data.outcome === "running"}
          heading={`Run ${id}`}
          view={view}
          onViewChange={(next) => void navigate({ search: { view: next }, replace: true })}
        />
      </div>
    );
  return (
    <div className="flex min-h-0 w-full flex-col gap-3 p-4">
      <h1 className="text-lg font-semibold">Run {id}</h1>
      <RunSummary run={run.data} />
      <p className="text-sm text-muted-foreground">
        This run has no trace (it ran before feature 342 or outside the loop); the journal row is all there
        is.
      </p>
    </div>
  );
}
