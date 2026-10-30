// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The action bar of an item (user stories 3 and 4): only the changes the item's status
 * allows, each disabled with the write gate's reason while the backlog is read-only (FR-023).
 * Changes that belong to runs (`start`, closing with a feature) are never offered, and nothing is
 * offered for the item a run works on.
 */

import { useNavigate } from "@tanstack/react-router";
import {
  ArchiveIcon,
  BadgeCheckIcon,
  BanIcon,
  CheckCheckIcon,
  CircleOffIcon,
  FilePenIcon,
  GavelIcon,
  ListChecksIcon,
  MoreHorizontalIcon,
  MoveRightIcon,
  NotebookPenIcon,
  PlayIcon,
  RotateCcwIcon,
  SlidersHorizontalIcon,
  UnlockIcon,
} from "lucide-react";
import { useState, type ReactNode } from "react";
import type { Item } from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  Tooltip,
} from "@/components/ui/overlays.tsx";
import { useBoard, useLegend } from "@/lib/queries.ts";
import { useAppStore } from "@/app/store.ts";
import { useWriteAccess } from "@/features/gate/gate-banner.tsx";
import {
  DecideDialog,
  FieldsDialog,
  MoveDialog,
  ReasonDialog,
  StepsDialog,
  TextDialog,
  type DialogKind,
} from "./dialogs.tsx";
import { SectionEditorDialog } from "./section-editor.tsx";
import { useChange } from "@/lib/changes.ts";

/**
 * A toolbar button that is disabled with a reason while changes are not allowed.
 *
 * @param props - Label, icon, click handler, the reason it is disabled.
 * @returns The element.
 */
function ActionButton({
  label,
  icon,
  onClick,
  disabledReason,
  variant = "outline",
}: {
  /** Label. */ label: string;
  /** Icon. */ icon: ReactNode;
  /** Handler. */ onClick: () => void;
  /** Why disabled. */ disabledReason: string;
  /** Look. */ variant?: "outline" | "default";
}) {
  const button = (
    <Button size="sm" variant={variant} disabled={disabledReason !== ""} onClick={onClick} aria-label={label}>
      {icon} {label}
    </Button>
  );
  // A disabled button gets no pointer events; the wrapper carries the tooltip.
  return disabledReason ? (
    <Tooltip content={disabledReason}>
      <span tabIndex={0}>{button}</span>
    </Tooltip>
  ) : (
    button
  );
}

/**
 * The action bar.
 *
 * @param props - The item.
 * @returns The element.
 */
export function ItemActions({ item }: { /** The item. */ item: Item }) {
  const [open, setOpen] = useState<DialogKind | "edit" | null>(null);
  const access = useWriteAccess();
  const board = useBoard("");
  const legend = useLegend();
  const navigate = useNavigate();
  const loop = useAppStore((s) => s.state?.loop ?? null);
  const reply = useChange();
  const running = loop?.lock?.slug === item.slug || loop?.slug === item.slug;
  const reason = running
    ? "a run works on this item - it is never changed meanwhile"
    : access.writable
      ? ""
      : access.reason;
  const props = {
    item,
    boardRevision: board.data?.revision ?? null,
    legend: legend.data ?? null,
    onClose: () => setOpen(null),
  };
  const status = item.status;
  const closedState = status === "parked" || status === "rejected";

  return (
    <div className="flex flex-wrap gap-1.5" role="toolbar" aria-label="Item actions">
      {item.type === "decision" && !closedState ? (
        <ActionButton
          label="Decide"
          icon={<GavelIcon />}
          variant="default"
          onClick={() => setOpen("decide")}
          disabledReason={reason}
        />
      ) : null}
      {item.steps.length > 0 ? (
        <ActionButton
          label="Record steps"
          icon={<ListChecksIcon />}
          variant="default"
          onClick={() => setOpen("steps")}
          disabledReason={reason}
        />
      ) : null}
      {status === "new" ? (
        <ActionButton
          label="Triage"
          icon={<MoveRightIcon />}
          variant="default"
          onClick={() => void navigate({ to: "/triage", search: { at: item.slug } })}
          disabledReason=""
        />
      ) : null}
      {!closedState && status !== "in-progress" ? (
        <ActionButton
          label="Move"
          icon={<MoveRightIcon />}
          onClick={() => setOpen("move")}
          disabledReason={reason}
        />
      ) : null}
      {status === "open" ? (
        <ActionButton
          label="Block"
          icon={<BanIcon />}
          onClick={() => setOpen("block")}
          disabledReason={reason}
        />
      ) : null}
      {status === "blocked" ? (
        <ActionButton
          label="Unblock"
          icon={<UnlockIcon />}
          onClick={() => setOpen("unblock")}
          disabledReason={reason}
        />
      ) : null}
      {closedState ? (
        <ActionButton
          label="Reopen"
          icon={<RotateCcwIcon />}
          onClick={() => setOpen("reopen")}
          disabledReason={reason}
        />
      ) : null}
      <ActionButton
        label="Edit text"
        icon={<FilePenIcon />}
        onClick={() => setOpen("edit")}
        disabledReason={reason}
      />
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button size="sm" variant="outline" aria-label="More actions">
            <MoreHorizontalIcon />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem disabled={reason !== ""} onSelect={() => setOpen("fields")}>
            <SlidersHorizontalIcon /> Edit fields…
          </DropdownMenuItem>
          <DropdownMenuItem disabled={reason !== ""} onSelect={() => setOpen("log")}>
            <NotebookPenIcon /> Add a log line…
          </DropdownMenuItem>
          <DropdownMenuItem disabled={reason !== ""} onSelect={() => setOpen("verify")}>
            <BadgeCheckIcon /> Mark verified at main…
          </DropdownMenuItem>
          {item.files.reply ? (
            <DropdownMenuItem
              disabled={reason !== "" || reply.mutation.isPending}
              onSelect={() =>
                reply.mutation.mutate({
                  path: `/api/items/${item.slug}/reply`,
                  body: {
                    base: { item: item.revision },
                    state: item.files.reply?.state === "sent" ? "not-sent" : "sent",
                  },
                })
              }
            >
              <CheckCheckIcon /> Mark the GitHub answer{" "}
              {item.files.reply.state === "sent" ? "not sent" : "sent"}
            </DropdownMenuItem>
          ) : null}
          <DropdownMenuItem
            onSelect={() => void navigate({ to: "/new", search: { type: "bug", from: item.slug } })}
          >
            <PlayIcon /> New item related to this…
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          {!closedState && status !== "in-progress" ? (
            <>
              <DropdownMenuItem disabled={reason !== ""} onSelect={() => setOpen("park")}>
                <ArchiveIcon /> Park…
              </DropdownMenuItem>
              <DropdownMenuItem disabled={reason !== ""} onSelect={() => setOpen("reject")}>
                <CircleOffIcon /> Reject…
              </DropdownMenuItem>
            </>
          ) : null}
          {status !== "in-progress" ? (
            <DropdownMenuItem disabled={reason !== ""} onSelect={() => setOpen("close")} className="text-bad">
              <CheckCheckIcon /> Close (fixed elsewhere or obsolete)…
            </DropdownMenuItem>
          ) : null}
        </DropdownMenuContent>
      </DropdownMenu>
      {open === "move" ? <MoveDialog {...props} /> : null}
      {open === "block" ||
      open === "unblock" ||
      open === "park" ||
      open === "reject" ||
      open === "reopen" ||
      open === "close" ? (
        <ReasonDialog {...props} kind={open} />
      ) : null}
      {open === "fields" ? <FieldsDialog {...props} /> : null}
      {open === "log" || open === "verify" ? <TextDialog {...props} kind={open} /> : null}
      {open === "decide" ? <DecideDialog {...props} /> : null}
      {open === "steps" ? <StepsDialog {...props} /> : null}
      {open === "edit" ? <SectionEditorDialog item={item} onClose={() => setOpen(null)} /> : null}
    </div>
  );
}
