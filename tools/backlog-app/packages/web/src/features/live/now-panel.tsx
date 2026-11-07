// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file What happens now (feature 415, FR-002): the current activity in one sentence and since
 * when, a warning while a GUI probe runs on the hidden desktop, and the agent's latest message.
 */

import { MonitorIcon } from "lucide-react";
import type { StoryEntry, StoryNow } from "@backlog-app/shared";
import { Markdown } from "@/components/markdown.tsx";
import { cn, formatDuration } from "@/lib/utils.ts";
import { StoryIcon, StoryLabelPill, StoryText } from "./labels.tsx";
import { timeOf } from "./progress-header.tsx";

/**
 * The "now" panel.
 *
 * @param props - The activity, the latest message, a running probe, now and whether it is live.
 * @returns The element.
 */
export function NowPanel({
  now,
  message,
  probe,
  nowMs,
  live,
}: {
  /** The current activity. */ now: StoryNow | null;
  /** The agent's latest message. */ message: StoryEntry | null;
  /** A GUI probe runs. */ probe: boolean;
  /** Now. */ nowMs: number;
  /** The run is live. */ live: boolean;
}) {
  const since = timeOf(now?.since ?? null);
  return (
    <section
      className="grid gap-3 rounded-lg border bg-card p-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.2fr)]"
      aria-label="What happens now"
    >
      <div className="flex min-w-0 flex-col gap-2">
        <h2 className="flex items-center gap-2 text-xs font-semibold tracking-wide text-muted-foreground uppercase">
          <span
            className={cn(
              "inline-block size-2 rounded-full",
              live && now?.running
                ? "animate-pulse bg-ok motion-reduce:animate-none"
                : "bg-muted-foreground/40",
            )}
            aria-hidden
          />
          {live ? "Now" : "Last step"}
        </h2>
        {now ? (
          <div className="flex items-start gap-2">
            <StoryIcon label={now.label} className="mt-0.5 size-7" />
            <div className="min-w-0">
              <p className="text-base leading-snug font-semibold" aria-live="polite">
                <StoryText text={now.title} />
              </p>
              <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                <StoryLabelPill label={now.label} />
                {since !== null ? (
                  <span>
                    {now.running ? "for " : ""}
                    {formatDuration(Math.max(0, (nowMs - since) / 1000))}
                    {now.running ? "" : " ago"}
                  </span>
                ) : null}
              </div>
            </div>
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">Nothing has happened yet.</p>
        )}
        {probe ? (
          <p className="flex items-center gap-2 rounded-md border border-warn/40 bg-warn/10 px-2 py-1 text-xs text-warn">
            <MonitorIcon className="size-3.5" aria-hidden /> A GUI probe runs on the hidden desktop - a hard
            stop now leaves its registry backup to be restored.
          </p>
        ) : null}
      </div>
      <div className="min-w-0 border-t pt-3 lg:border-t-0 lg:border-l lg:pt-0 lg:pl-3">
        <h2 className="text-xs font-semibold tracking-wide text-muted-foreground uppercase">
          The agent's latest message
        </h2>
        {message ? (
          <div className="mt-1 max-h-48 overflow-y-auto rounded-md border-l-4 border-primary/50 bg-primary/5 px-3 py-2">
            <Markdown className="text-sm">{message.detail ?? message.title}</Markdown>
          </div>
        ) : (
          <p className="mt-1 text-sm text-muted-foreground">No message yet.</p>
        )}
      </div>
    </section>
  );
}
