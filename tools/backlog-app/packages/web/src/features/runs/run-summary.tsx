// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The head of a run's page (live or ended): the phase timeline of the implementation flow,
 * task progress, the tool in flight, attempts, commits, cost and the last messages.
 */

import { Link } from "@tanstack/react-router";
import { CheckIcon } from "lucide-react";
import { PHASE_ORDER, type Run } from "@backlog-app/shared";
import { OutcomeBadge } from "@/components/badges.tsx";
import { Markdown } from "@/components/markdown.tsx";
import { Alert, Badge, Card, CardHeader, CardTitle } from "@/components/ui/primitives.tsx";
import { cn, formatDuration, relativeTime } from "@/lib/utils.ts";

/**
 * The phase timeline as a row of steps.
 *
 * @param props - The run.
 * @returns The element.
 */
export function PhaseTimeline({ run }: { /** The run. */ run: Run }) {
  const phases =
    run.kind === "triage" ? (["triage", "done"] as const) : PHASE_ORDER.filter((p) => p !== "starting");
  const reached = new Set(run.phaseTimeline.map((t) => t.phase));
  const current = run.phase;
  return (
    <ol className="flex flex-wrap gap-1" aria-label="Phases">
      {phases.map((phase) => {
        const done = reached.has(phase) && phase !== current;
        const active = phase === current;
        return (
          <li
            key={phase}
            aria-current={active ? "step" : undefined}
            className={cn(
              "flex items-center gap-1 rounded-full border px-2 py-0.5 text-xs",
              done && "border-ok/40 bg-ok/10 text-ok",
              active && "border-primary bg-primary/12 font-semibold text-primary",
              !done && !active && "text-muted-foreground",
            )}
          >
            {done ? <CheckIcon className="size-3" aria-hidden /> : null}
            {phase}
          </li>
        );
      })}
      {current === "stopped" ? (
        <li className="rounded-full border border-bad/50 bg-bad/10 px-2 py-0.5 text-xs text-bad">
          stopped (blocked)
        </li>
      ) : null}
    </ol>
  );
}

/**
 * The run's summary card.
 *
 * @param props - The run.
 * @returns The element.
 */
export function RunSummary({ run }: { /** The run. */ run: Run }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex flex-wrap items-center gap-2">
          <OutcomeBadge outcome={run.outcome} />
          {run.slug ? (
            <Link
              to="/items/$slug"
              params={{ slug: run.slug }}
              search={{ tab: "" }}
              className="hover:underline"
            >
              {run.slug}
            </Link>
          ) : (
            "auto-triage"
          )}
        </CardTitle>
        <span className="text-xs text-muted-foreground">
          {run.started ? `started ${relativeTime(run.started)}` : ""} · {formatDuration(run.durationSeconds)}
        </span>
      </CardHeader>
      <div className="flex flex-col gap-3 p-4 text-sm">
        <PhaseTimeline run={run} />
        {run.tasks ? (
          <div>
            <div className="mb-1 text-xs text-muted-foreground">
              Tasks {run.tasks.done} / {run.tasks.total}
            </div>
            <div
              className="h-2 overflow-hidden rounded-full bg-muted"
              role="progressbar"
              aria-valuemin={0}
              aria-valuemax={run.tasks.total}
              aria-valuenow={run.tasks.done}
            >
              <div
                className="h-full bg-ok"
                style={{ width: `${(run.tasks.done / Math.max(1, run.tasks.total)) * 100}%` }}
              />
            </div>
          </div>
        ) : null}
        {run.currentTool ? (
          <div>
            <span className="text-xs text-muted-foreground">Running now: </span>
            <Badge variant="outline">{run.currentTool.name}</Badge>{" "}
            <code className="text-xs">{run.currentTool.summary}</code>
            {run.currentTool.since ? (
              <span className="text-xs text-muted-foreground"> · {relativeTime(run.currentTool.since)}</span>
            ) : null}
          </div>
        ) : null}
        {run.guiProbeRunning ? <Alert tone="warn">A GUI probe runs on the hidden desktop.</Alert> : null}
        <dl className="grid grid-cols-2 gap-2 sm:grid-cols-4">
          <div>
            <dt className="text-xs text-muted-foreground">Feature</dt>
            <dd>
              {run.feature ? (
                <Link
                  to="/features/$nnn"
                  params={{ nnn: run.feature }}
                  search={{ file: "" }}
                  className="text-primary hover:underline"
                >
                  {run.feature}
                </Link>
              ) : (
                "-"
              )}
            </dd>
          </div>
          <div>
            <dt className="text-xs text-muted-foreground">Branch</dt>
            <dd className="truncate">{run.branch ?? "-"}</dd>
          </div>
          <div>
            <dt className="text-xs text-muted-foreground">Attempts</dt>
            <dd>
              {run.attempts.length
                ? run.attempts
                    .map((a) => `${a.n} ${a.kind}${a.reason !== "-" ? ` (${a.reason})` : ""}`)
                    .join(", ")
                : "-"}
            </dd>
          </div>
          <div>
            <dt className="text-xs text-muted-foreground">Cost</dt>
            <dd>{run.cost ? `$${run.cost.usd.toFixed(2)}` : "-"}</dd>
          </div>
        </dl>
        {run.note ? <p className="text-sm">{run.note}</p> : null}
        {run.commits.length > 0 ? (
          <div>
            <div className="text-xs text-muted-foreground">Commits</div>
            <ul className="font-mono text-xs">
              {run.commits.map((c) => (
                <li key={c.hash}>
                  {c.hash} <span className="font-sans">{c.subject}</span>
                </li>
              ))}
            </ul>
          </div>
        ) : null}
        {run.recentMessages.length > 0 ? (
          <div>
            <div className="text-xs text-muted-foreground">Latest message</div>
            <Markdown className="rounded-md border bg-muted/40 p-2">
              {run.recentMessages.at(-1) ?? ""}
            </Markdown>
          </div>
        ) : null}
      </div>
    </Card>
  );
}
