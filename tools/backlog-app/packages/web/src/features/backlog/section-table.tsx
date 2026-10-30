// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The table of one backlog section (analysis A4 §3.2): real table semantics, sortable
 * headers announced to screen readers, the columns the section has in `BACKLOG.md`, the search
 * snippet under a title, the next-up marker, and the selected row. Rows of the ordered sections
 * can be reordered (drag and drop and keys) by the sortable wrapper of user story 3.
 */

import {
  flexRender,
  getCoreRowModel,
  getSortedRowModel,
  useReactTable,
  type ColumnDef,
  type SortingState,
} from "@tanstack/react-table";
import { ArrowDownIcon, ArrowUpIcon, GripVerticalIcon } from "lucide-react";
import { useMemo, useState, type ReactNode } from "react";
import type { ItemRowView, SectionName } from "@backlog-app/shared";
import { SeverityBadge, StatusBadge, TypeBadge } from "@/components/badges.tsx";
import { highlight } from "@/components/markdown.tsx";
import { cn } from "@/lib/utils.ts";

/** Columns each section shows (as in `BACKLOG.md`, analysis A1 §2.3). */
const SECTION_COLUMNS: Record<SectionName, string[]> = {
  "In progress": ["position", "title", "type", "severity", "area", "feature"],
  Next: ["position", "title", "type", "severity", "area", "who", "effort", "status"],
  "Decisions for the maintainer": ["position", "title", "severity", "area", "status"],
  "Person steps": ["position", "title", "area", "status"],
  Inbox: ["title", "type", "severity", "area", "source", "created"],
  Parked: ["title", "area", "reason"],
  Rejected: ["title", "area", "reason"],
};

/** Properties of {@link SectionTable}. */
export interface SectionTableProps {
  /** The section. */
  name: SectionName;
  /** Its matching rows in order. */
  rows: ItemRowView[];
  /** Search snippets per slug. */
  snippets: Record<string, string>;
  /** Free words of the search (highlighted). */
  words: string[];
  /** The selected slug. */
  selected: string;
  /** The slug the next run would take. */
  nextUp: string | null;
  /** Skip reasons of rows above the next-up item. */
  skipped: Map<string, string>;
  /** Called when a row is chosen. */
  onSelect: (slug: string) => void;
  /** Called when a row is opened (Enter, double click). */
  onOpen: (slug: string) => void;
  /** Renders the drag handle cell of a row (user story 3), or nothing. */
  handle?: (row: ItemRowView) => ReactNode;
  /** Rows marked for a bulk change. */
  marked?: ReadonlySet<string>;
  /** Toggles a row's bulk mark; when absent there is no mark column. */
  onToggleMark?: (slug: string) => void;
  /** Wraps a table row element (sortable rows of user story 3). */
  wrapRow?: (row: ItemRowView, element: ReactNode) => ReactNode;
}

/**
 * The column definitions.
 *
 * @param snippets - Search snippets per slug.
 * @param words - Search words.
 * @param nextUp - The next-up slug.
 * @param skipped - Skip reasons.
 * @returns The columns.
 */
function columnsOf(
  snippets: Record<string, string>,
  words: string[],
  nextUp: string | null,
  skipped: Map<string, string>,
): ColumnDef<ItemRowView>[] {
  return [
    {
      id: "position",
      header: "#",
      accessorFn: (row) => row.position ?? 0,
      cell: ({ row }) => (
        <span className="text-muted-foreground tabular-nums">{row.original.position ?? ""}</span>
      ),
    },
    {
      id: "title",
      header: "Item",
      accessorFn: (row) => row.title,
      cell: ({ row }) => {
        const item = row.original;
        const snippet = snippets[item.slug];
        return (
          <div className="min-w-0">
            <div className="flex items-center gap-1.5">
              {item.slug === nextUp ? (
                <span
                  className="shrink-0 rounded bg-ok/15 px-1 text-[11px] font-medium text-ok"
                  title="The next run takes this item"
                >
                  next up
                </span>
              ) : null}
              <span className="line-clamp-2" title={item.title}>
                {highlight(item.title, words)}
              </span>
            </div>
            {skipped.has(item.slug) ? (
              <div className="text-xs text-muted-foreground">
                skipped by the loop: {skipped.get(item.slug)}
              </div>
            ) : null}
            {item.reason && item.status === "blocked" ? (
              <div className="truncate text-xs text-status-blocked" title={item.reason}>
                blocked: {item.reason}
              </div>
            ) : null}
            {snippet ? (
              <div className="line-clamp-2 text-xs text-muted-foreground">{highlight(snippet, words)}</div>
            ) : null}
          </div>
        );
      },
    },
    {
      id: "type",
      header: "Type",
      accessorFn: (row) => row.type,
      cell: ({ row }) => <TypeBadge type={row.original.type} />,
    },
    {
      id: "severity",
      header: "Sev",
      accessorFn: (row) => row.severity,
      cell: ({ row }) => <SeverityBadge severity={row.original.severity} />,
    },
    { id: "area", header: "Area", accessorFn: (row) => row.area },
    { id: "who", header: "Who", accessorFn: (row) => row.who },
    { id: "effort", header: "Effort", accessorFn: (row) => row.effort },
    {
      id: "status",
      header: "Status",
      accessorFn: (row) => row.status,
      cell: ({ row }) => <StatusBadge status={row.original.status} />,
    },
    { id: "source", header: "Source", accessorFn: (row) => row.source },
    { id: "created", header: "Created", accessorFn: (row) => row.created },
    { id: "feature", header: "Feature", accessorFn: (row) => row.feature ?? "" },
    {
      id: "reason",
      header: "Reason",
      accessorFn: (row) => row.reason ?? "",
      cell: ({ row }) => (
        <span className="line-clamp-2 text-xs" title={row.original.reason ?? ""}>
          {row.original.reason}
        </span>
      ),
    },
  ];
}

/**
 * The table of one section.
 *
 * @param props - See {@link SectionTableProps}.
 * @returns The element.
 */
export function SectionTable(props: SectionTableProps) {
  const {
    name,
    rows,
    snippets,
    words,
    selected,
    nextUp,
    skipped,
    onSelect,
    onOpen,
    handle,
    wrapRow,
    marked,
    onToggleMark,
  } = props;
  const [sorting, setSorting] = useState<SortingState>([]);
  const visible = SECTION_COLUMNS[name];
  const columns = useMemo(
    () => columnsOf(snippets, words, nextUp, skipped).filter((c) => visible.includes(c.id!)),
    [snippets, words, nextUp, skipped, visible],
  );
  // TanStack Table is not compatible with the React Compiler; the app is built without the
  // compiler, so the hook works as documented.
  // eslint-disable-next-line react-hooks/incompatible-library
  const table = useReactTable({
    data: rows,
    columns,
    state: { sorting },
    onSortingChange: setSorting,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getRowId: (row) => row.slug,
  });
  // Reordering makes sense only in the backlog's own order.
  const showHandles = Boolean(handle) && sorting.length === 0;

  return (
    <table className="w-full table-fixed border-collapse text-sm">
      <caption className="sr-only">{name}</caption>
      <colgroup>
        {onToggleMark ? <col className="w-8" /> : null}
        {showHandles ? <col className="w-7" /> : null}
        {table.getVisibleLeafColumns().map((column) => (
          <col
            key={column.id}
            className={cn(
              column.id === "title"
                ? "w-auto"
                : column.id === "reason"
                  ? "w-[38%]"
                  : column.id === "position"
                    ? "w-10"
                    : "w-24",
              column.id === "severity" && "w-14",
            )}
          />
        ))}
      </colgroup>
      <thead className="sticky top-0 z-10 bg-background">
        {table.getHeaderGroups().map((group) => (
          <tr key={group.id} className="border-b text-left text-xs text-muted-foreground">
            {onToggleMark ? <th className="w-8" aria-label="Marked for a bulk change" /> : null}
            {showHandles ? <th className="w-7" aria-label="Drag to reorder" /> : null}
            {group.headers.map((header) => {
              const sorted = header.column.getIsSorted();
              return (
                <th
                  key={header.id}
                  className="px-2 py-1.5 font-medium"
                  aria-sort={sorted === "asc" ? "ascending" : sorted === "desc" ? "descending" : "none"}
                >
                  <button
                    type="button"
                    className="inline-flex items-center gap-1 hover:text-foreground"
                    onClick={header.column.getToggleSortingHandler()}
                  >
                    {flexRender(header.column.columnDef.header, header.getContext())}
                    {sorted === "asc" ? (
                      <ArrowUpIcon className="size-3" />
                    ) : sorted === "desc" ? (
                      <ArrowDownIcon className="size-3" />
                    ) : null}
                  </button>
                </th>
              );
            })}
          </tr>
        ))}
      </thead>
      <tbody>
        {table.getRowModel().rows.map((row) => {
          const isSelected = row.original.slug === selected;
          const element = (
            <tr
              key={row.id}
              data-slug={row.original.slug}
              aria-selected={isSelected}
              tabIndex={isSelected ? 0 : -1}
              onClick={() => onSelect(row.original.slug)}
              onDoubleClick={() => onOpen(row.original.slug)}
              className={cn(
                "cursor-default border-b border-border/60 align-top hover:bg-accent/50",
                isSelected && "bg-accent ring-1 ring-ring/50 outline-none ring-inset",
              )}
            >
              {onToggleMark ? (
                <td className="px-2 py-1.5" onClick={(e) => e.stopPropagation()}>
                  <input
                    type="checkbox"
                    aria-label={`Mark ${row.original.title} for a bulk change`}
                    checked={marked?.has(row.original.slug) ?? false}
                    onChange={() => onToggleMark(row.original.slug)}
                  />
                </td>
              ) : null}
              {showHandles ? (
                <td className="px-1 py-1.5 text-muted-foreground">
                  {handle ? handle(row.original) : <GripVerticalIcon className="size-4" />}
                </td>
              ) : null}
              {row.getVisibleCells().map((cell) => (
                <td key={cell.id} className="px-2 py-1.5">
                  {flexRender(
                    cell.column.columnDef.cell ??
                      ((info) => {
                        const value = info.getValue();
                        return typeof value === "string" || typeof value === "number" ? String(value) : "";
                      }),
                    cell.getContext(),
                  )}
                </td>
              ))}
            </tr>
          );
          return wrapRow ? wrapRow(row.original, element) : element;
        })}
      </tbody>
    </table>
  );
}
