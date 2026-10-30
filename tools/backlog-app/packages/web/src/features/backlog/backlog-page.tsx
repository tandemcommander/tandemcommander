// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The backlog page (user story 1; analysis A4 §3.2): one section or all of them in the
 * backlog's real order, the filter box, the next-up marker, and the selected item in a detail pane
 * on wide windows. The section, the filter and the selection are in the address (FR-009).
 */

import { getRouteApi, useNavigate } from "@tanstack/react-router";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { BookmarkPlusIcon, XIcon } from "lucide-react";
import { useCallback, useMemo, useState } from "react";
import { toast } from "sonner";
import {
  highlightTexts,
  parseFilter,
  type ItemRowView,
  type SectionName,
  type SectionView,
} from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import { Alert, Input, Skeleton } from "@/components/ui/primitives.tsx";
import { Dialog, DialogContent, DialogFooter } from "@/components/ui/overlays.tsx";
import { apiPost, ApiFailure } from "@/lib/api.ts";
import { useBoard, useLegend } from "@/lib/queries.ts";
import { useShortcuts, type Shortcut } from "@/lib/hotkeys.ts";
import { ItemView } from "@/features/item/item-view.tsx";
import { FilterBox } from "./filter-box.tsx";
import { SectionTable } from "./section-table.tsx";
import { SortableSection } from "./sortable-section.tsx";
import { BulkBar } from "./bulk-actions.tsx";
import { useWriteAccess } from "@/features/gate/gate-banner.tsx";

/** The route's parameters. */
const route = getRouteApi("/backlog/$section");

/** Section names by the short names of the address. */
export const SECTION_BY_PARAM: Record<string, SectionName | "all"> = {
  all: "all",
  progress: "In progress",
  next: "Next",
  decisions: "Decisions for the maintainer",
  person: "Person steps",
  inbox: "Inbox",
  parked: "Parked",
  rejected: "Rejected",
};

/** Empty-state texts per section (analysis A4 §4.8). */
const EMPTY_TEXT: Partial<Record<SectionName, string>> = {
  Inbox: "The Inbox is empty. Nothing to triage.",
  "In progress": "No item is in progress on this branch (a run starts its item on its feature branch).",
  "Decisions for the maintainer": "No decision waits for you.",
  "Person steps": "No person step is open.",
};

/**
 * The dialog that saves the current address as a named view.
 *
 * @param props - Open state, setter and the address.
 * @returns The element.
 */
function SaveViewDialog({
  open,
  onOpenChange,
  url,
}: {
  /** Open. */ open: boolean;
  /** Setter. */ onOpenChange: (o: boolean) => void;
  /** Address. */ url: string;
}) {
  const [name, setName] = useState("");
  const queryClient = useQueryClient();
  const save = useMutation({
    mutationFn: () => apiPost("/api/views", { name: name.trim(), url, pinned: true, builtIn: false }),
    onSuccess: () => {
      toast.success(`Saved the view '${name.trim()}'`);
      void queryClient.invalidateQueries({ queryKey: ["views"] });
      onOpenChange(false);
      setName("");
    },
    onError: (error) => toast.error(error instanceof ApiFailure ? error.message : String(error)),
  });
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent title="Save this view" description={<code className="text-xs">{url}</code>}>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            if (name.trim()) save.mutate();
          }}
        >
          <label className="text-xs font-medium text-muted-foreground" htmlFor="view-name">
            Name
          </label>
          <Input
            id="view-name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            maxLength={60}
            autoFocus
          />
          <DialogFooter>
            <Button type="submit" disabled={!name.trim() || save.isPending}>
              Save
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

/**
 * The backlog page.
 *
 * @returns The element.
 */
export function BacklogPage() {
  const { section: sectionParam } = route.useParams();
  const { q, sel } = route.useSearch();
  const navigate = useNavigate();
  const board = useBoard(q);
  const legend = useLegend();
  const [saving, setSaving] = useState(false);
  const [marked, setMarked] = useState<ReadonlySet<string>>(new Set());
  const access = useWriteAccess();
  /**
   * Toggles a row's bulk mark.
   *
   * @param slug - The row.
   */
  const toggleMark = useCallback((slug: string) => {
    setMarked((current) => {
      const next = new Set(current);
      if (next.has(slug)) next.delete(slug);
      else next.add(slug);
      return next;
    });
  }, []);
  const wanted = SECTION_BY_PARAM[sectionParam] ?? "all";

  const sections: SectionView[] = useMemo(
    () => (board.data?.sections ?? []).filter((s) => wanted === "all" || s.name === wanted),
    [board.data, wanted],
  );
  const words = useMemo(
    () => (legend.data ? highlightTexts(parseFilter(q, legend.data).terms) : []),
    [q, legend.data],
  );
  const visibleRows = useMemo(
    () => sections.flatMap((s) => s.rows.filter((r): r is ItemRowView => r.kind === "item")),
    [sections],
  );
  const skipped = useMemo(
    () => new Map((board.data?.next.skipped ?? []).map((s) => [s.slug, s.reason])),
    [board.data],
  );

  const setSearch = useCallback(
    (patch: { q?: string; sel?: string }) =>
      void navigate({
        to: "/backlog/$section",
        params: { section: sectionParam },
        search: { q, sel, ...patch },
        replace: true,
      }),
    [navigate, sectionParam, q, sel],
  );

  /**
   * Opens an item: the full page.
   *
   * @param slug - The item.
   */
  const open = useCallback(
    (slug: string) => void navigate({ to: "/items/$slug", params: { slug }, search: { tab: "" } }),
    [navigate],
  );

  /**
   * Moves the selection by some rows.
   *
   * @param delta - +1 next, -1 previous.
   */
  const step = useCallback(
    (delta: number) => {
      if (visibleRows.length === 0) return;
      const index = visibleRows.findIndex((r) => r.slug === sel);
      const next = visibleRows[Math.max(0, Math.min(visibleRows.length - 1, index < 0 ? 0 : index + delta))]!;
      setSearch({ sel: next.slug });
      document.querySelector(`tr[data-slug="${next.slug}"]`)?.scrollIntoView({ block: "nearest" });
    },
    [visibleRows, sel, setSearch],
  );

  const shortcuts = useMemo<Shortcut[]>(
    () => [
      { keys: "j", label: "Next row", run: () => step(1) },
      { keys: "ArrowDown", label: "Next row", run: () => step(1) },
      { keys: "k", label: "Previous row", run: () => step(-1) },
      { keys: "ArrowUp", label: "Previous row", run: () => step(-1) },
      { keys: "Enter", label: "Open the item", run: () => sel && open(sel) },
      { keys: "o", label: "Open the item", run: () => sel && open(sel) },
      { keys: "x", label: "Mark the row for a bulk change", run: () => sel && toggleMark(sel) },
      {
        keys: "Escape",
        label: "Clear the selection and the marks",
        run: () => {
          setMarked(new Set());
          setSearch({ sel: "" });
        },
      },
    ],
    [step, sel, open, setSearch, toggleMark],
  );
  useShortcuts(shortcuts);

  const title = wanted === "all" ? "Backlog" : wanted;
  return (
    <div
      className={`grid min-h-0 flex-1 grid-cols-1 ${sel ? "min-[1280px]:grid-cols-[minmax(0,1fr)_minmax(26rem,38%)]" : ""}`}
    >
      <section
        aria-labelledby="backlog-title"
        className="flex min-h-0 min-w-0 flex-col gap-3 overflow-y-auto p-4"
      >
        <div className="flex items-center gap-2">
          <h1 id="backlog-title" className="text-lg font-semibold">
            {title}
          </h1>
          {board.data?.lastTriaged ? (
            <span className="text-xs text-muted-foreground">last triaged {board.data.lastTriaged}</span>
          ) : null}
          <Button variant="ghost" size="sm" className="ml-auto" onClick={() => setSaving(true)}>
            <BookmarkPlusIcon /> Save view
          </Button>
        </div>
        <FilterBox
          query={q}
          errors={board.data?.errors ?? []}
          matches={board.data ? board.data.matches : null}
          onChange={(next) => setSearch({ q: next })}
        />
        {board.isLoading ? (
          <div className="flex flex-col gap-2">
            {Array.from({ length: 8 }, (_, i) => (
              <Skeleton key={i} className="h-8" />
            ))}
          </div>
        ) : null}
        {board.error ? (
          <Alert tone="bad">
            {board.error instanceof ApiFailure ? board.error.message : String(board.error)}
          </Alert>
        ) : null}
        {(board.data?.unreadable.length ?? 0) > 0 ? (
          <Alert tone="bad">
            {board.data!.unreadable.length} item(s) cannot be read:{" "}
            {board.data!.unreadable.map((u) => `${u.slug} (${u.finding})`).join("; ")}
          </Alert>
        ) : null}
        {sections.map((section) => {
          const items = section.rows.filter((r): r is ItemRowView => r.kind === "item");
          const notes = section.rows.filter((r): r is { kind: "note"; note: string } => r.kind === "note");
          return (
            <div key={section.name} className="flex flex-col">
              {wanted === "all" ? (
                <h2 className="sticky top-0 z-20 flex items-baseline gap-2 bg-background py-1 text-sm font-semibold">
                  {section.name}
                  <span className="text-xs font-normal text-muted-foreground">
                    {q ? `${items.length} of ${section.total}` : section.total}
                  </span>
                </h2>
              ) : null}
              {items.length === 0 ? (
                <p className="py-3 text-sm text-muted-foreground">
                  {q
                    ? "No item of this section matches the filter."
                    : (EMPTY_TEXT[section.name] ?? "No items.")}
                </p>
              ) : section.ordered ? (
                <SortableSection
                  section={section.name}
                  rows={items}
                  revision={board.data!.revision}
                  filtered={q.length > 0}
                  table={{
                    name: section.name,
                    rows: items,
                    snippets: board.data!.snippets,
                    words,
                    selected: sel,
                    nextUp: board.data!.next.slug,
                    skipped,
                    onSelect: (slug) => setSearch({ sel: slug }),
                    onOpen: open,
                    marked,
                    onToggleMark: toggleMark,
                  }}
                />
              ) : (
                <SectionTable
                  name={section.name}
                  rows={items}
                  snippets={board.data!.snippets}
                  words={words}
                  selected={sel}
                  nextUp={board.data!.next.slug}
                  skipped={skipped}
                  onSelect={(slug) => setSearch({ sel: slug })}
                  onOpen={open}
                  marked={marked}
                  onToggleMark={toggleMark}
                />
              )}
              {notes.map((note) => (
                <p
                  key={note.note}
                  className="mt-1 rounded border border-dashed px-2 py-1 text-xs text-muted-foreground"
                >
                  Hand-written row: {note.note}
                </p>
              ))}
            </div>
          );
        })}
        <BulkBar
          slugs={[...marked]}
          revision={board.data?.revision ?? null}
          legend={legend.data ?? null}
          onClear={() => setMarked(new Set())}
          disabledReason={access.writable ? "" : access.reason}
        />
      </section>
      {sel ? (
        <aside
          aria-label="Selected item"
          className="hidden min-h-0 flex-col overflow-y-auto border-l bg-card min-[1280px]:flex"
        >
          <div className="flex items-center justify-end border-b px-2 py-1">
            <Button
              variant="ghost"
              size="icon-sm"
              aria-label="Close the detail pane"
              onClick={() => setSearch({ sel: "" })}
            >
              <XIcon />
            </Button>
          </div>
          <ItemView slug={sel} compact words={words} />
        </aside>
      ) : null}
      <SaveViewDialog
        open={saving}
        onOpenChange={setSaving}
        url={`/backlog/${sectionParam}${q ? `?q=${encodeURIComponent(q)}` : ""}`}
      />
    </div>
  );
}
