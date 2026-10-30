// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Reordering an ordered section (FR-026; analysis A4 §4.2): drag and drop with the mouse,
 * the keyboard sensor (Space to lift, arrows to move, Space to drop) with screen-reader
 * announcements, and Alt+↑/↓ (Alt+Shift: top/bottom) on the selected row.
 *
 * A reorder is the one optimistic change: the row moves at once, and the new order of the whole
 * section is sent as one `reorder` (no log line per step - analysis A1 found that `move` per drag
 * would flood item logs). Several quick key presses are coalesced into one request. A refusal
 * puts the rows back. While a filter is active, rows are not reordered (the full order is not
 * visible).
 */

import {
  closestCenter,
  DndContext,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
} from "@dnd-kit/core";
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { GripVerticalIcon } from "lucide-react";
import { cloneElement, useMemo, useRef, useState, type ReactElement, type ReactNode } from "react";
import { toast } from "sonner";
import type { ChangeResult, ItemRowView, SectionName } from "@backlog-app/shared";
import { apiPost, ApiFailure } from "@/lib/api.ts";
import { useShortcuts, type Shortcut } from "@/lib/hotkeys.ts";
import { useWriteAccess } from "@/features/gate/gate-banner.tsx";
import { SectionTable, type SectionTableProps } from "./section-table.tsx";

/** The tool's short names of the ordered sections. */
const SECTION_ARG: Partial<Record<SectionName, string>> = {
  "In progress": "progress",
  Next: "next",
  "Decisions for the maintainer": "decisions",
  "Person steps": "person",
};

/** Milliseconds key presses are coalesced before the order is sent. */
const COALESCE_MS = 450;

/**
 * One sortable table row: the row element with the drag behaviour attached.
 *
 * @param props - The slug, the row element and whether dragging is allowed.
 * @returns The element.
 */
function SortableRow({
  id,
  element,
  enabled,
}: {
  /** Slug. */ id: string;
  /** The `<tr>`. */ element: ReactNode;
  /** Dragging allowed. */ enabled: boolean;
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id,
    disabled: !enabled,
  });
  const row = element as ReactElement<Record<string, unknown>>;
  // While dragging is not allowed the row stays a plain table row: the drag attributes would mark
  // it `aria-disabled` (a screen reader would announce every row as disabled) and change its
  // tab order; the hook is still called so the hook order never changes.
  if (!enabled) return row;
  return cloneElement(row, {
    ref: setNodeRef,
    style: {
      transform: CSS.Translate.toString(transform),
      transition,
      opacity: isDragging ? 0.6 : 1,
      position: "relative",
      zIndex: isDragging ? 5 : undefined,
    },
    ...attributes,
    ...listeners,
    // The table row keeps its own role, tab order and selection semantics.
    role: undefined,
    tabIndex: row.props["tabIndex"],
    "aria-disabled": undefined,
    "aria-roledescription": "sortable row",
  });
}

/**
 * An ordered section with reordering.
 *
 * @param props - The section, its rows, the board revision, whether a filter is active, and the
 *   table's properties.
 * @returns The element.
 */
export function SortableSection({
  section,
  rows,
  revision,
  filtered,
  table,
}: {
  /** The section. */
  section: SectionName;
  /** Its rows in the board's order. */
  rows: ItemRowView[];
  /** The board revision the order is based on. */
  revision: string;
  /** A filter is active (no reordering then). */
  filtered: boolean;
  /** The table's properties. */
  table: SectionTableProps;
}) {
  const access = useWriteAccess();
  const queryClient = useQueryClient();
  const [order, setOrder] = useState(() => rows.map((r) => r.slug));
  const [orderOf, setOrderOf] = useState(rows);
  const pendingTimer = useRef<number | undefined>(undefined);
  // A new board (after a change by anyone) replaces the local order (adjusted during render).
  if (rows !== orderOf) {
    setOrderOf(rows);
    setOrder(rows.map((r) => r.slug));
  }
  const bySlug = useMemo(() => new Map(rows.map((r) => [r.slug, r])), [rows]);
  const ordered = order.map((slug) => bySlug.get(slug)).filter((r): r is ItemRowView => r !== undefined);
  const enabled = access.writable && !filtered && Boolean(SECTION_ARG[section]) && section !== "In progress";

  const save = useMutation({
    mutationFn: (next: string[]) =>
      apiPost<ChangeResult>(`/api/sections/${SECTION_ARG[section]}/order`, {
        base: { board: revision },
        order: next,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["board"] });
      void queryClient.invalidateQueries({ queryKey: ["tray"] });
    },
    onError: (error) => {
      // Put the rows back where the server has them.
      setOrder(rows.map((r) => r.slug));
      toast.error(error instanceof ApiFailure ? error.message : String(error));
      void queryClient.invalidateQueries({ queryKey: ["board"] });
    },
  });

  /**
   * Applies a new order locally at once and sends it after a short pause.
   *
   * @param next - The new order.
   */
  const reorder = (next: string[]): void => {
    setOrder(next);
    window.clearTimeout(pendingTimer.current);
    pendingTimer.current = window.setTimeout(() => save.mutate(next), COALESCE_MS);
  };

  const sensors = useSensors(
    // A small distance keeps a click a click (selection), not a drag.
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  );

  /**
   * Finishes a drag.
   *
   * @param event - The drag end.
   */
  const onDragEnd = (event: DragEndEvent): void => {
    const { active, over } = event;
    if (!over || active.id === over.id) return;
    const from = order.indexOf(String(active.id));
    const to = order.indexOf(String(over.id));
    if (from < 0 || to < 0) return;
    reorder(arrayMove(order, from, to));
  };

  const selected = table.selected;
  const shortcuts = useMemo<Shortcut[]>(() => {
    if (!enabled || !order.includes(selected)) return [];
    /**
     * Moves the selected row.
     *
     * @param target - Function of the current index giving the new index.
     */
    const move = (target: (index: number) => number): void => {
      const from = order.indexOf(selected);
      const to = Math.max(0, Math.min(order.length - 1, target(from)));
      if (from !== to) reorder(arrayMove(order, from, to));
    };
    return [
      { keys: "alt+ArrowUp", label: "Move up", run: () => move((i) => i - 1) },
      { keys: "alt+ArrowDown", label: "Move down", run: () => move((i) => i + 1) },
      { keys: "alt+shift+ArrowUp", label: "Move to the top", run: () => move(() => 0) },
      { keys: "alt+shift+ArrowDown", label: "Move to the bottom", run: () => move(() => order.length - 1) },
    ];
    // reorder is stable enough: it only reads state through setters and the latest closure.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [enabled, order, selected]);
  useShortcuts(shortcuts);

  return (
    <div className="flex flex-col">
      {filtered ? (
        <p className="pb-1 text-xs text-muted-foreground">Clear the filter to reorder this section.</p>
      ) : null}
      <DndContext
        sensors={sensors}
        collisionDetection={closestCenter}
        onDragEnd={onDragEnd}
        accessibility={{
          screenReaderInstructions: {
            draggable:
              "Press Space to lift the row, the arrow keys to move it, Space to drop it, Escape to cancel.",
          },
        }}
      >
        <SortableContext items={order} strategy={verticalListSortingStrategy}>
          <SectionTable
            {...table}
            rows={ordered}
            handle={
              enabled ? () => <GripVerticalIcon className="size-4 cursor-grab" aria-hidden /> : undefined
            }
            wrapRow={(row, element) => (
              <SortableRow key={row.slug} id={row.slug} element={element} enabled={enabled} />
            )}
          />
        </SortableContext>
      </DndContext>
      {save.isPending ? (
        <p className="text-xs text-muted-foreground" aria-live="polite">
          Saving the order…
        </p>
      ) : null}
    </div>
  );
}
