// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Release readiness (user story 6; research R25): read-only and without network - the
 * unreleased changelog entries, the person steps and decisions that block a release, `main`
 * against its remote as last fetched, the local tags, and the release records of
 * `backlog/RELEASE.md`. There is deliberately no build, tag, push or publish control: releasing is
 * the maintainer's step (`/tandem-release` in Claude Code).
 */

import { Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Markdown } from "@/components/markdown.tsx";
import { Alert, Card, CardHeader, CardTitle, Skeleton } from "@/components/ui/primitives.tsx";
import { apiGet } from "@/lib/api.ts";

/** The answer of `GET /api/release`. */
interface ReleaseView {
  /** The unreleased section of CHANGELOG.md (Markdown), or null. */
  unreleased: string | null;
  /** Items that block a release. */
  blockers: { slug: string; title: string; section?: string | null }[];
  /** Commits of main not on origin/main. */
  ahead: number | null;
  /** Commits of origin/main not on main. */
  behind: number | null;
  /** Local version tags, newest first. */
  tags: string[];
  /** The release records of RELEASE.md (Markdown). */
  records: string | null;
}

/**
 * The release page.
 *
 * @returns The element.
 */
export function ReleasePage() {
  const release = useQuery({
    queryKey: ["release"],
    queryFn: ({ signal }) => apiGet<ReleaseView>("/api/release", signal),
  });
  if (release.isLoading) return <Skeleton className="m-4 h-60" />;
  if (release.error || !release.data)
    return <Alert tone="bad">{String(release.error ?? "unavailable")}</Alert>;
  const data = release.data;
  return (
    <div className="mx-auto flex w-full max-w-5xl flex-col gap-4 p-4">
      <h1 className="text-lg font-semibold">Release readiness</h1>
      <Alert tone="info">
        Read-only. Preparing a release is <code>/tandem-release &lt;x.y.z&gt;</code> in Claude Code; building,
        tagging, pushing and publishing are the maintainer's steps (backlog/RELEASE.md).
      </Alert>
      <div className="grid gap-4 md:grid-cols-3">
        <Card className="p-4 text-sm">
          <div className="text-xs text-muted-foreground">main vs origin (last fetch)</div>
          <div className="text-lg font-semibold">
            {data.ahead === null ? "no origin/main" : `+${data.ahead} / -${data.behind ?? 0}`}
          </div>
        </Card>
        <Card className="p-4 text-sm">
          <div className="text-xs text-muted-foreground">Latest tag</div>
          <div className="text-lg font-semibold">{data.tags[0] ?? "none"}</div>
        </Card>
        <Card className="p-4 text-sm">
          <div className="text-xs text-muted-foreground">Blocking items</div>
          <div className="text-lg font-semibold">{data.blockers.length}</div>
        </Card>
      </div>
      {data.blockers.length > 0 ? (
        <Card>
          <CardHeader>
            <CardTitle>Blocking a release</CardTitle>
          </CardHeader>
          <ul className="flex flex-col gap-1 p-4 text-sm">
            {data.blockers.map((b) => (
              <li key={b.slug}>
                <Link
                  to="/items/$slug"
                  params={{ slug: b.slug }}
                  search={{ tab: "" }}
                  className="text-primary hover:underline"
                >
                  {b.title}
                </Link>
                {b.section ? <span className="text-xs text-muted-foreground"> · {b.section}</span> : null}
              </li>
            ))}
          </ul>
        </Card>
      ) : null}
      <Card>
        <CardHeader>
          <CardTitle>Unreleased changes</CardTitle>
        </CardHeader>
        {data.unreleased ? (
          <Markdown className="p-4">{data.unreleased}</Markdown>
        ) : (
          <p className="p-4 text-sm text-muted-foreground">No unreleased section in CHANGELOG.md.</p>
        )}
      </Card>
      {data.records ? (
        <Card>
          <CardHeader>
            <CardTitle>Release records (RELEASE.md)</CardTitle>
          </CardHeader>
          <Markdown className="p-4">{data.records}</Markdown>
        </Card>
      ) : null}
    </div>
  );
}
