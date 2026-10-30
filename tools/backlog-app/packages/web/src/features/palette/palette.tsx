// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The command palette (Ctrl+K; FR-041): go to any page, open any item by title or slug, open
 * a saved view, or run a filter query. Built on cmdk inside a Radix dialog.
 */

import { useNavigate } from "@tanstack/react-router";
import { Command } from "cmdk";
import { Dialog as DialogPrimitive } from "radix-ui";
import { useMemo, useState } from "react";
import type { ItemRowView } from "@backlog-app/shared";
import { useBoard, useViews } from "@/lib/queries.ts";

/** Pages the palette can go to. */
const PAGES: { label: string; to: string }[] = [
  { label: "Home", to: "/" },
  { label: "Live run", to: "/live" },
  { label: "Backlog: all sections", to: "/backlog/all" },
  { label: "Backlog: Next", to: "/backlog/next" },
  { label: "Backlog: Decisions", to: "/backlog/decisions" },
  { label: "Backlog: Person steps", to: "/backlog/person" },
  { label: "Backlog: Inbox", to: "/backlog/inbox" },
  { label: "Triage the Inbox", to: "/triage" },
  { label: "New item", to: "/new" },
  { label: "Loop", to: "/loop" },
  { label: "Runs", to: "/runs" },
  { label: "Features", to: "/features" },
  { label: "Closed items", to: "/closed" },
  { label: "Release readiness", to: "/release" },
  { label: "Check", to: "/check" },
  { label: "Ask", to: "/ask" },
  { label: "Settings", to: "/settings" },
];

/** Class of a palette entry. */
const ITEM = "flex cursor-default items-center gap-2 rounded-md px-2 py-1.5 text-sm aria-selected:bg-accent";

/**
 * The palette dialog.
 *
 * @param props - Open state and its setter.
 * @returns The element.
 */
export function CommandPalette({
  open,
  onOpenChange,
}: {
  /** Whether the palette is open. */
  open: boolean;
  /** Called to open or close it. */
  onOpenChange: (open: boolean) => void;
}) {
  const navigate = useNavigate();
  const [search, setSearch] = useState("");
  const board = useBoard("");
  const views = useViews();
  const items = useMemo(
    () =>
      (board.data?.sections ?? []).flatMap((s) => s.rows.filter((r): r is ItemRowView => r.kind === "item")),
    [board.data],
  );

  /**
   * Closes the palette and goes somewhere.
   *
   * @param to - The address.
   */
  const go = (to: string): void => {
    onOpenChange(false);
    setSearch("");
    // An address with a search part (`/backlog/all?q=...`, a saved view) goes as `href`: as `to`
    // the router would take the whole text for a path.
    void navigate({ href: to });
  };

  return (
    <DialogPrimitive.Root open={open} onOpenChange={onOpenChange}>
      <DialogPrimitive.Portal>
        <DialogPrimitive.Overlay className="fixed inset-0 z-50 bg-black/40" />
        <DialogPrimitive.Content className="fixed top-[14vh] left-1/2 z-50 w-[calc(100vw-2rem)] max-w-xl -translate-x-1/2 overflow-hidden rounded-lg border bg-popover shadow-2xl">
          <DialogPrimitive.Title className="sr-only">Command palette</DialogPrimitive.Title>
          <DialogPrimitive.Description className="sr-only">
            Go to a page or an item, or filter the backlog
          </DialogPrimitive.Description>
          <Command label="Command palette" loop>
            <Command.Input
              value={search}
              onValueChange={setSearch}
              placeholder="Type a page, an item, or a filter like area:encoding sev>=5"
              className="w-full border-b bg-transparent px-3 py-2.5 text-sm outline-none"
            />
            <Command.List className="max-h-[50vh] overflow-y-auto p-1">
              <Command.Empty className="px-3 py-4 text-sm text-muted-foreground">
                Nothing found.
              </Command.Empty>
              {search.trim() ? (
                <Command.Group
                  heading="Filter"
                  className="text-xs text-muted-foreground [&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-1"
                >
                  <Command.Item
                    value={`filter ${search}`}
                    onSelect={() => go(`/backlog/all?q=${encodeURIComponent(search.trim())}`)}
                    className={ITEM}
                  >
                    Filter the backlog: <code className="text-foreground">{search.trim()}</code>
                  </Command.Item>
                </Command.Group>
              ) : null}
              <Command.Group
                heading="Pages"
                className="text-xs text-muted-foreground [&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-1"
              >
                {PAGES.map((page) => (
                  <Command.Item
                    key={page.to}
                    value={`page ${page.label}`}
                    onSelect={() => go(page.to)}
                    className={`${ITEM} text-foreground`}
                  >
                    {page.label}
                  </Command.Item>
                ))}
              </Command.Group>
              {(views.data?.views.length ?? 0) > 0 ? (
                <Command.Group
                  heading="Saved views"
                  className="text-xs text-muted-foreground [&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-1"
                >
                  {views.data!.views.map((view) => (
                    <Command.Item
                      key={view.name}
                      value={`view ${view.name}`}
                      onSelect={() => go(view.url)}
                      className={`${ITEM} text-foreground`}
                    >
                      {view.name}
                    </Command.Item>
                  ))}
                </Command.Group>
              ) : null}
              <Command.Group
                heading="Items"
                className="text-xs text-muted-foreground [&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-1"
              >
                {items.map((item) => (
                  <Command.Item
                    key={item.slug}
                    value={`item ${item.title} ${item.slug}`}
                    onSelect={() => go(`/items/${item.slug}`)}
                    className={`${ITEM} text-foreground`}
                  >
                    <span className="truncate">{item.title}</span>
                    <span className="ml-auto shrink-0 text-xs text-muted-foreground">{item.section}</span>
                  </Command.Item>
                ))}
              </Command.Group>
            </Command.List>
          </Command>
        </DialogPrimitive.Content>
      </DialogPrimitive.Portal>
    </DialogPrimitive.Root>
  );
}
