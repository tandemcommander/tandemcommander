// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Feature records (user story 4; data-model *Feature record*): the list of `specs/NNN-*`
 * folders, and one feature with its closing report, fix log, specification, tasks progress, probe
 * files, commits and the items that name it. A run's closing report is what the maintainer reads
 * after every night.
 */

import { getRouteApi, Link, useNavigate } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { Markdown } from "@/components/markdown.tsx";
import { Alert, Badge, Card, CardHeader, CardTitle, Input, Skeleton } from "@/components/ui/primitives.tsx";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/overlays.tsx";
import { apiGet } from "@/lib/api.ts";
import { foldText } from "@backlog-app/shared";

/** One feature in the list. */
interface FeatureSummary {
  /** Three-digit number. */
  number: string;
  /** Folder name after the number. */
  name: string;
  /** Has an entry in FEATURE-HISTORY.md. */
  closed: boolean;
  /** Items that name it. */
  items: string[];
}

/** One feature's records. */
interface FeatureRecord extends FeatureSummary {
  /** Files of the folder (relative paths). */
  files: string[];
  /** Task progress. */
  tasks: { done: number; total: number } | null;
  /** Commits whose subject starts with `[NNN]`. */
  commits: { hash: string; date: string; subject: string }[];
  /** The FEATURE-HISTORY.md entry. */
  history: string | null;
}

/** The detail route. */
const detailRoute = getRouteApi("/features/$nnn");

/** The main files, in the order a reader wants them. */
const MAIN_FILES = [
  "closing-report.md",
  "fix-log.md",
  "spec.md",
  "plan.md",
  "tasks.md",
  "research.md",
  "quickstart.md",
  "data-model.md",
];

/**
 * The feature list.
 *
 * @returns The element.
 */
export function FeaturesPage() {
  const [q, setQ] = useState("");
  const features = useQuery({
    queryKey: ["features"],
    queryFn: ({ signal }) => apiGet<{ features: FeatureSummary[] }>("/api/features", signal),
  });
  const list = (features.data?.features ?? [])
    .filter((f) => !q || foldText(`${f.number} ${f.name}`).includes(foldText(q)))
    .sort((a, b) => b.number.localeCompare(a.number));
  return (
    <div className="mx-auto flex w-full max-w-4xl flex-col gap-3 p-4">
      <h1 className="text-lg font-semibold">Features</h1>
      <Input
        aria-label="Filter the features"
        placeholder="number or name"
        value={q}
        onChange={(e) => setQ(e.target.value)}
      />
      {features.isLoading ? <Skeleton className="h-40" /> : null}
      {features.error ? <Alert tone="bad">{String(features.error)}</Alert> : null}
      <ul className="flex flex-col gap-1 text-sm">
        {list.map((f) => (
          <li key={f.number} className="flex items-center gap-2">
            <Link
              to="/features/$nnn"
              params={{ nnn: f.number }}
              search={{ file: "" }}
              className="text-primary hover:underline"
            >
              {f.number} {f.name}
            </Link>
            {f.closed ? <Badge variant="outline">closed</Badge> : <Badge variant="primary">open</Badge>}
            {f.items.length ? (
              <span className="text-xs text-muted-foreground">{f.items.length} item(s)</span>
            ) : null}
          </li>
        ))}
      </ul>
    </div>
  );
}

/**
 * One feature.
 *
 * @returns The element.
 */
export function FeaturePage() {
  const { nnn } = detailRoute.useParams();
  const { file } = detailRoute.useSearch();
  const navigate = useNavigate();
  const feature = useQuery({
    queryKey: ["features", nnn],
    queryFn: ({ signal }) => apiGet<FeatureRecord>(`/api/features/${nnn}`, signal),
  });
  const files = feature.data?.files ?? [];
  const main = MAIN_FILES.filter((f) => files.includes(f));
  const current = file || main[0] || "";
  const text = useQuery({
    queryKey: ["features", nnn, "file", current],
    queryFn: ({ signal }) =>
      apiGet<{ path: string; text: string | null; binary: boolean; size: number }>(
        `/api/features/${nnn}/files/${current.split("/").map(encodeURIComponent).join("/")}`,
        signal,
      ),
    enabled: current !== "",
  });
  if (feature.isLoading) return <Skeleton className="m-4 h-60" />;
  if (feature.error || !feature.data)
    return <Alert tone="bad">{String(feature.error ?? "no such feature")}</Alert>;
  const data = feature.data;
  const others = files.filter((f) => !main.includes(f));
  return (
    <div className="mx-auto flex w-full max-w-5xl flex-col gap-3 p-4">
      <h1 className="text-lg font-semibold">
        {data.number} {data.name}
      </h1>
      <div className="flex flex-wrap gap-2 text-sm">
        {data.closed ? <Badge variant="outline">closed</Badge> : <Badge variant="primary">open</Badge>}
        {data.tasks ? (
          <span>
            tasks {data.tasks.done}/{data.tasks.total}
          </span>
        ) : null}
        {data.items.map((slug) => (
          <Link
            key={slug}
            to="/items/$slug"
            params={{ slug }}
            search={{ tab: "" }}
            className="text-primary hover:underline"
          >
            {slug}
          </Link>
        ))}
      </div>
      {data.history ? (
        <Card>
          <CardHeader>
            <CardTitle>Feature history</CardTitle>
          </CardHeader>
          <Markdown className="p-4">{data.history}</Markdown>
        </Card>
      ) : null}
      {main.length > 0 ? (
        <Tabs
          value={current}
          onValueChange={(value) =>
            void navigate({ to: "/features/$nnn", params: { nnn }, search: { file: value }, replace: true })
          }
        >
          <TabsList className="flex-wrap">
            {main.map((f) => (
              <TabsTrigger key={f} value={f}>
                {f.replace(".md", "")}
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>
      ) : null}
      {text.data && text.data.text !== null ? (
        current.endsWith(".md") ? (
          <Markdown className="rounded-md border p-4">{text.data.text}</Markdown>
        ) : (
          <pre className="max-h-[70vh] overflow-auto rounded-md border p-4 font-mono text-xs whitespace-pre-wrap">
            {text.data.text}
          </pre>
        )
      ) : text.data ? (
        // The server sends no text for binary files and files over 2 MB.
        <Alert tone="info">
          {text.data.binary ? "A binary file" : "A large file"} ({Math.round(text.data.size / 1024)} KB) - not
          shown here; open {current} in the repository.
        </Alert>
      ) : current ? (
        <Skeleton className="h-40" />
      ) : null}
      {others.length > 0 ? (
        <details className="text-sm">
          <summary className="cursor-pointer">Other files ({others.length})</summary>
          <ul className="mt-1 flex flex-col gap-0.5 font-mono text-xs">
            {others.map((f) => (
              <li key={f}>
                <button
                  type="button"
                  className="text-primary hover:underline"
                  onClick={() =>
                    void navigate({
                      to: "/features/$nnn",
                      params: { nnn },
                      search: { file: f },
                      replace: true,
                    })
                  }
                >
                  {f}
                </button>
              </li>
            ))}
          </ul>
        </details>
      ) : null}
      {data.commits.length > 0 ? (
        <Card>
          <CardHeader>
            <CardTitle>Commits</CardTitle>
          </CardHeader>
          <ul className="p-4 font-mono text-xs">
            {data.commits.map((c) => (
              <li key={c.hash}>
                {c.hash.slice(0, 8)} {c.date.slice(0, 10)} <span className="font-sans">{c.subject}</span>
              </li>
            ))}
          </ul>
        </Card>
      ) : null}
    </div>
  );
}
