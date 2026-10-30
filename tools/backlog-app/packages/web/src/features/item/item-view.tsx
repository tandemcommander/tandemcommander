// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The item view (FR-010; analysis A4 §3.3): header fields, the rendered description, the
 * log, relations in both directions, files, version history and runs. Used in the detail pane of
 * the backlog page and on the item's own page. Item and GitHub texts are rendered as untrusted
 * Markdown (no raw HTML).
 */

import { Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { CheckSquareIcon, ExternalLinkIcon, SquareIcon } from "lucide-react";
import { useState } from "react";
import type { Item } from "@backlog-app/shared";
import { SeverityBadge, StatusBadge, TypeBadge } from "@/components/badges.tsx";
import { Markdown } from "@/components/markdown.tsx";
import { Alert, Badge, Skeleton } from "@/components/ui/primitives.tsx";
import {
  Dialog,
  DialogContent,
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "@/components/ui/overlays.tsx";
import { apiGet, ApiFailure } from "@/lib/api.ts";
import { useItem, useItemHistory } from "@/lib/queries.ts";
import { relativeTime } from "@/lib/utils.ts";
import { ItemActions } from "./item-actions.tsx";
import { ItemRuns } from "./item-runs.tsx";

/**
 * One header field as a label and a value.
 *
 * @param props - Label and value.
 * @returns The element.
 */
function Field({
  label,
  children,
}: {
  /** Label. */ label: string;
  /** Value. */ children: React.ReactNode;
}) {
  return (
    <div className="flex flex-col">
      <dt className="text-[11px] text-muted-foreground uppercase">{label}</dt>
      <dd className="text-sm">{children}</dd>
    </div>
  );
}

/**
 * A list of slugs as links to the items.
 *
 * @param props - The slugs.
 * @returns The element.
 */
function SlugLinks({ slugs }: { /** Slugs. */ slugs: string[] }) {
  if (slugs.length === 0) return <span className="text-muted-foreground">none</span>;
  return (
    <ul className="flex flex-col gap-0.5">
      {slugs.map((slug) => (
        <li key={slug}>
          <Link
            to="/items/$slug"
            params={{ slug }}
            search={{ tab: "" }}
            className="text-primary hover:underline"
          >
            {slug}
          </Link>
        </li>
      ))}
    </ul>
  );
}

/**
 * The description: every body section but the log, rendered; checklists and options highlighted.
 *
 * @param props - The item.
 * @returns The element.
 */
function Description({ item }: { /** The item. */ item: Item }) {
  return (
    <div className="flex flex-col gap-1">
      {item.body
        .filter((section) => section.name !== "Log")
        .map((section) => (
          <section key={section.name} aria-label={section.name}>
            <h3 className="mt-2 text-xs font-semibold tracking-wide text-muted-foreground uppercase">
              {section.name}
            </h3>
            {section.name === "Steps" && item.steps.length > 0 ? (
              <ul className="mt-1 flex flex-col gap-1">
                {item.steps.map((step) => (
                  <li key={step.index} className="flex gap-2 text-sm">
                    {step.done ? (
                      <CheckSquareIcon className="mt-0.5 size-4 shrink-0 text-ok" aria-label="done" />
                    ) : (
                      <SquareIcon
                        className="mt-0.5 size-4 shrink-0 text-muted-foreground"
                        aria-label="open"
                      />
                    )}
                    <Markdown className="[&>p]:m-0">{step.text}</Markdown>
                  </li>
                ))}
              </ul>
            ) : (
              <Markdown>{section.markdown}</Markdown>
            )}
          </section>
        ))}
    </div>
  );
}

/**
 * The version history of an item with a viewer of each version.
 *
 * @param props - The slug.
 * @returns The element.
 */
function History({ slug }: { /** The item. */ slug: string }) {
  const history = useItemHistory(slug);
  const [hash, setHash] = useState<string | null>(null);
  const version = useQuery({
    queryKey: ["item", slug, "version", hash],
    queryFn: ({ signal }) => apiGet<{ markdown: string }>(`/api/items/${slug}/history/${hash}`, signal),
    enabled: hash !== null,
  });
  if (history.isLoading) return <Skeleton className="h-24" />;
  if (history.error) return <Alert tone="bad">{String(history.error)}</Alert>;
  return (
    <>
      <ol className="flex flex-col gap-1">
        {(history.data?.commits ?? []).map((commit) => (
          <li key={commit.hash} className="flex gap-2 text-sm">
            <button
              type="button"
              className="font-mono text-xs text-primary hover:underline"
              onClick={() => setHash(commit.hash)}
            >
              {commit.hash.slice(0, 8)}
            </button>
            <span className="text-xs text-muted-foreground tabular-nums">{commit.date.slice(0, 10)}</span>
            <span className="min-w-0 truncate" title={commit.subject}>
              {commit.subject}
            </span>
          </li>
        ))}
      </ol>
      <Dialog open={hash !== null} onOpenChange={(open) => !open && setHash(null)}>
        <DialogContent title={`${slug} at ${hash?.slice(0, 8) ?? ""}`} wide>
          {version.data ? (
            <pre className="max-h-[60vh] overflow-auto rounded bg-muted p-3 font-mono text-xs whitespace-pre-wrap">
              {version.data.markdown}
            </pre>
          ) : (
            <Skeleton className="h-40" />
          )}
        </DialogContent>
      </Dialog>
    </>
  );
}

/**
 * The files of an item folder with a viewer.
 *
 * @param props - The item.
 * @returns The element.
 */
function Files({ item }: { /** The item. */ item: Item }) {
  const [name, setName] = useState<string | null>(null);
  const file = useQuery({
    queryKey: ["item", item.slug, "file", name],
    queryFn: ({ signal }) =>
      apiGet<{ name: string; text: string }>(
        `/api/items/${item.slug}/files/${encodeURIComponent(name!)}`,
        signal,
      ),
    enabled: name !== null,
  });
  const names = [
    ...(item.files.issue ? ["issue.md"] : []),
    ...(item.files.reply ? ["reply.md"] : []),
    ...item.files.evidence,
  ];
  if (names.length === 0)
    return <p className="text-sm text-muted-foreground">No files besides the description.</p>;
  return (
    <>
      <ul className="flex flex-col gap-1 text-sm">
        {names.map((n) => (
          <li key={n}>
            <button type="button" className="text-primary hover:underline" onClick={() => setName(n)}>
              {item.files.evidence.includes(n) ? `evidence/${n}` : n}
            </button>
            {n === "reply.md" && item.files.reply ? (
              <Badge variant="outline" className="ml-2">
                {item.files.reply.state}
              </Badge>
            ) : null}
          </li>
        ))}
      </ul>
      <Dialog open={name !== null} onOpenChange={(open) => !open && setName(null)}>
        <DialogContent title={name ?? ""} wide>
          {file.data ? (
            name?.endsWith(".md") ? (
              <Markdown>{file.data.text}</Markdown>
            ) : (
              <pre className="max-h-[60vh] overflow-auto rounded bg-muted p-3 font-mono text-xs whitespace-pre-wrap">
                {file.data.text}
              </pre>
            )
          ) : (
            <Skeleton className="h-40" />
          )}
        </DialogContent>
      </Dialog>
    </>
  );
}

/**
 * The item view.
 *
 * @param props - The slug, compact mode (detail pane) and search words.
 * @returns The element.
 */
export function ItemView({
  slug,
  compact = false,
  tab,
  onTab,
}: {
  /** The item. */
  slug: string;
  /** Detail-pane mode (smaller header). */
  compact?: boolean;
  /** Search words to highlight (reserved for the description). */
  words?: string[];
  /** The open tab (controlled by the item page's address). */
  tab?: string;
  /** Called when the tab changes. */
  onTab?: (tab: string) => void;
}) {
  const item = useItem(slug);
  // The item page keeps the open tab in its address (`tab` + `onTab`); the detail panes of the
  // backlog and triage pages pass neither, so the view keeps the tab itself. (A controlled value
  // without a handler froze the tabs on Description: clicks changed nothing.)
  const [ownTab, setOwnTab] = useState("description");
  const openTab = onTab ? tab || "description" : ownTab;
  if (item.isLoading) {
    return (
      <div className="flex flex-col gap-2 p-4">
        <Skeleton className="h-6 w-2/3" />
        <Skeleton className="h-40" />
      </div>
    );
  }
  if (item.error) {
    const missing = item.error instanceof ApiFailure && item.error.code === "not-found";
    return (
      <div className="p-4">
        <Alert tone={missing ? "info" : "bad"}>
          {missing ? (
            <>
              This item is not in the backlog (any more). It may have been closed:{" "}
              <Link to="/closed/$slug" params={{ slug }} className="text-primary underline">
                look in the archive
              </Link>
              .
            </>
          ) : (
            String(item.error)
          )}
        </Alert>
      </div>
    );
  }
  const data = item.data!;
  const log = [...data.log].reverse();
  return (
    <article className="flex flex-col gap-3 p-4" aria-labelledby={`item-${slug}`}>
      <header className="flex flex-col gap-2">
        <div className="flex flex-wrap items-center gap-1.5">
          <TypeBadge type={data.type} />
          <SeverityBadge severity={data.severity} />
          <StatusBadge status={data.status} />
          <Badge variant="outline">{data.area}</Badge>
          {data.section ? (
            <Badge variant="outline">
              {data.section}
              {data.position ? ` #${data.position}` : ""}
            </Badge>
          ) : null}
          {data.ref === "main" ? <Badge variant="primary">read from main</Badge> : null}
        </div>
        <h1 id={`item-${slug}`} className={compact ? "text-base font-semibold" : "text-xl font-semibold"}>
          {data.title}
        </h1>
        {compact ? (
          <Link
            to="/items/$slug"
            params={{ slug }}
            search={{ tab: "" }}
            className="inline-flex items-center gap-1 text-xs text-primary hover:underline"
          >
            Open the full page <ExternalLinkIcon className="size-3" />
          </Link>
        ) : null}
        {data.reason ? <Alert tone={data.status === "blocked" ? "warn" : "info"}>{data.reason}</Alert> : null}
        <dl className="grid grid-cols-[repeat(auto-fill,minmax(8.5rem,1fr))] gap-2">
          <Field label="Who">{data.who}</Field>
          <Field label="Effort">{data.effort}</Field>
          <Field label="Source">{data.source}</Field>
          <Field label="Created">{data.created}</Field>
          <Field label="Updated">{relativeTime(data.updated)}</Field>
          <Field label="Verified">
            {data.verified ? `${data.verified.date} at ${data.verified.commit}` : "never"}
          </Field>
          {data.feature ? (
            <Field label="Feature">
              <a href={`/features/${data.feature}`} className="text-primary hover:underline">
                {data.feature}
              </a>
            </Field>
          ) : null}
          <Field label="Run eligibility">
            {data.eligibility.eligible ? "eligible" : (data.eligibility.reason ?? "not eligible")}
          </Field>
        </dl>
        {data.findings.length > 0 ? (
          <Alert tone="bad">
            Check findings: {data.findings.map((f) => `${f.rule}: ${f.message}`).join("; ")}
          </Alert>
        ) : null}
        <ItemActions item={data} />
      </header>
      <Tabs value={openTab} onValueChange={(value) => (onTab ? onTab(value) : setOwnTab(value))}>
        <TabsList>
          <TabsTrigger value="description">Description</TabsTrigger>
          <TabsTrigger value="log">Log ({data.log.length})</TabsTrigger>
          <TabsTrigger value="relations">Relations</TabsTrigger>
          <TabsTrigger value="files">Files</TabsTrigger>
          <TabsTrigger value="history">History</TabsTrigger>
          <TabsTrigger value="runs">Runs</TabsTrigger>
        </TabsList>
        <TabsContent value="description">
          <Description item={data} />
        </TabsContent>
        <TabsContent value="log">
          <ol className="flex flex-col gap-1.5">
            {log.map((entry, index) => (
              <li key={`${entry.date}-${index}`} className="grid grid-cols-[6.5rem_1fr] gap-2 text-sm">
                <span className="text-muted-foreground tabular-nums">{entry.date}</span>
                <span>{entry.text}</span>
              </li>
            ))}
          </ol>
        </TabsContent>
        <TabsContent value="relations">
          <dl className="grid gap-3 sm:grid-cols-3">
            <Field label="Depends on">
              <SlugLinks slugs={data.dependsOn} />
            </Field>
            <Field label="Needed by">
              <SlugLinks slugs={data.dependents} />
            </Field>
            <Field label="Related">
              <SlugLinks slugs={data.related} />
            </Field>
          </dl>
        </TabsContent>
        <TabsContent value="files">
          <Files item={data} />
        </TabsContent>
        <TabsContent value="history">
          <History slug={slug} />
        </TabsContent>
        <TabsContent value="runs">
          <ItemRuns slug={slug} />
        </TabsContent>
      </Tabs>
    </article>
  );
}
