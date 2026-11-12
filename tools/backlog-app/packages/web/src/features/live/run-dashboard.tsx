// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The run dashboard (features 415 and 419): what a person reads to follow a run without
 * knowing the trace format. One column that fills the page - the title with the run in one line,
 * a row of views, and the chosen view below it: the overview (progress head, what happens now, live
 * figures), the story in words, what is critical, the decisions, the screenshots, diagrams of the
 * solution, the files and commits, the feature's documents, the raw transcript and, while the item
 * runs, the conversation with Claude about it (every message carries a fresh snapshot of the run).
 * The page itself never scrolls: each view has one scroll area of its own. The page changes
 * nothing: it reads the trace stream and asks the server for the rest.
 */

import { useCallback, useEffect, useMemo, useState, type ReactNode } from "react";
import { laterPhase, type Phase, type Run, type TraceEvent } from "@backlog-app/shared";
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
import { ProgressHeader, progressOf, RunSummaryLine } from "./progress-header.tsx";
import { availableViews, chatMark, viewFromAddress, type RunView } from "./run-views.ts";
import { CriticalView, DecisionsView, STORY_FILTERS, StoryView, type StoryFilters } from "./story-view.tsx";
import { useInsight, useRunView } from "./use-run-insight.ts";

/** Views that show what the server reads from the run's files (asked only while shown). */
const INSIGHT_VIEWS: ReadonlySet<RunView> = new Set(["decisions", "gallery", "architecture", "documents"]);

/** Ready questions of the live chat. */
export const LIVE_QUESTIONS = [
  "What is it doing right now?",
  "What has it decided so far?",
  "What are the risks or problems?",
  "How long will it take?",
  "Explain the solution in simple words.",
] as const;

/** A view whose list or log is its one scroll area: it hands down the height it gets. */
const FILL = "flex min-h-0 flex-1 flex-col";

/** A view that scrolls as a whole, in one area of its own. */
const SCROLL = "min-h-0 flex-1 overflow-y-auto";

/**
 * The dashboard of a run.
 *
 * @param props - The run, its events, the stream's state, whether it is live, the page's heading
 *   and the view the page's address names.
 * @returns The element.
 */
export function RunDashboard({
  run,
  events,
  serverPhase = null,
  connected,
  live,
  heading,
  view: requested,
  onViewChange,
}: {
  /** The run. */ run: Run;
  /** The trace events so far. */ events: TraceEvent[];
  /** The server's phase from the trace stream (live runs), or null. */ serverPhase?: Phase | null;
  /** The stream is connected. */ connected: boolean;
  /** The run is live (follow the end, tick the clock, offer the chat). */ live: boolean;
  /** The page's heading. */ heading: ReactNode;
  /** The view the address names (anything; unknown means the overview). */ view: unknown;
  /** Puts the chosen view into the address. */ onViewChange: (view: RunView) => void;
}) {
  const showChat = live && run.slug !== null;
  const views = useMemo(() => availableViews(live, run.slug !== null), [live, run.slug]);
  const view = viewFromAddress(requested, views);
  // An address naming a view the run does not have (unknown, or the chat of an ended run) is
  // corrected to the view shown (review 2).
  useEffect(() => {
    if (typeof requested === "string" && requested !== view) onViewChange(view);
  }, [requested, view, onViewChange]);
  const nowMs = useNow(1000, live);
  const runView = useRunView(run.id, run.kind, events);
  const insight = useInsight(run.id, live && INSIGHT_VIEWS.has(view));
  const board = useBoard("");
  const title = useMemo(() => {
    if (run.title) return run.title;
    for (const section of board.data?.sections ?? [])
      for (const row of section.rows) if (row.kind === "item" && row.slug === run.slug) return row.title;
    return null;
  }, [board.data, run.slug, run.title]);
  // The page's own fold of the streamed events, never earlier than the server's fold of the same
  // trace (its `phase` stream event, else the run's phase; feature 426: a fold of a partial list
  // stayed at "Specify"); before any event, the server's phase.
  const lowerBound = laterPhase(run.phase, serverPhase);
  const folded: Phase = events.length > 0 ? laterPhase(runView.phase, lowerBound) : lowerBound;
  // A closed run is finished even when its trace ends before the last marker (the close and the
  // merge are backlog commands of the loop's own, not always in the trace).
  const phase: Phase = !live && run.outcome === "closed" && folded !== "stopped" ? "done" : folded;
  const timeline = useMemo(() => {
    const own = events.length > 0 ? runView.timeline : run.phaseTimeline;
    // The server's phase is reached even when the page's fold has not seen it.
    return own.some((t) => t.phase === folded) ? own : [...own, { phase: folded, at: null }];
  }, [events.length, runView.timeline, run.phaseTimeline, folded]);
  const progress = progressOf(run, phase, timeline, insight.data, nowMs);
  const reached = useMemo(() => new Set(timeline.map((t) => t.phase)), [timeline]);
  const commits = run.commits.length > 0 ? run.commits : runView.commits;
  const openCritical = runView.critical.filter((e) => !e.resolved).length;
  const images = insight.data?.images ?? [];

  // The story's search, filters and opened lines survive a switch to another view and back.
  const [storyFilters, setStoryFilters] = useState<StoryFilters>(STORY_FILTERS);
  // The mark on the Chat tab: something new in the conversation since the reader last saw it.
  const [chatSeen, setChatSeen] = useState<string | null>(null);
  const [chatNow, setChatNow] = useState("");
  const onSignature = useCallback((signature: string) => {
    setChatNow(signature);
    // The first report is what the conversation held when the page opened: nothing new.
    setChatSeen((seen) => seen ?? signature);
  }, []);
  // While the chat is shown, everything in it is seen (adjusted during render, not in an effect).
  if (view === "chat" && chatSeen !== null && chatSeen !== chatNow) setChatSeen(chatNow);
  const marked = showChat && chatMark(chatSeen, chatNow, view === "chat");

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
    <div className="flex min-h-0 flex-1 flex-col gap-2">
      <div className="flex flex-wrap items-center gap-x-4 gap-y-1">
        <h1 className="text-lg font-semibold">{heading}</h1>
        <RunSummaryLine run={run} title={title} progress={progress} phase={phase} />
      </div>
      <Tabs
        value={view}
        onValueChange={(v) => onViewChange(viewFromAddress(v, views))}
        className="flex min-h-0 flex-1 flex-col"
      >
        <TabsList className="flex-wrap" aria-label="Views of the run">
          <TabsTrigger value="overview">{label("Overview", null)}</TabsTrigger>
          <TabsTrigger value="story">{label("Story", null)}</TabsTrigger>
          <TabsTrigger value="critical">{label("Critical", openCritical, openCritical > 0)}</TabsTrigger>
          <TabsTrigger value="decisions">
            {label("Decisions", (insight.data?.decisions.length ?? 0) + runView.decisions.length)}
          </TabsTrigger>
          <TabsTrigger value="gallery">
            {label("Gallery", images.length || runView.images.length)}
          </TabsTrigger>
          <TabsTrigger value="architecture">{label("Architecture", null)}</TabsTrigger>
          <TabsTrigger value="files">{label("Files", runView.files.length)}</TabsTrigger>
          <TabsTrigger value="documents">
            {label("Documents", insight.data?.documents.length ?? null)}
          </TabsTrigger>
          <TabsTrigger value="trace">{label("Raw trace", null)}</TabsTrigger>
          {showChat ? (
            <TabsTrigger value="chat">
              <span className="flex items-center gap-1.5">
                Chat
                {marked ? (
                  <>
                    <span className="size-2 rounded-full bg-primary" aria-hidden />
                    <span className="sr-only">new answer</span>
                  </>
                ) : null}
              </span>
            </TabsTrigger>
          ) : null}
        </TabsList>
        <TabsContent value="overview" className={SCROLL}>
          <div className="flex flex-col gap-3">
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
              now={runView.now}
              message={runView.latestMessage}
              probe={run.guiProbeRunning}
              nowMs={nowMs}
              live={live}
            />
            <MetricsStrip
              metrics={runView.metrics}
              commits={commits.length}
              elapsedSeconds={progress.elapsedSeconds}
            />
          </div>
        </TabsContent>
        <TabsContent value="story" className={FILL}>
          <StoryView
            entries={runView.entries}
            follow={live}
            nowMs={nowMs}
            filters={storyFilters}
            onFilters={setStoryFilters}
          />
          {live && !connected ? (
            <p className="mt-1 text-xs text-muted-foreground">Connecting to the trace…</p>
          ) : null}
        </TabsContent>
        <TabsContent value="critical" className={SCROLL}>
          <CriticalView entries={runView.critical} />
        </TabsContent>
        <TabsContent value="decisions" className={SCROLL}>
          <DecisionsView
            decisions={insight.data?.decisions ?? []}
            assumptions={insight.data?.assumptions ?? []}
            stated={runView.decisions}
            folder={insight.data?.featureFolder ?? null}
          />
        </TabsContent>
        <TabsContent value="gallery" className={SCROLL}>
          <Gallery runId={run.id} images={images} />
        </TabsContent>
        <TabsContent value="architecture" className={SCROLL}>
          <ArchitectureView
            phase={phase}
            reached={reached}
            live={live}
            files={runView.files}
            diagrams={insight.data?.diagrams ?? []}
            center={run.feature ? `Feature ${run.feature}` : (run.branch?.split("-")[0] ?? "The change")}
            kind={run.kind}
          />
        </TabsContent>
        <TabsContent value="files" className={SCROLL}>
          <FilesView files={runView.files} commits={commits} />
        </TabsContent>
        <TabsContent value="documents" className={SCROLL}>
          <DocumentsView runId={run.id} insight={insight.data} live={live} />
        </TabsContent>
        <TabsContent value="trace" className={FILL}>
          <TraceView events={events} follow={live} />
        </TabsContent>
        {showChat ? (
          // Mounted while another view is shown: a draft and an answer being written survive a
          // switch (FR-008).
          <TabsContent value="chat" forceMount className={cn(FILL, "data-[state=inactive]:hidden")}>
            <section
              aria-label="Chat about the run"
              className="flex min-h-0 flex-1 flex-col rounded-lg border"
            >
              <ChatPanel
                slug={run.slug!}
                questions={LIVE_QUESTIONS}
                placeholder="Ask about the run… (Enter sends, Shift+Enter is a new line)"
                shown={view === "chat"}
                onSignature={onSignature}
                intro="Ask Claude about the run in progress: what it does, why, what it decided, what may go wrong. Every message carries a fresh snapshot of the run; Claude only reads."
              />
            </section>
          </TabsContent>
        ) : null}
      </Tabs>
    </div>
  );
}
