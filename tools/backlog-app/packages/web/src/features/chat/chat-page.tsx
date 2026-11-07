// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The conversation with Claude about one item (feature 371, user story 4; FR-014 -
 * FR-020): opened in its own window without the app's frame, the item's essentials at the top,
 * the transcript below, a composer at the bottom. Replies stream in as they are produced (the
 * conversation stream); Claude's tool uses show as short lines; a reply can be stopped; the
 * transcript is kept on the server and shown again after a reload. Claude only reads.
 */

import { getRouteApi } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import type { ChatContext } from "@backlog-app/shared";
import { SeverityBadge, StatusBadge, TypeBadge } from "@/components/badges.tsx";
import { Markdown } from "@/components/markdown.tsx";
import { Alert, Badge, Skeleton } from "@/components/ui/primitives.tsx";
import { ChatPanel, useChatContext } from "./chat-panel.tsx";

/** The route. */
const route = getRouteApi("/items/$slug/chat");

/**
 * The item's essentials.
 *
 * @param props - The context.
 * @returns The element.
 */
function Essentials({ context }: { /** The context. */ context: ChatContext }) {
  const { item } = context;
  const [open, setOpen] = useState(false);
  return (
    <header className="flex flex-col gap-2 border-b px-4 py-3" aria-label="The item">
      <div className="flex flex-wrap items-center gap-1.5">
        <TypeBadge type={item.type} />
        <SeverityBadge severity={item.severity} />
        <StatusBadge status={item.status} />
        <Badge variant="outline">{item.area}</Badge>
        {item.section ? (
          <Badge variant="outline">
            {item.section}
            {item.position ? ` #${item.position}` : ""}
          </Badge>
        ) : null}
        {context.running ? <Badge variant="primary">a run works on it now</Badge> : null}
      </div>
      <h1 className="text-lg font-semibold">
        {item.title} <span className="font-mono text-sm font-normal text-muted-foreground">{item.slug}</span>
      </h1>
      <dl className="grid grid-cols-[repeat(auto-fill,minmax(9rem,1fr))] gap-x-3 gap-y-1 text-sm">
        <div>
          <dt className="text-[11px] text-muted-foreground uppercase">Who / effort</dt>
          <dd>
            {item.who} / {item.effort}
          </dd>
        </div>
        <div>
          <dt className="text-[11px] text-muted-foreground uppercase">Source</dt>
          <dd>{item.source}</dd>
        </div>
        <div>
          <dt className="text-[11px] text-muted-foreground uppercase">Created / updated</dt>
          <dd>
            {item.created} / {item.updated}
          </dd>
        </div>
        <div>
          <dt className="text-[11px] text-muted-foreground uppercase">Feature</dt>
          <dd>
            {item.feature ?? "-"}
            {context.featureFolder ? ` (${context.featureFolder})` : ""}
          </dd>
        </div>
        <div>
          <dt className="text-[11px] text-muted-foreground uppercase">Runs</dt>
          <dd>
            {context.runs.length === 0
              ? "none"
              : context.runs
                  .slice(0, 3)
                  .map((r) => `${r.outcome}${r.feature ? ` (${r.feature})` : ""}`)
                  .join(", ")}
          </dd>
        </div>
        <div>
          <dt className="text-[11px] text-muted-foreground uppercase">Related / depends on</dt>
          <dd>{[...item.related, ...item.dependsOn].join(", ") || "none"}</dd>
        </div>
        <div>
          <dt className="text-[11px] text-muted-foreground uppercase">Claude reads</dt>
          <dd>branch {context.branch}</dd>
        </div>
      </dl>
      {item.reason ? <Alert tone="info">{item.reason}</Alert> : null}
      <button
        type="button"
        className="self-start text-xs text-primary hover:underline"
        aria-expanded={open}
        onClick={() => setOpen((o) => !o)}
      >
        {open ? "Hide the description" : "Show the description"}
      </button>
      {open ? (
        <div className="max-h-[40vh] overflow-y-auto rounded-md border p-3">
          {item.body
            .filter((s) => s.name !== "Log")
            .map((s) => (
              <section key={s.name}>
                <h3 className="mt-2 text-xs font-semibold tracking-wide text-muted-foreground uppercase">
                  {s.name}
                </h3>
                <Markdown>{s.markdown}</Markdown>
              </section>
            ))}
        </div>
      ) : null}
    </header>
  );
}

/**
 * The conversation page.
 *
 * @returns The element.
 */
export function ChatPage() {
  const { slug } = route.useParams();
  const context = useChatContext(slug);
  useEffect(() => {
    document.title = context.data ? `Chat: ${context.data.item.title}` : "Chat";
  }, [context.data]);
  return (
    <div className="flex h-full flex-col bg-background text-foreground">
      {context.data ? (
        <Essentials context={context.data} />
      ) : context.error ? (
        <div className="p-4">
          <Alert tone="bad">{String(context.error)}</Alert>
        </div>
      ) : (
        <div className="flex flex-col gap-2 p-4">
          <Skeleton className="h-6 w-2/3" />
          <Skeleton className="h-16" />
        </div>
      )}
      <main className="flex min-h-0 flex-1 flex-col">
        <ChatPanel slug={slug} />
      </main>
    </div>
  );
}
