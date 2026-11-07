// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The run dashboard (feature 415): what a person reads to follow a run without knowing the
 * trace format - the progress head, what happens now, the live figures, and tabs: the story in
 * words, what is critical, the decisions, the screenshots, diagrams of the solution, the files and
 * commits, the feature's documents and the raw transcript. Beside it, while the item runs, the
 * conversation with Claude about the item; every message carries a fresh snapshot of the run.
 * The page changes nothing: it reads the trace stream and asks the server for the rest.
 */

import { MessageSquareTextIcon, PanelRightCloseIcon } from "lucide-react";
import { useMemo, useState } from "react";
import type { Phase, Run, TraceEvent } from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/overlays.tsx";
import { useBoard } from "@/lib/queries.ts";
import { useNow } from "@/lib/now.ts";
import { cn } from "@/lib/utils.ts";
import { ChatPanel } from "@/features/chat/chat-panel.tsx";
import { TraceView } from "@/features/runs/trace-view.tsx";
import { ArchitectureView } from "./architecture-view.tsx";
import { DocumentsView, FilesView } from "./documents-view.tsx";
import { Gallery } from "./gallery.tsx";
import { MetricsStrip } from "./metrics-strip.tsx";
import { NowPanel } from "./now-panel.tsx";
import { ProgressHeader, progressOf } from "./progress-header.tsx";
import { CriticalView, DecisionsView, StoryView } from "./story-view.tsx";
import { useInsight, useRunView } from "./use-run-insight.ts";

/** The tabs of the dashboard. */
export const TABS = [
  "story",
  "critical",
  "decisions",
  "gallery",
  "architecture",
  "files",
  "documents",
  "trace",
] as const;

/** One tab. */
type Tab = (typeof TABS)[number];

/** Tabs that show what the server reads from the run's files (asked only while shown). */
const INSIGHT_TABS: ReadonlySet<Tab> = new Set(["decisions", "gallery", "architecture", "documents"]);

/** Storage key of the chat column's state. */
const CHAT_KEY = "backlog-app.live.chat";

/** Ready questions of the live chat. */
export const LIVE_QUESTIONS = [
  "What is it doing right now?",
  "What has it decided so far?",
  "What are the risks or problems?",
  "How long will it take?",
  "Explain the solution in simple words.",
] as const;

/**
 * Whether the chat column starts open: remembered in the browser, else open on a wide window.
 *
 * @returns True when open.
 */
function initialChat(): boolean {
  try {
    const stored = window.localStorage.getItem(CHAT_KEY);
    if (stored === "open") return true;
    if (stored === "closed") return false;
  } catch {
    // No storage: the default.
  }
  return typeof window.matchMedia === "function" ? window.matchMedia("(min-width: 1280px)").matches : true;
}

/**
 * The dashboard of a run.
 *
 * @param props - The run, its events, the stream's state and whether it is live.
 * @returns The element.
 */
export function RunDashboard({
  run,
  events,
  connected,
  live,
}: {
  /** The run. */ run: Run;
  /** The trace events so far. */ events: TraceEvent[];
  /** The stream is connected. */ connected: boolean;
  /** The run is live (follow the end, tick the clock, offer the chat). */ live: boolean;
}) {
  const [tab, setTab] = useState<Tab>("story");
  const [chat, setChat] = useState(initialChat);
  const nowMs = useNow(1000, live);
  const view = useRunView(run.id, run.kind, events);
  const insight = useInsight(run.id, live && INSIGHT_TABS.has(tab));
  const board = useBoard("");
  const title = useMemo(() => {
    if (run.title) return run.title;
    for (const section of board.data?.sections ?? [])
      for (const row of section.rows) if (row.kind === "item" && row.slug === run.slug) return row.title;
    return null;
  }, [board.data, run.slug, run.title]);
  // The fold of the full trace knows the phase as well as the server; before any event, the
  // server's phase.
  const folded: Phase = events.length > 0 ? view.phase : run.phase;
  // A closed run is finished even when its trace ends before the last marker (the close and the
  // merge are backlog commands of the loop's own, not always in the trace).
  const phase: Phase = !live && run.outcome === "closed" && folded !== "stopped" ? "done" : folded;
  const timeline = events.length > 0 ? view.timeline : run.phaseTimeline;
  const progress = progressOf(run, phase, timeline, insight.data, nowMs);
  const reached = useMemo(() => new Set(timeline.map((t) => t.phase)), [timeline]);
  const commits = run.commits.length > 0 ? run.commits : view.commits;
  const openCritical = view.critical.filter((e) => !e.resolved).length;
  const images = insight.data?.images ?? [];
  const showChat = live && run.slug !== null;
  /**
   * Opens or closes the chat column and remembers it.
   *
   * @param open - The new state.
   */
  const toggleChat = (open: boolean): void => {
    setChat(open);
    try {
      window.localStorage.setItem(CHAT_KEY, open ? "open" : "closed");
    } catch {
      // Not remembered.
    }
  };
  /**
   * A tab's label with a count.
   *
   * @param name - The name.
   * @param count - The count, or null.
   * @param alert - Show the count in the alert colour.
   * @returns The label.
   */
  const label = (name: string, count: number | null, alert = false) => (
    <span className="flex items-center gap-1.5">
      {name}
      {count !== null && count > 0 ? (
        <span
          className={cn(
            "rounded-full px-1.5 text-[11px] leading-4 font-semibold tabular-nums",
            alert ? "bg-bad text-destructive-foreground" : "bg-muted text-muted-foreground",
          )}
        >
          {count}
        </span>
      ) : null}
    </span>
  );
  return (
    <div className="flex min-h-0 w-full gap-4">
      <div className="flex min-w-0 flex-1 flex-col gap-3">
        <ProgressHeader
          run={run}
          title={title}
          progress={progress}
          phase={phase}
          timeline={timeline}
          nowMs={nowMs}
          live={live}
        />
        <NowPanel
          now={view.now}
          message={view.latestMessage}
          probe={run.guiProbeRunning}
          nowMs={nowMs}
          live={live}
        />
        <MetricsStrip
          metrics={view.metrics}
          commits={commits.length}
          elapsedSeconds={progress.elapsedSeconds}
        />
        {showChat && !chat ? (
          <div className="flex justify-end">
            <Button variant="outline" size="sm" onClick={() => toggleChat(true)}>
              <MessageSquareTextIcon /> Ask about the run
            </Button>
          </div>
        ) : null}
        <Tabs value={tab} onValueChange={(v) => setTab(v as Tab)} className="flex min-h-0 flex-col">
          <TabsList className="flex-wrap" aria-label="Views of the run">
            <TabsTrigger value="story">{label("Story", null)}</TabsTrigger>
            <TabsTrigger value="critical">{label("Critical", openCritical, openCritical > 0)}</TabsTrigger>
            <TabsTrigger value="decisions">
              {label("Decisions", (insight.data?.decisions.length ?? 0) + view.decisions.length)}
            </TabsTrigger>
            <TabsTrigger value="gallery">{label("Gallery", images.length || view.images.length)}</TabsTrigger>
            <TabsTrigger value="architecture">{label("Architecture", null)}</TabsTrigger>
            <TabsTrigger value="files">{label("Files", view.files.length)}</TabsTrigger>
            <TabsTrigger value="documents">
              {label("Documents", insight.data?.documents.length ?? null)}
            </TabsTrigger>
            <TabsTrigger value="trace">{label("Raw trace", null)}</TabsTrigger>
          </TabsList>
          <TabsContent value="story">
            <StoryView entries={view.entries} follow={live} nowMs={nowMs} />
            {live && !connected ? (
              <p className="mt-1 text-xs text-muted-foreground">Connecting to the trace…</p>
            ) : null}
          </TabsContent>
          <TabsContent value="critical">
            <CriticalView entries={view.critical} />
          </TabsContent>
          <TabsContent value="decisions">
            <DecisionsView
              decisions={insight.data?.decisions ?? []}
              assumptions={insight.data?.assumptions ?? []}
              stated={view.decisions}
              folder={insight.data?.featureFolder ?? null}
            />
          </TabsContent>
          <TabsContent value="gallery">
            <Gallery runId={run.id} images={images} />
          </TabsContent>
          <TabsContent value="architecture">
            <ArchitectureView
              phase={phase}
              reached={reached}
              live={live}
              files={view.files}
              diagrams={insight.data?.diagrams ?? []}
              center={run.feature ? `Feature ${run.feature}` : (run.branch?.split("-")[0] ?? "The change")}
              kind={run.kind}
            />
          </TabsContent>
          <TabsContent value="files">
            <FilesView files={view.files} commits={commits} />
          </TabsContent>
          <TabsContent value="documents">
            <DocumentsView runId={run.id} insight={insight.data} live={live} />
          </TabsContent>
          <TabsContent value="trace">
            <TraceView events={events} follow={live} />
          </TabsContent>
        </Tabs>
      </div>
      {showChat && chat ? (
        <aside
          aria-label="Chat about the run"
          className="fixed inset-y-0 right-0 z-40 flex w-full max-w-md flex-col border-l bg-background shadow-xl min-[1280px]:sticky min-[1280px]:top-0 min-[1280px]:z-auto min-[1280px]:h-[calc(100vh-5rem)] min-[1280px]:w-[24rem] min-[1280px]:shrink-0 min-[1280px]:rounded-lg min-[1280px]:border min-[1280px]:shadow-none"
        >
          <div className="flex items-center gap-2 border-b px-4 py-2">
            <MessageSquareTextIcon className="size-4 text-primary" aria-hidden />
            <h2 className="text-sm font-semibold">Ask about the run</h2>
            <Button
              variant="ghost"
              size="sm"
              className="ml-auto"
              aria-label="Hide the chat"
              onClick={() => toggleChat(false)}
            >
              <PanelRightCloseIcon />
            </Button>
          </div>
          <ChatPanel
            slug={run.slug!}
            questions={LIVE_QUESTIONS}
            compact
            intro="Ask Claude about the run in progress: what it does, why, what it decided, what may go wrong. Every message carries a fresh snapshot of the run; Claude only reads."
          />
        </aside>
      ) : null}
    </div>
  );
}
