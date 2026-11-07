// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The run's story and figures in the browser (feature 415, research R10): the events the
 * trace stream delivers are folded incrementally - only new events are applied; a new run, a reset
 * stream or a list trimmed at its start folds again from the beginning. Also the queries of the
 * run's insight (documents, decisions, gallery, estimate basis) and its documents, asked only
 * while their tab is shown (at most every 10 s), and gallery images fetched with the session
 * token as object URLs.
 */

import { useQuery } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";
import {
  RunMetrics,
  RunStory,
  type RunInsight,
  type RunMetricsSnapshot,
  type StoryEntry,
  type StoryFile,
  type StoryNow,
  type TraceEvent,
} from "@backlog-app/shared";
import { apiGet, currentToken } from "@/lib/api.ts";

/** The fold of one run. */
interface Fold {
  /** The story. */
  story: RunStory;
  /** The figures. */
  metrics: RunMetrics;
  /** Events applied. */
  applied: number;
  /** Offset of the first event applied (a trimmed list starts elsewhere). */
  first: number | null;
}

/** Folds by run id (at most a few: the live run and the pages opened). */
const folds = new Map<string, Fold>();

/** What the views read of a fold. */
export interface RunView {
  /** The story's entries, oldest first. */
  entries: StoryEntry[];
  /** Critical entries, newest first. */
  critical: StoryEntry[];
  /** Entries stating decisions. */
  decisions: StoryEntry[];
  /** Images the trace names. */
  images: { path: string; at: string | null }[];
  /** Files changed. */
  files: StoryFile[];
  /** Commits the results showed. */
  commits: { hash: string; subject: string }[];
  /** What happens now. */
  now: StoryNow | null;
  /** The latest message of the agent. */
  latestMessage: StoryEntry | null;
  /** The figures. */
  metrics: RunMetricsSnapshot;
  /** The phase and its timeline. */
  phase: RunStory["state"]["phase"];
  /** When each phase was first seen. */
  timeline: { phase: RunStory["state"]["phase"]; at: string | null }[];
}

/**
 * Folds the new events of a run.
 *
 * @param id - The run id.
 * @param kind - `item` or `triage`.
 * @param events - All events so far (the stream's list).
 * @returns The fold, up to date.
 */
function foldFor(id: string, kind: "item" | "triage", events: readonly TraceEvent[]): Fold {
  let fold = folds.get(id);
  const first = events[0]?.offset ?? null;
  if (!fold || events.length < fold.applied || (fold.first !== null && first !== fold.first)) {
    fold = { story: new RunStory(kind), metrics: new RunMetrics(), applied: 0, first };
    folds.set(id, fold);
    while (folds.size > 4) folds.delete(folds.keys().next().value!);
  }
  for (let i = fold.applied; i < events.length; i++) {
    fold.story.apply(events[i]!);
    fold.metrics.apply(events[i]!);
  }
  fold.applied = events.length;
  fold.first = first;
  return fold;
}

/**
 * The story and figures of a run, folded from its events.
 *
 * @param id - The run id, or null.
 * @param kind - `item` or `triage`.
 * @param events - The events the trace stream delivered.
 * @returns The view.
 */
export function useRunView(
  id: string | null,
  kind: "item" | "triage",
  events: readonly TraceEvent[],
): RunView {
  return useMemo(() => {
    const fold = foldFor(id ?? "-", kind, events);
    const story = fold.story;
    return {
      entries: story.view(),
      critical: story.critical(),
      decisions: story.decisions(),
      images: story.images(),
      files: story.files(),
      commits: story.commits(),
      now: story.now(),
      latestMessage: story.latestMessage(),
      metrics: fold.metrics.snapshot(),
      phase: story.state.phase,
      timeline: story.state.timeline.map((t) => ({ ...t })),
    };
  }, [id, kind, events]);
}

/**
 * The insight of a run (documents, decisions, gallery, estimate basis).
 *
 * @param id - The run id, or null.
 * @param live - Asked again every 10 s while true.
 * @returns The query.
 */
export function useInsight(id: string | null, live: boolean) {
  return useQuery({
    queryKey: ["run", id, "insight"],
    queryFn: ({ signal }) => apiGet<RunInsight>(`/api/runs/${id}/insight`, signal),
    enabled: id !== null && !id.startsWith("runs-md-"),
    refetchInterval: live ? 10_000 : false,
    staleTime: 5000,
  });
}

/**
 * One document of a run's feature folder.
 *
 * @param id - The run id.
 * @param name - The document, or null.
 * @param live - Asked again every 10 s while true.
 * @returns The query.
 */
export function useRunDocument(id: string | null, name: string | null, live: boolean) {
  return useQuery({
    queryKey: ["run", id, "document", name],
    queryFn: ({ signal }) =>
      apiGet<{ name: string; text: string; modified: string }>(`/api/runs/${id}/documents/${name}`, signal),
    enabled: id !== null && name !== null,
    refetchInterval: live ? 10_000 : false,
  });
}

/**
 * A gallery image as an object URL, fetched with the session token (the API has no cookie an
 * `<img src>` could send; the page's CSP allows `blob:` images). The URL is revoked when the
 * image is no longer shown.
 *
 * @param id - The run id.
 * @param n - The image's number, or null.
 * @param version - Changes when the file changed (its modification time).
 * @returns The URL, `"gone"` when the server has no such image, or null while loading.
 */
export function useImageUrl(id: string, n: number | null, version: string | null): string | null {
  const [url, setUrl] = useState<{ key: string; value: string } | null>(null);
  const key = `${id}/${n}/${version ?? ""}`;
  useEffect(() => {
    if (n === null) return;
    const controller = new AbortController();
    let made: string | null = null;
    const token = currentToken();
    void fetch(`/api/runs/${id}/images/${n}`, {
      signal: controller.signal,
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    })
      .then(async (answer) => {
        if (!answer.ok) {
          setUrl({ key, value: "gone" });
          return;
        }
        made = URL.createObjectURL(await answer.blob());
        setUrl({ key, value: made });
      })
      .catch(() => {
        if (!controller.signal.aborted) setUrl({ key, value: "gone" });
      });
    return () => {
      controller.abort();
      if (made) URL.revokeObjectURL(made);
    };
  }, [id, n, key]);
  return url && url.key === key ? url.value : null;
}
