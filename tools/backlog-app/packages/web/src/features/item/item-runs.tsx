// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The runs of one item (the *Runs* tab of the item view): every run of the loop and every
 * journal row that names the item, newest first, with links to the run and its feature.
 */

import { Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import type { Run } from "@backlog-app/shared";
import { OutcomeBadge } from "@/components/badges.tsx";
import { Skeleton } from "@/components/ui/primitives.tsx";
import { apiGet } from "@/lib/api.ts";
import { formatDuration } from "@/lib/utils.ts";

/**
 * The item's runs.
 *
 * @param props - The slug.
 * @returns The element.
 */
export function ItemRuns({ slug }: { /** The item. */ slug: string }) {
  const runs = useQuery({
    queryKey: ["runs", { slug }],
    queryFn: ({ signal }) => apiGet<{ runs: Run[] }>(`/api/runs?slug=${encodeURIComponent(slug)}`, signal),
  });
  if (runs.isLoading) return <Skeleton className="h-16" />;
  const list = runs.data?.runs ?? [];
  if (list.length === 0)
    return <p className="text-sm text-muted-foreground">No run has worked on this item yet.</p>;
  return (
    <ul className="flex flex-col gap-1.5">
      {list.map((run) => (
        <li key={run.id} className="flex flex-wrap items-center gap-2 text-sm">
          <OutcomeBadge outcome={run.outcome} />
          <Link to="/runs/$id" params={{ id: run.id }} className="text-primary hover:underline">
            {run.started?.replace("T", " ").slice(0, 16) ?? run.id}
          </Link>
          {run.feature ? (
            <Link
              to="/features/$nnn"
              params={{ nnn: run.feature }}
              search={{ file: "" }}
              className="text-xs text-primary hover:underline"
            >
              feature {run.feature}
            </Link>
          ) : null}
          <span className="text-xs text-muted-foreground">{formatDuration(run.durationSeconds)}</span>
          {run.note ? <span className="w-full text-xs text-muted-foreground">{run.note}</span> : null}
        </li>
      ))}
    </ul>
  );
}
