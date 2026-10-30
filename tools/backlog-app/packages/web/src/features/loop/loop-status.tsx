// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The loop's state in the top bar of every page (FR-013): the state in words, the item and
 * its phase, the usage-limit wait, and pause / resume / stop buttons. Starting the loop and the
 * hard stop are on the Loop page (they need options or a typed confirmation).
 */

import { Link } from "@tanstack/react-router";
import { useMutation } from "@tanstack/react-query";
import { CirclePauseIcon, CirclePlayIcon, CircleStopIcon } from "lucide-react";
import { toast } from "sonner";
import type { LoopShown, LoopView } from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import { Tooltip } from "@/components/ui/overlays.tsx";
import { apiPost, ApiFailure } from "@/lib/api.ts";
import { cn, relativeTime } from "@/lib/utils.ts";
import { useAppStore } from "@/app/store.ts";

/** Words and tone of each shown state. */
export const LOOP_STATE_TEXT: Record<
  LoopShown,
  { label: string; tone: "ok" | "info" | "warn" | "bad" | "muted" }
> = {
  "not-running": { label: "Loop not running", tone: "muted" },
  starting: { label: "Loop starting", tone: "info" },
  running: { label: "Running", tone: "ok" },
  triage: { label: "Auto-triage", tone: "ok" },
  waiting: { label: "Waiting", tone: "warn" },
  idle: { label: "Idle - nothing eligible", tone: "info" },
  paused: { label: "Paused", tone: "info" },
  limit: { label: "Usage limit", tone: "warn" },
  backoff: { label: "Backing off after an error", tone: "warn" },
  "pause-pending": { label: "Pause pending", tone: "info" },
  "stop-pending": { label: "Stop pending", tone: "info" },
  "kill-pending": { label: "Hard stop requested", tone: "bad" },
  dead: { label: "Loop ended without cleanup", tone: "bad" },
  "run-outside-loop": { label: "A run outside the loop", tone: "info" },
  "stopped-for-person": { label: "Stopped - needs you", tone: "bad" },
};

/** Dot colour classes by tone. */
const DOT: Record<string, string> = {
  ok: "bg-ok",
  info: "bg-info",
  warn: "bg-warn",
  bad: "bg-bad",
  muted: "bg-muted-foreground/50",
};

/**
 * Runs a loop command and reports its answer.
 *
 * @param command - `pause`, `resume` or `stop`.
 * @returns The mutation.
 */
export function useLoopCommand(command: "pause" | "resume" | "stop") {
  return useMutation({
    mutationFn: () =>
      apiPost<{ output: string }>(`/api/loop/${command}`, command === "resume" ? { commitTray: true } : {}),
    onSuccess: (answer) => toast.success(answer.output || `${command} sent`),
    onError: (error) => toast.error(error instanceof ApiFailure ? error.message : String(error)),
  });
}

/**
 * The state as one line: words, item, until-time.
 *
 * @param view - The loop view.
 * @returns The text.
 */
export function loopLine(view: LoopView): string {
  const text = LOOP_STATE_TEXT[view.shown].label;
  const item = view.slug ? ` · ${view.slug}` : "";
  const until = view.until ? ` · until ${relativeTime(view.until).replace(/^in /, "")}` : "";
  return `${text}${item}${until}`;
}

/**
 * The loop widget of the top bar.
 *
 * @returns The element.
 */
export function LoopStatus() {
  const loop = useAppStore((s) => s.state?.loop ?? null);
  const run = useAppStore((s) => s.state?.run ?? null);
  const pause = useLoopCommand("pause");
  const resume = useLoopCommand("resume");
  const stop = useLoopCommand("stop");
  if (!loop) return <span className="text-sm text-muted-foreground">Reading the loop…</span>;
  const tone = LOOP_STATE_TEXT[loop.shown].tone;
  const busy = loop.shown === "running" || loop.shown === "triage";
  return (
    <div className="flex min-w-0 items-center gap-2 text-sm">
      <Link
        to={busy ? "/live" : "/loop"}
        className="flex min-w-0 items-center gap-2 rounded-md px-1.5 py-1 hover:bg-accent"
      >
        <span
          className={cn(
            "size-2.5 shrink-0 rounded-full",
            DOT[tone],
            busy && "animate-pulse motion-reduce:animate-none",
          )}
          aria-hidden
        />
        <span className="truncate font-medium" aria-live="polite">
          {loopLine(loop)}
          {run?.phase && busy ? ` · ${run.phase}` : ""}
          {run?.tasks ? ` · tasks ${run.tasks.done}/${run.tasks.total}` : ""}
        </span>
      </Link>
      {loop.usage?.fiveHour !== null && loop.usage?.fiveHour !== undefined ? (
        <Tooltip content="Usage of the five-hour and seven-day windows as the loop last saw them">
          <span className="text-xs text-muted-foreground tabular-nums max-[1000px]:hidden">
            5h {Math.round(loop.usage.fiveHour * 100)}%
            {loop.usage.sevenDay !== null ? ` · 7d ${Math.round(loop.usage.sevenDay * 100)}%` : ""}
          </span>
        </Tooltip>
      ) : null}
      {loop.live && loop.shown !== "paused" && !loop.flags.pause ? (
        <Tooltip content="Pause: the running item finishes, then the loop waits">
          <Button
            variant="ghost"
            size="icon-sm"
            aria-label="Pause the loop"
            disabled={pause.isPending}
            onClick={() => pause.mutate()}
          >
            <CirclePauseIcon />
          </Button>
        </Tooltip>
      ) : null}
      {loop.flags.pause || loop.flags.stop ? (
        <Tooltip content="Resume (commits the change tray first); also cancels a pending stop">
          <Button
            variant="ghost"
            size="icon-sm"
            aria-label="Resume the loop"
            disabled={resume.isPending}
            onClick={() => resume.mutate()}
          >
            <CirclePlayIcon />
          </Button>
        </Tooltip>
      ) : null}
      {loop.live && !loop.flags.stop ? (
        <Tooltip content="Stop: the running item finishes, then the loop ends">
          <Button
            variant="ghost"
            size="icon-sm"
            aria-label="Stop the loop"
            disabled={stop.isPending}
            onClick={() => stop.mutate()}
          >
            <CircleStopIcon />
          </Button>
        </Tooltip>
      ) : null}
    </div>
  );
}
