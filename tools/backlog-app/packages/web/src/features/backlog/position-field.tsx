// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file A typed position and "Move to the top" for an item of an ordered section (feature 371,
 * FR-011 - FR-013; research R7): both send the section's whole order as one `reorder`, computed
 * from the board's own order (not from a filtered or sorted view), like a drag does - no log line
 * per step. Enter confirms, Escape cancels; a number larger than the section means last; 0, a
 * negative number or text is refused with a hint. Disabled with the gate's reason, for the item a
 * run works on, for *In progress* and for the unordered sections.
 */

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { ArrowUpToLineIcon } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import type { ChangeResult, ItemRowView, SectionName } from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import { Tooltip } from "@/components/ui/overlays.tsx";
import { apiPost, ApiFailure, errorText } from "@/lib/api.ts";
import { useBoard } from "@/lib/queries.ts";
import { cn } from "@/lib/utils.ts";
import { itemReason, useWriteAccess } from "@/features/gate/gate-banner.tsx";

/** The tool's short names of the sections whose order the maintainer sets by hand. */
export const ORDERED_SECTION_ARG: Partial<Record<SectionName, string>> = {
  Next: "next",
  "Decisions for the maintainer": "decisions",
  "Person steps": "person",
};

/**
 * Why an item's position cannot be changed now, or empty.
 *
 * @param access - The write access.
 * @param slug - The item.
 * @param section - Its section.
 * @returns The reason, empty when allowed.
 */
export function positionReason(
  access: ReturnType<typeof useWriteAccess>,
  slug: string,
  section: SectionName | null,
): string {
  if (!section || !ORDERED_SECTION_ARG[section]) {
    return section === "In progress"
      ? "runs own the order of In progress"
      : "this section is sorted by the tool";
  }
  return itemReason(access, slug);
}

/**
 * The new order of a section with one item placed at a position (1 = top; beyond the end =
 * last).
 *
 * @param order - The current slugs in order.
 * @param slug - The item to place.
 * @param position - The wanted 1-based position.
 * @returns The new order, or null when the item is not in the section.
 */
export function placeAt(order: readonly string[], slug: string, position: number): string[] | null {
  const from = order.indexOf(slug);
  if (from < 0) return null;
  const rest = order.filter((s) => s !== slug);
  const at = Math.max(0, Math.min(rest.length, position - 1));
  return [...rest.slice(0, at), slug, ...rest.slice(at)];
}

/**
 * Sends a new order of a section (the whole section, as a drag does).
 *
 * @param section - The section.
 * @returns The mutation; call it with the item and the wanted position.
 */
export function usePlaceAt(section: SectionName | null) {
  const board = useBoard("");
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ slug, position }: { slug: string; position: number }) => {
      const arg = section ? ORDERED_SECTION_ARG[section] : undefined;
      if (!arg || !board.data) throw new ApiFailure(0, "refused", "this section cannot be reordered");
      const rows = board.data.sections.find((s) => s.name === section)?.rows ?? [];
      const order = rows.filter((r): r is ItemRowView => r.kind === "item").map((r) => r.slug);
      const next = placeAt(order, slug, position);
      if (!next) throw new ApiFailure(0, "refused", "the item is not in this section any more");
      if (next.join("\n") === order.join("\n")) return null;
      return apiPost<ChangeResult>(`/api/sections/${arg}/order`, {
        base: { board: board.data.revision },
        order: next,
      });
    },
    onSuccess: (result, { position }) => {
      void queryClient.invalidateQueries({ queryKey: ["board"] });
      void queryClient.invalidateQueries({ queryKey: ["item"] });
      void queryClient.invalidateQueries({ queryKey: ["tray"] });
      if (result === null) toast.info("Already at that position");
      else
        toast.success(
          `Moved to #${position}${result.commit ? ` (committed ${result.commit.slice(0, 8)})` : ""}`,
        );
    },
    onError: (error) => {
      toast.error(errorText(error));
      void queryClient.invalidateQueries({ queryKey: ["board"] });
    },
  });
}

/**
 * Reads a typed position.
 *
 * @param text - What was typed.
 * @returns The position, or a hint why it is not one.
 */
export function parsePosition(text: string): { position: number } | { hint: string } {
  const trimmed = text.trim();
  if (!/^\d+$/.test(trimmed)) return { hint: "type a whole number: 1 is the top" };
  const position = Number(trimmed);
  if (position < 1) return { hint: "positions count from 1 (the top)" };
  return { position };
}

/**
 * The position field with "Move to the top".
 *
 * @param props - The item, its section and position, the size.
 * @returns The element.
 */
export function PositionField({
  slug,
  section,
  position,
  compact = false,
  autoFocus = false,
  onDone,
}: {
  /** The item. */
  slug: string;
  /** Its section. */
  section: SectionName | null;
  /** Its position now. */
  position: number | null;
  /** Table-cell size. */
  compact?: boolean;
  /** Focus the field at once (the table cell opens it on demand). */
  autoFocus?: boolean;
  /** Called when the field closes (confirmed, cancelled or blurred). */
  onDone?: () => void;
}) {
  const access = useWriteAccess();
  const reason = positionReason(access, slug, section);
  const place = usePlaceAt(section);
  const [text, setText] = useState(position ? String(position) : "");
  const [hint, setHint] = useState("");
  const input = useRef<HTMLInputElement>(null);
  useEffect(() => {
    if (autoFocus) input.current?.select();
  }, [autoFocus]);
  // A new position from the board replaces what was typed (adjusted during render).
  const [positionOf, setPositionOf] = useState(position);
  if (position !== positionOf) {
    setPositionOf(position);
    setText(position ? String(position) : "");
  }

  /** Confirms the typed position. */
  const confirm = (): void => {
    const parsed = parsePosition(text);
    if ("hint" in parsed) {
      setHint(parsed.hint);
      return;
    }
    setHint("");
    place.mutate({ slug, position: parsed.position }, { onSettled: () => onDone?.() });
  };

  const disabled = reason !== "" || place.isPending;
  const field = (
    <span className={cn("inline-flex items-center gap-1", compact ? "text-xs" : "text-sm")}>
      <label className="sr-only" htmlFor={`position-${slug}`}>
        Position of {slug}
      </label>
      <input
        ref={input}
        id={`position-${slug}`}
        type="text"
        inputMode="numeric"
        aria-label={`Position of ${slug}`}
        aria-invalid={hint !== ""}
        aria-describedby={hint ? `position-hint-${slug}` : undefined}
        className={cn(
          "rounded-md border bg-background px-1.5 py-0.5 text-right tabular-nums",
          compact ? "w-12 text-xs" : "w-16",
          hint && "border-bad",
        )}
        value={text}
        disabled={disabled}
        onChange={(e) => {
          setText(e.target.value);
          setHint("");
        }}
        onKeyDown={(e) => {
          if (e.key === "Enter") {
            e.preventDefault();
            confirm();
          } else if (e.key === "Escape") {
            e.preventDefault();
            setText(position ? String(position) : "");
            setHint("");
            onDone?.();
          }
        }}
        onBlur={() => {
          if (text.trim() === (position ? String(position) : "")) onDone?.();
        }}
        onClick={(e) => e.stopPropagation()}
      />
      <Button
        size={compact ? "icon-sm" : "sm"}
        variant="outline"
        aria-label={`Move ${slug} to the top`}
        disabled={disabled || position === 1}
        onClick={(e) => {
          e.stopPropagation();
          place.mutate({ slug, position: 1 }, { onSettled: () => onDone?.() });
        }}
      >
        <ArrowUpToLineIcon /> {compact ? null : "Move to the top"}
      </Button>
      {hint ? (
        <span id={`position-hint-${slug}`} className="text-xs text-bad">
          {hint}
        </span>
      ) : null}
    </span>
  );
  return reason ? (
    <Tooltip content={reason}>
      <span tabIndex={0}>{field}</span>
    </Tooltip>
  ) : (
    field
  );
}
