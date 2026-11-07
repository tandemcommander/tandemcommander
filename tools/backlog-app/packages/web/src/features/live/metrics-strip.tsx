// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The live figures of a run (feature 415, FR-003): the price at list prices (claude's
 * reported total plus the tokens since, priced), the price per hour, input / output / cache
 * tokens, the context in use, tool calls and failures, subagents, files changed, commits and the
 * usage-limit utilisation.
 */

import {
  BotIcon,
  CoinsIcon,
  CpuIcon,
  FilePenIcon,
  GaugeIcon,
  GitCommitHorizontalIcon,
  LayersIcon,
  WrenchIcon,
  type LucideIcon,
} from "lucide-react";
import type { ReactNode } from "react";
import type { RunMetricsSnapshot } from "@backlog-app/shared";
import { cn } from "@/lib/utils.ts";

/** The context window of the current models, in tokens. */
const CONTEXT_WINDOW = 1_000_000;

/**
 * A token count in words.
 *
 * @param n - Tokens.
 * @returns `950`, `12.3 k`, `9.85 M`.
 */
export function tokenCount(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(n >= 10_000_000 ? 1 : 2)} M`;
  if (n >= 1000) return `${(n / 1000).toFixed(n >= 100_000 ? 0 : 1)} k`;
  return String(Math.round(n));
}

/**
 * One tile of the strip.
 *
 * @param props - Icon, name, value, a note and an optional bar (0-1).
 * @returns The element.
 */
function Tile({
  icon: Icon,
  name,
  value,
  note,
  bar,
  tone = "primary",
}: {
  /** The icon. */ icon: LucideIcon;
  /** The figure's name. */ name: string;
  /** The value. */ value: ReactNode;
  /** A line under it. */ note?: ReactNode;
  /** A bar 0-1. */ bar?: number | null;
  /** The bar's colour. */ tone?: "primary" | "warn" | "bad" | "ok";
}) {
  return (
    <div className="flex min-w-0 flex-col gap-0.5 rounded-lg border bg-card px-3 py-2">
      <dt className="flex items-center gap-1.5 text-[11px] text-muted-foreground uppercase">
        <Icon className="size-3.5" aria-hidden />
        {name}
      </dt>
      <dd className="truncate text-lg leading-tight font-semibold tabular-nums">{value}</dd>
      {note ? <dd className="truncate text-[11px] text-muted-foreground">{note}</dd> : null}
      {bar !== undefined && bar !== null ? (
        <dd className="mt-1 h-1.5 overflow-hidden rounded-full bg-muted" aria-hidden>
          <div
            className={cn(
              "h-full rounded-full",
              tone === "primary" && "bg-primary",
              tone === "warn" && "bg-warn",
              tone === "bad" && "bg-bad",
              tone === "ok" && "bg-ok",
            )}
            style={{ width: `${Math.min(100, Math.max(2, bar * 100))}%` }}
          />
        </dd>
      ) : null}
    </div>
  );
}

/**
 * The metrics strip.
 *
 * @param props - The figures, the commits counted elsewhere, and the elapsed seconds.
 * @returns The element.
 */
export function MetricsStrip({
  metrics,
  commits,
  elapsedSeconds,
}: {
  /** The figures. */ metrics: RunMetricsSnapshot;
  /** Commits of the run. */ commits: number;
  /** Seconds since the start. */ elapsedSeconds: number;
}) {
  const m = metrics;
  const perHour = m.costUsd !== null && elapsedSeconds > 300 ? (m.costUsd / elapsedSeconds) * 3600 : null;
  const inputAll = m.tokens.input + m.tokens.cacheRead + m.tokens.cacheWrite;
  const context = m.contextTokens;
  const fiveHour = m.limits?.fiveHour ?? null;
  const sevenDay = m.limits?.sevenDay ?? null;
  const worst = Math.max(fiveHour ?? 0, sevenDay ?? 0);
  return (
    <section aria-label="Live figures">
      <dl className="grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-4 2xl:grid-cols-8">
        <Tile
          icon={CoinsIcon}
          name="Price"
          value={
            m.costUsd === null ? (m.unpricedModels.length ? "unknown" : "—") : `$${m.costUsd.toFixed(2)}`
          }
          note={
            m.costBasis === "estimate"
              ? `estimate at list prices${perHour !== null ? ` · $${perHour.toFixed(2)}/h` : ""}`
              : m.costBasis === "reported"
                ? `reported by claude${perHour !== null ? ` · $${perHour.toFixed(2)}/h` : ""}`
                : m.unpricedModels.length
                  ? `no price for ${m.unpricedModels.join(", ")}`
                  : "no tokens yet"
          }
        />
        <Tile
          icon={LayersIcon}
          name="Tokens in"
          value={tokenCount(inputAll)}
          note={`${tokenCount(m.tokens.input)} new · ${tokenCount(m.tokens.cacheRead)} cache read · ${tokenCount(m.tokens.cacheWrite)} cache write`}
        />
        <Tile
          icon={CpuIcon}
          name="Tokens out"
          value={tokenCount(m.tokens.output)}
          note={m.costBasis === "estimate" ? "partly estimated (thinking included)" : "as reported"}
        />
        <Tile
          icon={GaugeIcon}
          name="Context"
          value={context !== null ? tokenCount(context) : "—"}
          note={
            context !== null
              ? `${Math.round((context / CONTEXT_WINDOW) * 100)} % of 1 M${m.model ? ` · ${m.model}` : ""}`
              : (m.model ?? "—")
          }
          bar={context !== null ? context / CONTEXT_WINDOW : null}
          tone={context !== null && context > 0.8 * CONTEXT_WINDOW ? "warn" : "primary"}
        />
        <Tile
          icon={WrenchIcon}
          name="Tool calls"
          value={m.toolCalls}
          note={m.toolErrors > 0 ? `${m.toolErrors} failed` : "none failed"}
        />
        <Tile icon={BotIcon} name="Subagents" value={m.subagents} note={`${m.messages} messages`} />
        <Tile
          icon={FilePenIcon}
          name="Files · commits"
          value={
            <span>
              {m.filesChanged} <span className="text-sm font-normal text-muted-foreground">·</span>{" "}
              <GitCommitHorizontalIcon className="inline size-4 align-[-2px]" aria-hidden /> {commits}
            </span>
          }
          note="files changed · commits"
        />
        <Tile
          icon={GaugeIcon}
          name="Usage limit"
          value={fiveHour !== null || sevenDay !== null ? `${Math.round(worst * 100)} %` : "—"}
          note={
            fiveHour !== null || sevenDay !== null
              ? `5 h ${fiveHour !== null ? `${Math.round(fiveHour * 100)} %` : "—"} · 7 d ${sevenDay !== null ? `${Math.round(sevenDay * 100)} %` : "—"}${m.limits && !m.limits.status.startsWith("allowed") ? " · limited" : ""}`
              : "not reported yet"
          }
          bar={fiveHour !== null || sevenDay !== null ? worst : null}
          tone={worst >= 0.9 ? "bad" : worst >= 0.75 ? "warn" : "ok"}
        />
      </dl>
    </section>
  );
}
