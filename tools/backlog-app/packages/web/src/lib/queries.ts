// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Query hooks of the server data the views show (TanStack Query). Keys are arrays starting
 * with the kind of data, so the event stream can invalidate a whole kind at once (`["board"]`).
 * Data stays fresh through invalidation by events, not through polling.
 */

import { useQuery } from "@tanstack/react-query";
import type {
  BoardView,
  CheckResult,
  ClosedItem,
  HistoryCommit,
  Item,
  Legend,
  LoopView,
  Run,
  SavedView,
  Settings,
} from "@backlog-app/shared";
import { apiGet } from "./api.ts";

/**
 * The (filtered) board.
 *
 * @param q - The filter query.
 * @returns The query result.
 */
export function useBoard(q: string) {
  return useQuery({
    queryKey: ["board", q],
    queryFn: ({ signal }) => apiGet<BoardView>(`/api/board?q=${encodeURIComponent(q)}`, signal),
    placeholderData: (previous) => previous,
  });
}

/**
 * The legend (the vocabulary of every field).
 *
 * @returns The query result.
 */
export function useLegend() {
  return useQuery({
    queryKey: ["board", "legend"],
    queryFn: ({ signal }) => apiGet<Legend>("/api/legend", signal),
    staleTime: 60_000,
  });
}

/**
 * One item.
 *
 * @param slug - The item, or null for none.
 * @returns The query result.
 */
export function useItem(slug: string | null) {
  return useQuery({
    queryKey: ["item", slug],
    queryFn: ({ signal }) => apiGet<Item>(`/api/items/${slug}`, signal),
    enabled: slug !== null,
  });
}

/**
 * An item's history.
 *
 * @param slug - The item.
 * @returns The query result.
 */
export function useItemHistory(slug: string) {
  return useQuery({
    queryKey: ["item", slug, "history"],
    queryFn: ({ signal }) => apiGet<{ commits: HistoryCommit[] }>(`/api/items/${slug}/history`, signal),
  });
}

/**
 * The consistency check.
 *
 * @returns The query result.
 */
export function useCheck() {
  return useQuery({
    queryKey: ["check"],
    queryFn: ({ signal }) => apiGet<CheckResult>("/api/check", signal),
  });
}

/**
 * The closed-items archive.
 *
 * @param q - Text filter.
 * @returns The query result.
 */
export function useClosed(q: string) {
  return useQuery({
    queryKey: ["closed", q],
    queryFn: ({ signal }) =>
      apiGet<{ items: ClosedItem[] }>(`/api/closed?q=${encodeURIComponent(q)}`, signal),
  });
}

/**
 * One closed item with its last description.
 *
 * @param slug - The item.
 * @returns The query result.
 */
export function useClosedItem(slug: string) {
  return useQuery({
    queryKey: ["closed", "item", slug],
    queryFn: ({ signal }) => apiGet<ClosedItem>(`/api/closed/${slug}`, signal),
  });
}

/**
 * The loop view.
 *
 * @returns The query result.
 */
export function useLoop() {
  return useQuery({
    queryKey: ["loop"],
    queryFn: ({ signal }) => apiGet<{ view: LoopView | null }>("/api/loop", signal),
  });
}

/**
 * The live run, if any.
 *
 * @returns The query result.
 */
export function useLiveRun() {
  return useQuery({
    queryKey: ["run", "live"],
    queryFn: ({ signal }) => apiGet<{ run: Run | null }>("/api/runs/live", signal),
  });
}

/**
 * The saved views.
 *
 * @returns The query result.
 */
export function useViews() {
  return useQuery({
    queryKey: ["views"],
    queryFn: ({ signal }) => apiGet<{ views: SavedView[] }>("/api/views", signal),
  });
}

/**
 * The maintainer's settings.
 *
 * @returns The query result.
 */
export function useSettings() {
  return useQuery({
    queryKey: ["settings"],
    queryFn: ({ signal }) => apiGet<Settings>("/api/settings", signal),
  });
}
