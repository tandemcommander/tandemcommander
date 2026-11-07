// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The Files and Documents tabs of the run dashboard (feature 415, FR-010): the files the run
 * changed with how often and the run's commits; the feature's specification, plan, tasks and
 * fix log as they are now (read on request, again every 10 s while shown during a run).
 */

import { BookOpenIcon, GitCommitHorizontalIcon } from "lucide-react";
import { useState } from "react";
import type { RunInsight, StoryFile } from "@backlog-app/shared";
import { Markdown } from "@/components/markdown.tsx";
import { Alert, Skeleton } from "@/components/ui/primitives.tsx";
import { cn, formatBytes, relativeTime } from "@/lib/utils.ts";
import { useRunDocument } from "./use-run-insight.ts";

/** Names of the documents as people read them. */
const DOCUMENT_TITLES: Readonly<Record<string, string>> = {
  spec: "Specification",
  plan: "Plan",
  tasks: "Tasks",
  "fix-log": "Fix log",
  research: "Research",
  "data-model": "Data model",
  quickstart: "Quickstart",
  "closing-report": "Closing report",
};

/**
 * The Files tab.
 *
 * @param props - Files changed and commits.
 * @returns The element.
 */
export function FilesView({
  files,
  commits,
}: {
  /** Files changed. */ files: StoryFile[];
  /** Commits. */ commits: { hash: string; subject: string }[];
}) {
  return (
    <div className="grid gap-4 xl:grid-cols-2">
      <section aria-label="Files changed">
        <h3 className="mb-2 text-sm font-semibold">Files changed ({files.length})</h3>
        {files.length === 0 ? (
          <p className="text-sm text-muted-foreground">No file changed yet.</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-xs text-muted-foreground">
                <th className="py-1 font-medium">File</th>
                <th className="py-1 font-medium">Component</th>
                <th className="py-1 text-right font-medium">Edits</th>
              </tr>
            </thead>
            <tbody>
              {files.map((f) => (
                <tr key={f.path} className="border-b last:border-0">
                  <td className="max-w-0 truncate py-1 font-mono text-xs" title={f.rel}>
                    {f.rel}
                  </td>
                  <td className="py-1 text-xs whitespace-nowrap">{f.component}</td>
                  <td className="py-1 text-right tabular-nums">{f.edits}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
      <section aria-label="Commits">
        <h3 className="mb-2 text-sm font-semibold">Commits ({commits.length})</h3>
        {commits.length === 0 ? (
          <p className="text-sm text-muted-foreground">No commit yet.</p>
        ) : (
          <ol className="flex flex-col gap-1">
            {commits.map((c) => (
              <li key={c.hash} className="flex items-start gap-2 text-sm">
                <GitCommitHorizontalIcon className="mt-0.5 size-4 shrink-0 text-ok" aria-hidden />
                <code className="shrink-0 font-mono text-xs text-muted-foreground">{c.hash}</code>
                <span>{c.subject}</span>
              </li>
            ))}
          </ol>
        )}
      </section>
    </div>
  );
}

/**
 * The Documents tab.
 *
 * @param props - The run, its insight and whether it is live.
 * @returns The element.
 */
export function DocumentsView({
  runId,
  insight,
  live,
}: {
  /** The run. */ runId: string;
  /** The insight. */ insight: RunInsight | undefined;
  /** The run is live. */ live: boolean;
}) {
  const documents = insight?.documents ?? [];
  const [chosen, setChosen] = useState<string | null>(null);
  const name = chosen ?? documents[0]?.name ?? null;
  const doc = useRunDocument(documents.length ? runId : null, name, live);
  if (!insight) return <Skeleton className="h-40" />;
  if (documents.length === 0) {
    return (
      <p className="flex items-center gap-2 rounded-lg border p-4 text-sm text-muted-foreground">
        <BookOpenIcon className="size-5" aria-hidden />
        {insight.featureFolder
          ? "The feature folder has no documents yet."
          : "The run has no feature folder yet - it is made in the specify phase."}
      </p>
    );
  }
  return (
    <div className="grid gap-3 lg:grid-cols-[12rem_minmax(0,1fr)]">
      <nav aria-label="Documents" className="flex flex-row flex-wrap gap-1 lg:flex-col">
        {documents.map((d) => (
          <button
            key={d.name}
            type="button"
            aria-current={d.name === name ? "page" : undefined}
            onClick={() => setChosen(d.name)}
            className={cn(
              "rounded-md px-2 py-1 text-left text-sm hover:bg-accent",
              d.name === name && "bg-primary/12 font-medium text-primary",
            )}
          >
            {DOCUMENT_TITLES[d.name] ?? d.name}
            <span className="block text-[11px] text-muted-foreground">
              {formatBytes(d.size)} · {relativeTime(d.modified)}
            </span>
          </button>
        ))}
      </nav>
      <article
        className="min-w-0 rounded-lg border bg-card p-4"
        aria-label={name ? (DOCUMENT_TITLES[name] ?? name) : "Document"}
      >
        <p className="mb-2 font-mono text-xs text-muted-foreground">
          {insight.featureFolder}/{documents.find((d) => d.name === name)?.file}
        </p>
        {doc.isLoading ? <Skeleton className="h-40" /> : null}
        {doc.error ? <Alert tone="bad">{String(doc.error)}</Alert> : null}
        {doc.data ? <Markdown>{doc.data.text}</Markdown> : null}
      </article>
    </div>
  );
}
