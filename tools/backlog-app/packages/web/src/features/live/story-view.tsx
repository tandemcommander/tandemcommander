// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The run told for people (feature 415, FR-004 - FR-006): the story grouped by phase - each
 * step with its time, icon, coloured label, its sentence in bold when it matters, its outcome in
 * colour and, when opened, its details, the lines of a collapsed group or a subagent's work; the
 * agent's messages as formatted text. Also the Critical tab (what the reader must know, open
 * first, resolved after) and the Decisions tab (what the specification records and what the agent
 * said it decided).
 */

import {
  ArrowDownIcon,
  ChevronRightIcon,
  CircleCheckIcon,
  LightbulbIcon,
  SearchIcon,
  ShieldAlertIcon,
} from "lucide-react";
import { memo, useCallback, useMemo, useRef, useState } from "react";
import { Virtuoso, type VirtuosoHandle } from "react-virtuoso";
import { localClock, type Decision, type StoryEntry } from "@backlog-app/shared";
import { Markdown } from "@/components/markdown.tsx";
import { Badge, Input } from "@/components/ui/primitives.tsx";
import { cn, formatDuration } from "@/lib/utils.ts";
import { OutcomeMark, StoryIcon, StoryLabelPill, StoryText } from "./labels.tsx";
import { timeOf } from "./progress-header.tsx";

/**
 * The time of an entry as `HH:MM`.
 *
 * @param at - ISO time, or null.
 * @returns The clock, or a dash.
 */
function hhmm(at: string | null): string {
  return at ? localClock(at) : "—";
}

/**
 * One step of the story.
 *
 * @param props - The entry, whether it is open, the toggle and the phase's duration.
 * @returns The element.
 */
const StoryRow = memo(function StoryRow({
  entry,
  open,
  onToggle,
  duration,
}: {
  /** The entry. */ entry: StoryEntry;
  /** Opened. */ open: boolean;
  /** Opens or closes it. */ onToggle: (id: string) => void;
  /** The phase's duration (phase rows). */ duration: number | null;
}) {
  if (entry.kind === "phase") {
    return (
      // The gap above the heading is padding, not a margin: a margin left the list's measured
      // height (a margin collapses out of the list's row), so the live story never reached its
      // real end - 12 px short per phase (feature 419, measured).
      <div className="pt-3">
        <div
          className={cn(
            "flex items-center gap-2 border-y px-3 py-1.5",
            entry.outcome === "fail" ? "border-bad/40 bg-bad/8" : "border-primary/25 bg-primary/6",
          )}
          role="heading"
          aria-level={3}
        >
          <StoryIcon label="PHASE" className={entry.outcome === "fail" ? "border-bad/40 text-bad" : ""} />
          <span className="text-sm font-semibold">{entry.title}</span>
          <span className="text-xs text-muted-foreground tabular-nums">
            {hhmm(entry.at)}
            {duration !== null ? ` · ${formatDuration(duration)}` : ""}
          </span>
        </div>
      </div>
    );
  }
  const openable = Boolean(entry.detail) || entry.children.length > 0;
  if (entry.kind === "message") {
    return (
      <div className="flex gap-2 px-3 py-1.5">
        <time className="w-11 shrink-0 pt-1 text-[11px] text-muted-foreground tabular-nums">
          {hhmm(entry.at)}
        </time>
        <StoryIcon label={entry.label} />
        <div
          className={cn(
            "min-w-0 flex-1 rounded-md border-l-4 px-3 py-1.5",
            entry.label === "DECISION" && "border-warn/60 bg-warn/5",
            entry.label === "REVIEW" && "border-bad/60 bg-bad/8",
            entry.label === "MESSAGE" && "border-primary/40 bg-primary/5",
          )}
        >
          <div className="mb-0.5 flex flex-wrap items-center gap-1.5">
            <StoryLabelPill label={entry.label} />
            {entry.critical ? (
              <span className="rounded-full bg-bad/14 px-1.5 text-[10px] font-semibold text-bad uppercase">
                critical
              </span>
            ) : null}
          </div>
          <div className={cn(!open && "line-clamp-6")}>
            <Markdown className="text-sm">{entry.detail ?? entry.title}</Markdown>
          </div>
          {(entry.detail ?? "").length > 400 ? (
            <button
              type="button"
              className="text-xs text-primary hover:underline"
              onClick={() => onToggle(entry.id)}
            >
              {open ? "Show less" : "Show all"}
            </button>
          ) : null}
        </div>
      </div>
    );
  }
  const important = entry.importance === "critical" || entry.importance === "high";
  return (
    <div className={cn("flex gap-2 px-3 py-1", entry.critical && !entry.resolved && "bg-bad/6")}>
      <time className="w-11 shrink-0 pt-1 text-[11px] text-muted-foreground tabular-nums">
        {hhmm(entry.at)}
      </time>
      <StoryIcon label={entry.label} />
      <div className="min-w-0 flex-1">
        <button
          type="button"
          disabled={!openable}
          aria-expanded={openable ? open : undefined}
          onClick={() => onToggle(entry.id)}
          className="flex w-full flex-wrap items-center gap-1.5 text-left disabled:cursor-default"
        >
          <StoryLabelPill label={entry.label} />
          <span
            className={cn(
              "min-w-0 text-sm",
              important ? "font-semibold" : entry.importance === "low" ? "text-muted-foreground" : "",
              entry.outcome === "fail" && "text-bad",
            )}
          >
            <StoryText text={entry.title} />
          </span>
          <OutcomeMark
            outcome={entry.outcome}
            withText={entry.outcome === "fail" || entry.outcome === "running"}
          />
          {entry.childCount > 0 ? (
            <Badge variant="outline" className="text-[10px]">
              {entry.childCount} {entry.kind === "agent" ? "steps" : "calls"}
            </Badge>
          ) : null}
          {entry.critical ? (
            <span
              className={cn(
                "rounded-full px-1.5 text-[10px] font-semibold uppercase",
                entry.resolved ? "bg-ok/12 text-ok" : "bg-bad/14 text-bad",
              )}
            >
              {entry.resolved ? "resolved" : "critical"}
            </span>
          ) : null}
          {openable ? (
            <ChevronRightIcon
              className={cn(
                "ml-auto size-3.5 text-muted-foreground transition-transform",
                open && "rotate-90",
              )}
              aria-hidden
            />
          ) : null}
        </button>
        {entry.kind === "agent" && entry.status ? (
          <p className="truncate text-xs text-muted-foreground">▸ {entry.status}</p>
        ) : null}
        {open ? (
          <div className="mt-1 flex flex-col gap-1">
            {entry.children.length > 0 ? (
              <ul className="flex flex-col gap-0.5 border-l-2 pl-2">
                {entry.children.map((c, i) => (
                  <li key={`${c.toolUseId ?? ""}-${i}`} className="flex items-center gap-1.5 text-xs">
                    <span className="w-10 shrink-0 text-muted-foreground tabular-nums">{hhmm(c.at)}</span>
                    <StoryLabelPill label={c.label} />
                    <span className="min-w-0 truncate">
                      <StoryText text={c.title} />
                    </span>
                    <OutcomeMark outcome={c.outcome} />
                  </li>
                ))}
                {entry.childCount > entry.children.length ? (
                  <li className="text-xs text-muted-foreground">
                    … and {entry.childCount - entry.children.length} more
                  </li>
                ) : null}
              </ul>
            ) : null}
            {entry.detail ? (
              // No scroll area of its own: the line grows inside the story list (feature 419).
              <div className="rounded-md border bg-muted/40 px-2 py-1">
                <Markdown className="text-xs">{entry.detail}</Markdown>
              </div>
            ) : null}
          </div>
        ) : null}
      </div>
    </div>
  );
});

/** How close to its end (px) the story counts as being at the end. */
const FOLLOW_SLACK = 80;

/** The reader's input that scrolls the story (a scroll without it is the list's own). */
const READER_EVENTS = ["wheel", "touchmove", "keydown", "pointerdown"] as const;

/** How long after the reader's input a scroll counts as the reader's (ms). */
const READER_INPUT_MS = 1000;

/**
 * The story tab.
 *
 * @param props - The entries, whether to follow the end, and now.
 * @returns The element.
 */
export function StoryView({
  entries,
  follow,
  nowMs,
}: {
  /** The entries, oldest first. */ entries: StoryEntry[];
  /** Follow the end (live). */ follow: boolean;
  /** Now. */ nowMs: number;
}) {
  const [routine, setRoutine] = useState(false);
  const [important, setImportant] = useState(false);
  const [query, setQuery] = useState("");
  const [open, setOpen] = useState<ReadonlySet<string>>(new Set());
  const list = useRef<VirtuosoHandle>(null);
  // While the run lives, the list keeps to its end until the reader scrolls away from it, and sticks
  // again when the reader reaches the end (or presses "Latest"). Decided by the reader's own input
  // (wheel, touch, keys, the scroll bar), never by the list's "at bottom" state or by scrolls the
  // list makes itself: a new line taller than its estimate left that state false, and the list
  // moves its own position while it measures lines - either stopped the story following (feature
  // 419, measured).
  const [stuck, setStuck] = useState(true);
  const stuckRef = useRef(true);
  const scroller = useRef<HTMLElement | null>(null);
  const inputAt = useRef(0);
  const stick = useCallback((value: boolean) => {
    stuckRef.current = value;
    setStuck(value);
  }, []);
  const onInput = useCallback(() => {
    inputAt.current = Date.now();
  }, []);
  const onScroll = useCallback(() => {
    const el = scroller.current;
    if (!el) return;
    if (el.scrollHeight - el.scrollTop - el.clientHeight < FOLLOW_SLACK) {
      if (!stuckRef.current) stick(true);
    } else if (stuckRef.current && Date.now() - inputAt.current < READER_INPUT_MS) stick(false);
  }, [stick]);
  const scrollerRef = useCallback(
    (el: HTMLElement | Window | null) => {
      const old = scroller.current;
      if (old) {
        old.removeEventListener("scroll", onScroll);
        for (const name of READER_EVENTS) old.removeEventListener(name, onInput);
      }
      scroller.current = el instanceof HTMLElement ? el : null;
      if (scroller.current) {
        scroller.current.addEventListener("scroll", onScroll, { passive: true });
        for (const name of READER_EVENTS) scroller.current.addEventListener(name, onInput, { passive: true });
        // A new list (a changed filter) starts at its end while the run lives.
        stick(true);
      }
    },
    [onInput, onScroll, stick],
  );
  const visible = useMemo(() => {
    const needle = query.trim().toLowerCase();
    return entries.filter((e) => {
      if (e.kind === "phase") return !needle;
      if (!routine && e.importance === "low") return false;
      if (important && !(e.importance === "critical" || e.importance === "high" || e.kind === "message"))
        return false;
      if (!needle) return true;
      return (
        e.title.toLowerCase().includes(needle) ||
        e.label.toLowerCase().includes(needle) ||
        (e.detail ?? "").toLowerCase().includes(needle)
      );
    });
  }, [entries, routine, important, query]);
  // How long each phase took: until the next phase began (or until now while it runs).
  const durations = useMemo(() => {
    const phases = entries.filter((e) => e.kind === "phase");
    const map = new Map<string, number | null>();
    phases.forEach((p, i) => {
      const from = timeOf(p.at);
      const next = phases[i + 1];
      const to = next ? timeOf(next.at) : follow ? nowMs : null;
      map.set(p.id, from !== null && to !== null ? Math.max(0, (to - from) / 1000) : null);
    });
    return map;
  }, [entries, follow, nowMs]);
  /**
   * Opens or closes an entry.
   *
   * @param id - The entry.
   */
  const toggle = (id: string): void => {
    setOpen((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };
  return (
    <div className="flex min-h-0 flex-1 flex-col gap-2">
      <div className="flex flex-wrap items-center gap-3">
        <div className="relative">
          <SearchIcon className="absolute top-1.5 left-2 size-4 text-muted-foreground" aria-hidden />
          <Input
            aria-label="Search the story"
            placeholder="Search the story"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="w-56 pl-7"
          />
        </div>
        <label className="flex items-center gap-1.5 text-xs">
          <input type="checkbox" checked={important} onChange={(e) => setImportant(e.target.checked)} />
          Only what matters
        </label>
        <label className="flex items-center gap-1.5 text-xs">
          <input type="checkbox" checked={routine} onChange={(e) => setRoutine(e.target.checked)} />
          Show routine steps
        </label>
        <span className="ml-auto text-xs text-muted-foreground">
          {visible.filter((e) => e.kind !== "phase").length} steps
        </span>
      </div>
      <div
        // The list fills the view and is its one scroll area (feature 419).
        className="relative min-h-0 flex-1 rounded-lg border bg-card"
        aria-label="The story of the run"
        role="log"
      >
        {visible.length === 0 ? (
          <p className="p-4 text-sm text-muted-foreground">
            Nothing to tell yet - the story appears as the run works.
          </p>
        ) : (
          <Virtuoso
            // A changed filter starts the list anew, at the end while the run lives: a search
            // never leaves the live story stuck in the middle.
            key={`${query}|${routine}|${important}`}
            ref={list}
            scrollerRef={scrollerRef}
            style={{ height: "100%" }}
            data={visible}
            // While the run lives the list keeps to its end as lines arrive (several a second),
            // unless the reader scrolled up; "Latest" brings it back.
            followOutput={() => (follow && stuckRef.current ? "auto" : false)}
            // A line is often taller than estimated: once measured, a stuck list goes to its very
            // end again (the measured height, not an estimate of an index).
            totalListHeightChanged={() => {
              const el = scroller.current;
              if (follow && stuckRef.current && el) el.scrollTop = el.scrollHeight;
            }}
            initialTopMostItemIndex={follow ? { index: "LAST", align: "end" } : 0}
            computeItemKey={(_, e) => e.id}
            itemContent={(_, entry) => (
              <StoryRow
                entry={entry}
                open={open.has(entry.id)}
                onToggle={toggle}
                duration={durations.get(entry.id) ?? null}
              />
            )}
          />
        )}
        {follow && !stuck && visible.length > 0 ? (
          <button
            type="button"
            onClick={() => {
              stick(true);
              list.current?.scrollToIndex({ index: "LAST", align: "end", behavior: "smooth" });
            }}
            className="absolute right-4 bottom-3 flex items-center gap-1 rounded-full bg-primary px-3 py-1 text-xs font-medium text-primary-foreground shadow-md"
          >
            <ArrowDownIcon className="size-3.5" aria-hidden /> Latest
          </button>
        ) : null}
      </div>
    </div>
  );
}

/**
 * The Critical tab: open entries first, newest first, then the resolved ones.
 *
 * @param props - The critical entries (newest first).
 * @returns The element.
 */
export function CriticalView({ entries }: { /** Critical entries, newest first. */ entries: StoryEntry[] }) {
  const open = entries.filter((e) => !e.resolved);
  const resolved = entries.filter((e) => e.resolved);
  if (entries.length === 0) {
    return (
      <p className="flex items-center gap-2 rounded-lg border border-ok/40 bg-ok/8 p-4 text-sm text-ok">
        <CircleCheckIcon className="size-5" aria-hidden /> Nothing critical so far: no failed build, test or
        probe, no stop, no usage limit, no review finding, nothing added to the backlog.
      </p>
    );
  }
  /**
   * One card.
   *
   * @param e - The entry.
   * @returns The element.
   */
  const card = (e: StoryEntry) => (
    <li
      key={e.id}
      className={cn(
        "flex gap-3 rounded-lg border p-3",
        e.resolved ? "border-border bg-muted/30 text-muted-foreground" : "border-bad/40 bg-bad/6",
      )}
    >
      <StoryIcon label={e.label} />
      <div className="min-w-0 flex-1">
        <p className={cn("text-sm font-semibold", !e.resolved && "text-bad")}>{e.critical}</p>
        <p className="mt-0.5 text-sm">
          <StoryText text={e.title} />
        </p>
        <p className="mt-1 flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
          <StoryLabelPill label={e.label} />
          <span>{hhmm(e.at)}</span>
          {e.resolved ? <span className="text-ok">resolved by a later pass</span> : null}
        </p>
      </div>
    </li>
  );
  return (
    <div className="flex flex-col gap-4">
      <section aria-label="Open">
        <h3 className="mb-2 flex items-center gap-2 text-sm font-semibold">
          <ShieldAlertIcon className="size-4 text-bad" aria-hidden /> Needs attention ({open.length})
        </h3>
        {open.length ? (
          <ul className="flex flex-col gap-2">{open.map(card)}</ul>
        ) : (
          <p className="text-sm text-muted-foreground">Nothing open.</p>
        )}
      </section>
      {resolved.length ? (
        <section aria-label="Resolved">
          <h3 className="mb-2 text-sm font-semibold text-muted-foreground">
            Resolved later ({resolved.length})
          </h3>
          <ul className="flex flex-col gap-2">{resolved.map(card)}</ul>
        </section>
      ) : null}
    </div>
  );
}

/**
 * The Decisions tab: the specification's clarifications and assumptions, and the agent's own
 * statements of what it decided.
 *
 * @param props - Recorded decisions, assumptions and the story's decision entries.
 * @returns The element.
 */
export function DecisionsView({
  decisions,
  assumptions,
  stated,
  folder,
}: {
  /** The spec's clarifications. */ decisions: Decision[];
  /** The spec's assumptions. */ assumptions: string[];
  /** Entries stating decisions. */ stated: StoryEntry[];
  /** The feature folder, if any. */ folder: string | null;
}) {
  return (
    <div className="grid gap-4 xl:grid-cols-2">
      <section aria-label="Recorded in the specification" className="flex flex-col gap-2">
        <h3 className="text-sm font-semibold">
          Recorded in the specification
          {folder ? (
            <span className="font-mono font-normal text-muted-foreground"> {folder}/spec.md</span>
          ) : null}
        </h3>
        {decisions.length === 0 && assumptions.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {folder
              ? "No clarifications recorded yet."
              : "The run has no specification yet (it is written in the specify phase)."}
          </p>
        ) : null}
        <ol className="flex flex-col gap-2">
          {decisions.map((d, i) => (
            <li key={i} className="rounded-lg border bg-card p-3">
              <p className="text-sm font-semibold">
                <span className="mr-1 text-warn">Q{i + 1}.</span>
                {d.question}
              </p>
              <p className="mt-1 text-sm">
                <span className="mr-1 font-semibold text-ok">→</span>
                {d.answer}
              </p>
              {d.how ? (
                <span className="mt-1 inline-block rounded-full border border-warn/40 bg-warn/10 px-1.5 font-mono text-[10px] font-semibold text-warn uppercase">
                  {d.how}
                </span>
              ) : null}
            </li>
          ))}
        </ol>
        {assumptions.length ? (
          <>
            <h4 className="mt-2 text-xs font-semibold tracking-wide text-muted-foreground uppercase">
              Assumptions
            </h4>
            <ul className="flex flex-col gap-1.5">
              {assumptions.map((a, i) => (
                <li key={i} className="rounded-md border-l-4 border-info/50 bg-info/6 px-3 py-1.5 text-sm">
                  {a}
                </li>
              ))}
            </ul>
          </>
        ) : null}
      </section>
      <section aria-label="Said by the agent" className="flex flex-col gap-2">
        <h3 className="text-sm font-semibold">What the agent said it decided</h3>
        {stated.length === 0 ? (
          <p className="text-sm text-muted-foreground">No statement of a decision yet.</p>
        ) : null}
        <ol className="flex flex-col gap-2">
          {stated.map((e) => (
            <li key={e.id} className="flex gap-2 rounded-lg border border-warn/30 bg-warn/5 p-3">
              <LightbulbIcon className="mt-0.5 size-4 shrink-0 text-warn" aria-hidden />
              <div className="min-w-0">
                <p className="text-[11px] text-muted-foreground">{hhmm(e.at)}</p>
                <Markdown className="text-sm">{e.detail ?? e.title}</Markdown>
              </div>
            </li>
          ))}
        </ol>
      </section>
    </div>
  );
}
