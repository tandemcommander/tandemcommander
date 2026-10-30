// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Shapes of the answers of the read routes that combine several entities
 * (contracts/http-api.md). Single entities use the schemas of `schemas/`.
 */

import type { Board, CheckResult, ItemRow, Legend, NextUp, SectionName } from "../schemas/backlog.ts";
import type { LoopView } from "../schemas/loop.ts";
import type { Run } from "../schemas/runs.ts";
import type { WriteGate } from "../schemas/app-state.ts";
import type { FilterError } from "../query/filter-language.ts";

/** An item row as sent to the client (without the body and issue texts). */
export type ItemRowView = Omit<ItemRow, "body" | "issue"> & {
  /** The section the row is in. */
  section: SectionName;
};

/** One section of a filtered board. */
export interface SectionView {
  /** The section. */
  name: SectionName;
  /** Ordered (priority) section. */
  ordered: boolean;
  /** The matching rows in order (notes are kept only when no filter is set). */
  rows: (ItemRowView | { kind: "note"; note: string })[];
  /** Number of items in the section before filtering. */
  total: number;
}

/** The answer of `GET /api/board`. */
export interface BoardView {
  /** The board revision (SHA-256 of `BACKLOG.md` as read). */
  revision: string;
  /** Where it was read from. */
  ref: Board["ref"];
  /** Day of the last triage. */
  lastTriaged: string | null;
  /** The sections. */
  sections: SectionView[];
  /** Items that cannot be read. */
  unreadable: Board["unreadable"];
  /** Parts of the query that were not understood. */
  errors: FilterError[];
  /** A text excerpt around the first hit of the free words, per slug. */
  snippets: Record<string, string>;
  /** Number of matching items. */
  matches: number;
  /** What the next autonomous run would take. */
  next: NextUp;
}

/** The answer of `GET /api/state` and the `hello` event. */
export interface StateView {
  /** The write gate. */
  gate: WriteGate;
  /** The loop. */
  loop: LoopView | null;
  /** Summary of the live run, if any. */
  run: Pick<Run, "id" | "slug" | "phase" | "tasks" | "outcome"> | null;
  /** The change tray's pending count. */
  tray: { pending: number; outside: number };
  /** Repository facts. */
  repo: {
    /** Repository root. */
    root: string;
    /** Folder name of the repository. */
    name: string;
    /** The working tree's branch. */
    branch: string;
    /** Commits of `main` not on `origin/main` and the reverse, as last fetched. */
    ahead: number | null;
    /** Commits of `origin/main` not on `main`. */
    behind: number | null;
  };
  /** Where the backlog is read from. */
  source: Board["ref"];
  /** The check result's count. */
  check: Pick<CheckResult, "total">;
  /** Notification events not seen yet. */
  unseenEvents: number;
  /** Development mode of the server. */
  dev: boolean;
}

/** The answer of `GET /api/legend`. */
export type LegendView = Legend;
