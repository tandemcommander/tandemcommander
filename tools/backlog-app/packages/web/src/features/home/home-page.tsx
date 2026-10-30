// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Home (analysis A4 §3.1): what needs the maintainer now, what happened since the last
 * visit (also while no tab was open - the server keeps the event log), the loop and the item the
 * next run takes, and the size of every section.
 */

import { Link } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowRightIcon, BellIcon } from "lucide-react";
import type { ItemRowView, NotificationEvent } from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import { Card, CardHeader, CardTitle, Skeleton } from "@/components/ui/primitives.tsx";
import { apiGet, apiPost } from "@/lib/api.ts";
import { useBoard, useSettings } from "@/lib/queries.ts";
import { relativeTime } from "@/lib/utils.ts";
import { useAppStore } from "@/app/store.ts";
import { loopLine } from "@/features/loop/loop-status.tsx";

/** Tone classes of events. */
const TONE: Record<NotificationEvent["severity"], string> = {
  urgent: "border-l-bad",
  attention: "border-l-warn",
  info: "border-l-info",
};

/**
 * One event line.
 *
 * @param props - The event.
 * @returns The element.
 */
function EventLine({ event }: { /** The event. */ event: NotificationEvent }) {
  const body = (
    <>
      <div className="flex items-baseline gap-2">
        <span className="font-medium">{event.title}</span>
        <span className="ml-auto shrink-0 text-xs text-muted-foreground">{relativeTime(event.at)}</span>
      </div>
      <div className="text-xs text-muted-foreground">{event.text}</div>
    </>
  );
  return (
    <li className={`border-l-4 py-1 pl-2 text-sm ${TONE[event.severity]}`}>
      {event.link ? (
        <a href={event.link} className="block hover:bg-accent/40">
          {body}
        </a>
      ) : (
        body
      )}
    </li>
  );
}

/**
 * The home page.
 *
 * @returns The element.
 */
export function HomePage() {
  const board = useBoard("");
  const settings = useSettings();
  const state = useAppStore((s) => s.state);
  const queryClient = useQueryClient();
  const lastSeen = settings.data?.lastSeenEventId ?? 0;
  const events = useQuery({
    queryKey: ["events", 0],
    queryFn: ({ signal }) => apiGet<{ events: NotificationEvent[] }>("/api/events/log?since=0", signal),
  });
  const seen = useMutation({
    mutationFn: (upTo: number) => apiPost("/api/events/seen", { upTo }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["settings"] });
      void queryClient.invalidateQueries({ queryKey: ["events"] });
    },
  });
  const all = events.data?.events ?? [];
  const unseen = all.filter((e) => e.id > lastSeen).reverse();
  const needsYou = unseen.filter((e) => e.severity !== "info");
  /**
   * The size of a section.
   *
   * @param name - The section.
   * @returns Its item count.
   */
  const count = (name: string): number => board.data?.sections.find((s) => s.name === name)?.total ?? 0;
  const next = board.data?.next.slug ?? null;
  const nextRow = board.data?.sections
    .flatMap((s) => s.rows)
    .find((r): r is ItemRowView => r.kind === "item" && r.slug === next);
  const loop = state?.loop ?? null;

  return (
    <div className="mx-auto flex w-full max-w-6xl flex-col gap-4 p-4">
      <h1 className="text-lg font-semibold">Home</h1>
      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Needs you</CardTitle>
          </CardHeader>
          <ul className="flex flex-col gap-2 p-4 text-sm">
            {loop?.shown === "stopped-for-person" ? (
              <li className="border-l-4 border-l-bad pl-2">
                <Link to="/loop" className="font-medium">
                  The loop stopped and needs you
                </Link>
                <div className="text-xs text-muted-foreground">{loop.detail}</div>
              </li>
            ) : null}
            {needsYou.map((e) => (
              <EventLine key={e.id} event={e} />
            ))}
            <li className="flex flex-wrap gap-2 pt-1">
              <Link
                to="/backlog/$section"
                params={{ section: "inbox" }}
                search={{ q: "", sel: "" }}
                className="rounded-md border px-2 py-1 hover:bg-accent"
              >
                Inbox <strong>{count("Inbox")}</strong>
              </Link>
              <Link
                to="/backlog/$section"
                params={{ section: "decisions" }}
                search={{ q: "", sel: "" }}
                className="rounded-md border px-2 py-1 hover:bg-accent"
              >
                Decisions <strong>{count("Decisions for the maintainer")}</strong>
              </Link>
              <Link
                to="/backlog/$section"
                params={{ section: "person" }}
                search={{ q: "", sel: "" }}
                className="rounded-md border px-2 py-1 hover:bg-accent"
              >
                Person steps <strong>{count("Person steps")}</strong>
              </Link>
              {(state?.check.total ?? 0) > 0 ? (
                <Link
                  to="/check"
                  className="rounded-md border border-bad/50 px-2 py-1 text-bad hover:bg-accent"
                >
                  Check findings <strong>{state?.check.total}</strong>
                </Link>
              ) : null}
              {(state?.tray.pending ?? 0) > 0 ? (
                <span className="rounded-md border border-warn/50 px-2 py-1">
                  Uncommitted changes <strong>{state?.tray.pending}</strong>
                </span>
              ) : null}
            </li>
          </ul>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>The loop</CardTitle>
            <Button asChild size="sm" variant="ghost">
              <Link to="/loop">
                Open <ArrowRightIcon />
              </Link>
            </Button>
          </CardHeader>
          <div className="flex flex-col gap-2 p-4 text-sm">
            {loop ? <div className="font-medium">{loopLine(loop)}</div> : <Skeleton className="h-5 w-1/2" />}
            {loop ? <div className="text-muted-foreground">{loop.detail}</div> : null}
            {state?.run ? (
              <Link to="/live" className="text-primary hover:underline">
                Live run of {state.run.slug ?? "the auto-triage"}: {state.run.phase}
                {state.run.tasks ? `, tasks ${state.run.tasks.done}/${state.run.tasks.total}` : ""}
              </Link>
            ) : null}
            <div>
              <span className="text-muted-foreground">Next up: </span>
              {nextRow ? (
                <Link
                  to="/items/$slug"
                  params={{ slug: nextRow.slug }}
                  search={{ tab: "" }}
                  className="text-primary hover:underline"
                >
                  {nextRow.title}
                </Link>
              ) : (
                <span>nothing eligible in Next</span>
              )}
            </div>
            {board.data && board.data.next.skipped.length > 0 ? (
              <div className="text-xs text-muted-foreground">
                Skipped above it: {board.data.next.skipped.map((s) => `${s.slug} (${s.reason})`).join("; ")}
              </div>
            ) : null}
          </div>
        </Card>
      </div>
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <BellIcon className="size-4" /> Since your last visit
          </CardTitle>
          {unseen.length > 0 ? (
            <Button
              size="sm"
              variant="ghost"
              disabled={seen.isPending}
              onClick={() => seen.mutate(all.at(-1)?.id ?? 0)}
            >
              Mark all as seen
            </Button>
          ) : null}
        </CardHeader>
        <ul className="flex flex-col gap-1.5 p-4">
          {events.isLoading ? <Skeleton className="h-10" /> : null}
          {unseen.length === 0 && !events.isLoading ? (
            <li className="text-sm text-muted-foreground">Nothing new.</li>
          ) : null}
          {unseen.map((e) => (
            <EventLine key={e.id} event={e} />
          ))}
        </ul>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle>Sections</CardTitle>
        </CardHeader>
        <div className="grid grid-cols-2 gap-2 p-4 sm:grid-cols-4 lg:grid-cols-7">
          {(board.data?.sections ?? []).map((s) => (
            <Link
              key={s.name}
              to="/backlog/$section"
              params={{
                section: {
                  "In progress": "progress",
                  Next: "next",
                  "Decisions for the maintainer": "decisions",
                  "Person steps": "person",
                  Inbox: "inbox",
                  Parked: "parked",
                  Rejected: "rejected",
                }[s.name],
              }}
              search={{ q: "", sel: "" }}
              className="rounded-md border p-2 hover:bg-accent"
            >
              <div className="text-xs text-muted-foreground">{s.name}</div>
              <div className="text-xl font-semibold tabular-nums">{s.total}</div>
            </Link>
          ))}
        </div>
      </Card>
    </div>
  );
}
