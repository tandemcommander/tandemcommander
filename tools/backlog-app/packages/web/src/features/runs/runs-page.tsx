// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Run history (FR-019; analysis A4 §3.9): every run - with a trace or only a journal row -
 * filterable by outcome and item, and statistics by outcome, week and area with the total cost.
 */

import { getRouteApi, Link, useNavigate } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Legend as ChartLegend,
  ResponsiveContainer,
  Tooltip as ChartTooltip,
  XAxis,
  YAxis,
} from "recharts";
import { RUN_OUTCOMES, type Run, type RunStats } from "@backlog-app/shared";
import { OutcomeBadge } from "@/components/badges.tsx";
import { Card, CardHeader, CardTitle, Input, NativeSelect, Skeleton } from "@/components/ui/primitives.tsx";
import { apiGet } from "@/lib/api.ts";
import { formatDuration } from "@/lib/utils.ts";

/** The route. */
const route = getRouteApi("/runs");

/** Chart colours per outcome (theme tokens). */
const OUTCOME_COLOR: Record<string, string> = {
  closed: "var(--ok)",
  blocked: "var(--bad)",
  "not-reproduced": "var(--sev-trivial)",
  split: "var(--info)",
  triaged: "var(--status-new)",
  "nothing-to-do": "var(--muted-foreground)",
};

/**
 * The statistics panel.
 *
 * @returns The element.
 */
function RunStatsPanel() {
  const stats = useQuery({
    queryKey: ["runs", "stats"],
    queryFn: ({ signal }) => apiGet<RunStats>("/api/stats", signal),
  });
  if (!stats.data) return <Skeleton className="h-48" />;
  const outcomes = Object.keys(stats.data.byOutcome);
  const weeks = stats.data.byWeek.map((w) => ({ week: w.week.slice(5), ...w.counts }));
  const areas = Object.entries(stats.data.byArea)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 10);
  return (
    <Card>
      <CardHeader>
        <CardTitle>Statistics</CardTitle>
        <span className="text-xs text-muted-foreground">
          cost ${stats.data.costUsd.toFixed(2)} · median {formatDuration(stats.data.durations.median)}
        </span>
      </CardHeader>
      <div className="grid gap-4 p-4 lg:grid-cols-[2fr_1fr]">
        <div className="h-56" role="img" aria-label="Runs per week by outcome">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={weeks}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
              <XAxis dataKey="week" stroke="var(--muted-foreground)" fontSize={11} />
              <YAxis allowDecimals={false} stroke="var(--muted-foreground)" fontSize={11} />
              <ChartTooltip
                contentStyle={{
                  background: "var(--popover)",
                  border: "1px solid var(--border)",
                  color: "var(--popover-foreground)",
                }}
              />
              <ChartLegend />
              {outcomes.map((o) => (
                <Bar key={o} dataKey={o} stackId="a" fill={OUTCOME_COLOR[o] ?? "var(--primary)"} />
              ))}
            </BarChart>
          </ResponsiveContainer>
        </div>
        <ul className="flex flex-col gap-1 text-sm">
          {Object.entries(stats.data.byOutcome).map(([o, n]) => (
            <li key={o} className="flex items-center gap-2">
              <OutcomeBadge outcome={o} /> <span className="tabular-nums">{n}</span>
            </li>
          ))}
          <li className="mt-2 text-xs text-muted-foreground">
            By area: {areas.map(([a, n]) => `${a} ${n}`).join(", ")}
          </li>
        </ul>
      </div>
    </Card>
  );
}

/**
 * The run history page.
 *
 * @returns The element.
 */
export function RunsPage() {
  const { outcome, q } = route.useSearch();
  const navigate = useNavigate();
  const runs = useQuery({
    queryKey: ["runs", { outcome }],
    queryFn: ({ signal }) =>
      apiGet<{ runs: Run[] }>(`/api/runs${outcome ? `?outcome=${outcome}` : ""}`, signal),
  });
  const list = (runs.data?.runs ?? []).filter(
    (r) => !q || (r.slug ?? "triage").includes(q) || (r.note ?? "").toLowerCase().includes(q.toLowerCase()),
  );
  return (
    <div className="mx-auto flex w-full max-w-6xl flex-col gap-4 p-4">
      <h1 className="text-lg font-semibold">Runs</h1>
      <RunStatsPanel />
      <div className="flex flex-wrap gap-2">
        <NativeSelect
          aria-label="Outcome"
          className="w-44"
          value={outcome}
          onChange={(e) =>
            void navigate({ to: "/runs", search: { outcome: e.target.value, q }, replace: true })
          }
        >
          <option value="">every outcome</option>
          {RUN_OUTCOMES.map((o) => (
            <option key={o} value={o}>
              {o}
            </option>
          ))}
        </NativeSelect>
        <Input
          aria-label="Filter by item or note"
          className="max-w-xs"
          placeholder="item or note"
          defaultValue={q}
          onChange={(e) =>
            void navigate({ to: "/runs", search: { outcome, q: e.target.value }, replace: true })
          }
        />
      </div>
      {runs.isLoading ? <Skeleton className="h-40" /> : null}
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b text-left text-xs text-muted-foreground">
            <th className="py-1.5 pr-2">Started</th>
            <th className="pr-2">Outcome</th>
            <th className="pr-2">Item</th>
            <th className="pr-2">Feature</th>
            <th className="pr-2">Duration</th>
            <th className="pr-2">Cost</th>
            <th>Note</th>
          </tr>
        </thead>
        <tbody>
          {list.map((run) => (
            <tr key={run.id} className="border-b border-border/60 align-top">
              <td className="py-1.5 pr-2 whitespace-nowrap">
                <Link to="/runs/$id" params={{ id: run.id }} className="text-primary hover:underline">
                  {run.started?.replace("T", " ").slice(0, 16) ?? run.id}
                </Link>
              </td>
              <td className="pr-2">
                <OutcomeBadge outcome={run.outcome} />
              </td>
              <td className="max-w-64 truncate pr-2">{run.slug ?? "auto-triage"}</td>
              <td className="pr-2">{run.feature ?? "-"}</td>
              <td className="pr-2 whitespace-nowrap">{formatDuration(run.durationSeconds)}</td>
              <td className="pr-2">{run.cost ? `$${run.cost.usd.toFixed(2)}` : "-"}</td>
              <td className="text-xs text-muted-foreground">{run.note}</td>
            </tr>
          ))}
        </tbody>
      </table>
      {runs.data && list.length === 0 ? (
        <p className="text-sm text-muted-foreground">No runs yet - start the loop.</p>
      ) : null}
    </div>
  );
}
