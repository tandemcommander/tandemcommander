// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The head of the run dashboard (feature 415, FR-001): the item, its feature and branch, a
 * progress bar with the percentage, the elapsed time, the expected remaining time and the expected
 * end (an estimate, with its basis), and the steps of the implementation flow in words with the
 * time each took.
 */

import { Link } from "@tanstack/react-router";
import { CheckIcon, Clock3Icon, FlagIcon, HourglassIcon, LoaderIcon, TimerIcon } from "lucide-react";
import {
  estimateProgress,
  PHASE_ORDER,
  PHASE_TITLES,
  type Phase,
  type ProgressEstimate,
  type Run,
  type RunInsight,
} from "@backlog-app/shared";
import { OutcomeBadge } from "@/components/badges.tsx";
import { cn, formatDuration } from "@/lib/utils.ts";

/** Short names of the phases for the steps. */
const SHORT: Readonly<Partial<Record<Phase, string>>> = {
  selection: "Select",
  measure: "Measure",
  specify: "Specify",
  clarify: "Clarify",
  plan: "Plan",
  tasks: "Tasks",
  analyze: "Analyze",
  implement: "Implement",
  verify: "Verify",
  review: "Review",
  close: "Close",
  merge: "Merge",
  done: "Done",
};

/**
 * Epoch ms of a time the run records (local `YYYY-MM-DD HH:MM:SS`, or ISO).
 *
 * @param value - The time.
 * @returns Epoch ms, or null.
 */
export function timeOf(value: string | null | undefined): number | null {
  if (!value) return null;
  const ms = Date.parse(value.includes("T") ? value : value.replace(" ", "T"));
  return Number.isNaN(ms) ? null : ms;
}

/**
 * The progress of a run now.
 *
 * @param run - The run.
 * @param phase - The phase of the story.
 * @param timeline - When each phase began.
 * @param insight - The estimate basis.
 * @param nowMs - Now.
 * @returns The estimate.
 */
export function progressOf(
  run: Run,
  phase: Phase,
  timeline: { phase: Phase; at: string | null }[],
  insight: RunInsight | undefined,
  nowMs: number,
): ProgressEstimate {
  const started = timeOf(run.started);
  const live = run.outcome === "running";
  const elapsed =
    live && started !== null ? (nowMs - started) / 1000 : (run.durationSeconds ?? (started ? 0 : 0));
  const finished = !live && run.outcome !== "running";
  const current = timeline.filter((t) => t.phase === phase).at(-1)?.at ?? null;
  return estimateProgress({
    phase: finished && phase !== "stopped" ? "done" : phase,
    kind: run.kind,
    phaseStartedMs: timeOf(current),
    tasks: run.tasks,
    elapsedSeconds: elapsed,
    history: insight?.estimate ?? { medianSeconds: null, count: 0 },
    nowMs,
  });
}

/**
 * A clock time, with the day when it is not today.
 *
 * @param ms - Epoch ms.
 * @param nowMs - Now.
 * @returns `15:54` or `Sat 09:12`.
 */
function clock(ms: number, nowMs: number): string {
  const d = new Date(ms);
  const time = d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  return new Date(nowMs).toDateString() === d.toDateString()
    ? time
    : `${d.toLocaleDateString([], { weekday: "short" })} ${time}`;
}

/**
 * The steps of the flow with their state and duration.
 *
 * @param props - The run's phase and timeline, and now.
 * @returns The element.
 */
export function PhaseSteps({
  kind,
  phase,
  timeline,
  nowMs,
  live,
}: {
  /** The run kind. */ kind: Run["kind"];
  /** The current phase. */ phase: Phase;
  /** When each phase began. */ timeline: { phase: Phase; at: string | null }[];
  /** Now. */ nowMs: number;
  /** The run is live. */ live: boolean;
}) {
  if (kind === "triage") return null;
  const phases = PHASE_ORDER.filter((p) => p !== "starting" && p !== "done");
  const started = new Map<Phase, number | null>();
  for (const t of timeline) if (!started.has(t.phase)) started.set(t.phase, timeOf(t.at));
  const index = PHASE_ORDER.indexOf(phase);
  const stopped = phase === "stopped";
  /**
   * How long a phase took (until the next phase began), or runs now.
   *
   * @param p - The phase.
   * @returns Seconds, or null.
   */
  const took = (p: Phase): number | null => {
    const from = started.get(p);
    if (from === undefined || from === null) return null;
    const later = timeline.map((t) => timeOf(t.at)).filter((t): t is number => t !== null && t > from);
    const next = later.length ? Math.min(...later) : p === phase && live ? nowMs : null;
    return next === null ? null : (next - from) / 1000;
  };
  return (
    <ol className="flex flex-wrap gap-1.5" aria-label="Steps of the run">
      {phases.map((p) => {
        const reached = started.has(p);
        const active = p === phase && !stopped;
        const done =
          (reached && !active) || (!stopped && PHASE_ORDER.indexOf(p) < index && phase !== "starting");
        const seconds = reached ? took(p) : null;
        return (
          <li
            key={p}
            aria-current={active ? "step" : undefined}
            title={PHASE_TITLES[p]}
            className={cn(
              "flex min-w-[4.5rem] flex-col rounded-md border px-2 py-1 text-xs",
              done && "border-ok/40 bg-ok/8",
              active && "border-primary bg-primary/12 shadow-sm",
              !done && !active && "border-dashed text-muted-foreground",
            )}
          >
            <span
              className={cn(
                "flex items-center gap-1 font-medium",
                active && "text-primary",
                done && "text-ok",
              )}
            >
              {done ? (
                <CheckIcon className="size-3" aria-hidden />
              ) : active && live ? (
                <LoaderIcon className="size-3 animate-spin motion-reduce:animate-none" aria-hidden />
              ) : null}
              {SHORT[p] ?? p}
            </span>
            <span className="text-[10px] text-muted-foreground tabular-nums">
              {seconds !== null ? formatDuration(seconds) : done ? "skipped" : " "}
            </span>
          </li>
        );
      })}
      {stopped ? (
        <li className="flex items-center rounded-md border border-bad/50 bg-bad/10 px-2 py-1 text-xs font-medium text-bad">
          stopped - the item is blocked
        </li>
      ) : null}
    </ol>
  );
}

/**
 * The head of the dashboard.
 *
 * @param props - The run, its progress and phase, and whether it is live.
 * @returns The element.
 */
export function ProgressHeader({
  run,
  title,
  progress,
  phase,
  timeline,
  nowMs,
  live,
}: {
  /** The run. */ run: Run;
  /** The item's title, when known. */ title: string | null;
  /** The estimate. */ progress: ProgressEstimate;
  /** The current phase. */ phase: Phase;
  /** When each phase began. */ timeline: { phase: Phase; at: string | null }[];
  /** Now. */ nowMs: number;
  /** The run is live. */ live: boolean;
}) {
  const percent = Math.round(progress.fraction * 100);
  return (
    <section className="flex flex-col gap-3 rounded-lg border bg-card p-4" aria-label="Run progress">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <OutcomeBadge outcome={run.outcome} />
            <span className="text-xs text-muted-foreground">
              {run.kind === "triage" ? "Auto-triage of the Inbox" : PHASE_TITLES[phase]}
            </span>
          </div>
          <h2 className="mt-1 text-lg leading-snug font-semibold">
            {run.slug ? (
              <Link
                to="/items/$slug"
                params={{ slug: run.slug }}
                search={{ tab: "" }}
                className="hover:underline"
              >
                {title ?? run.slug}
              </Link>
            ) : (
              "Auto-triage"
            )}
          </h2>
          <div className="flex flex-wrap gap-x-3 text-xs text-muted-foreground">
            {run.slug && title ? <span className="font-mono">{run.slug}</span> : null}
            {run.feature ? <span>feature {run.feature}</span> : null}
            {run.branch ? <span className="font-mono">{run.branch}</span> : null}
          </div>
        </div>
        <div className="text-right">
          <div className="text-3xl leading-none font-semibold tabular-nums" aria-hidden>
            {percent}
            <span className="text-lg text-muted-foreground">%</span>
          </div>
          <div className="text-[11px] text-muted-foreground">
            {progress.finished ? progress.basis : "estimated"}
          </div>
        </div>
      </div>
      <div
        className="relative h-3 overflow-hidden rounded-full bg-muted"
        role="progressbar"
        aria-label="Progress of the run (estimate)"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={percent}
        aria-valuetext={`${percent} %, ${progress.finished ? "finished" : `about ${formatDuration(progress.remainingSeconds)} left`}`}
      >
        <div
          className={cn(
            "h-full rounded-full transition-[width] duration-700",
            phase === "stopped"
              ? "bg-bad"
              : progress.finished
                ? "bg-ok"
                : "bg-gradient-to-r from-primary/70 to-primary",
          )}
          style={{ width: `${Math.max(2, percent)}%` }}
        />
        {live && !progress.finished ? (
          <div
            className="absolute inset-y-0 w-16 animate-pulse bg-white/20 motion-reduce:hidden"
            style={{ left: `calc(${percent}% - 4rem)` }}
          />
        ) : null}
      </div>
      <dl className="grid grid-cols-2 gap-2 text-sm sm:grid-cols-4">
        <div>
          <dt className="flex items-center gap-1.5 text-[11px] text-muted-foreground uppercase">
            <TimerIcon className="size-3.5" aria-hidden />
            Elapsed
          </dt>
          <dd className="font-medium tabular-nums">{formatDuration(progress.elapsedSeconds)}</dd>
        </div>
        <div>
          <dt className="flex items-center gap-1.5 text-[11px] text-muted-foreground uppercase">
            <HourglassIcon className="size-3.5" aria-hidden />
            Remaining
          </dt>
          <dd className="font-medium tabular-nums">
            {progress.finished ? "—" : `≈ ${formatDuration(progress.remainingSeconds)}`}
          </dd>
        </div>
        <div>
          <dt className="flex items-center gap-1.5 text-[11px] text-muted-foreground uppercase">
            <Clock3Icon className="size-3.5" aria-hidden />
            Expected end
          </dt>
          <dd className="font-medium tabular-nums">
            {progress.finished
              ? run.ended
                ? clock(timeOf(run.ended) ?? nowMs, nowMs)
                : "—"
              : `≈ ${clock(progress.expectedEndMs, nowMs)}`}
          </dd>
        </div>
        <div>
          <dt className="flex items-center gap-1.5 text-[11px] text-muted-foreground uppercase">
            <FlagIcon className="size-3.5" aria-hidden />
            Tasks
          </dt>
          <dd className="font-medium tabular-nums">
            {run.tasks ? `${run.tasks.done} / ${run.tasks.total}` : "—"}
          </dd>
        </div>
      </dl>
      {!progress.finished ? (
        <p className="text-[11px] text-muted-foreground">Estimate: {progress.basis}.</p>
      ) : null}
      <PhaseSteps kind={run.kind} phase={phase} timeline={timeline} nowMs={nowMs} live={live} />
    </section>
  );
}
