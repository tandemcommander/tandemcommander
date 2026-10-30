// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The archive of closed items (FR-010; research R16): every item a run or the maintainer
 * closed, read from git history (a closed item's folder is deleted), with the feature that closed
 * it and its last description.
 */

import { getRouteApi, Link, useNavigate } from "@tanstack/react-router";
import { SeverityBadge } from "@/components/badges.tsx";
import { Markdown } from "@/components/markdown.tsx";
import { Alert, Input, Skeleton } from "@/components/ui/primitives.tsx";
import { useClosed, useClosedItem } from "@/lib/queries.ts";

/** The archive's route. */
const listRoute = getRouteApi("/closed");

/** One closed item's route. */
const itemRoute = getRouteApi("/closed/$slug");

/**
 * The archive list.
 *
 * @returns The element.
 */
export function ClosedPage() {
  const { q } = listRoute.useSearch();
  const navigate = useNavigate();
  const closed = useClosed(q);
  return (
    <div className="mx-auto flex w-full max-w-5xl flex-col gap-3 p-4">
      <h1 className="text-lg font-semibold">Closed items</h1>
      <Input
        aria-label="Filter the closed items"
        placeholder="Filter by title, slug or area"
        defaultValue={q}
        onChange={(e) => void navigate({ to: "/closed", search: { q: e.target.value }, replace: true })}
      />
      {closed.isLoading ? <Skeleton className="h-40" /> : null}
      {closed.error ? <Alert tone="bad">{String(closed.error)}</Alert> : null}
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b text-left text-xs text-muted-foreground">
            <th className="py-1.5 pr-2">Closed</th>
            <th className="pr-2">Item</th>
            <th className="pr-2">Area</th>
            <th className="pr-2">Sev</th>
            <th>Feature</th>
          </tr>
        </thead>
        <tbody>
          {(closed.data?.items ?? []).map((item) => (
            <tr key={`${item.closedIn.hash}-${item.slug}`} className="border-b border-border/60 align-top">
              <td className="py-1.5 pr-2 text-xs whitespace-nowrap text-muted-foreground">
                {item.closedIn.date.slice(0, 10)}
              </td>
              <td className="pr-2">
                <Link
                  to="/closed/$slug"
                  params={{ slug: item.slug }}
                  className="text-primary hover:underline"
                >
                  {item.title}
                </Link>
              </td>
              <td className="pr-2">{item.area}</td>
              <td className="pr-2">
                {item.severity !== null ? <SeverityBadge severity={item.severity} /> : null}
              </td>
              <td>{item.feature ?? "-"}</td>
            </tr>
          ))}
        </tbody>
      </table>
      {closed.data && closed.data.items.length === 0 ? (
        <p className="text-sm text-muted-foreground">No closed item matches.</p>
      ) : null}
    </div>
  );
}

/**
 * One closed item with its last description.
 *
 * @returns The element.
 */
export function ClosedItemPage() {
  const { slug } = itemRoute.useParams();
  const item = useClosedItem(slug);
  if (item.isLoading) return <Skeleton className="m-4 h-60" />;
  if (item.error || !item.data) return <Alert tone="bad">{String(item.error ?? "not found")}</Alert>;
  const data = item.data;
  return (
    <article className="mx-auto flex w-full max-w-4xl flex-col gap-3 p-4">
      <h1 className="text-xl font-semibold">{data.title}</h1>
      <p className="text-sm text-muted-foreground">
        Closed {data.closedIn.date.slice(0, 10)} in {data.closedIn.hash.slice(0, 8)}: {data.closedIn.subject}
        {data.feature ? (
          <>
            {" "}
            (feature{" "}
            <Link
              to="/features/$nnn"
              params={{ nnn: data.feature }}
              search={{ file: "" }}
              className="text-primary hover:underline"
            >
              {data.feature}
            </Link>
            )
          </>
        ) : null}
      </p>
      <Markdown>{(data.lastDescription ?? "").replace(/^---[\s\S]*?\n---\n/, "")}</Markdown>
    </article>
  );
}
