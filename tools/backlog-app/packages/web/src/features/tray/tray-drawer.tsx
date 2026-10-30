// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The change tray (FR-034, FR-035; research R11): the counter of uncommitted changes in the
 * top bar, and a panel with the changes, the backlog files changed outside the app, an editable
 * commit message, the commit, and the undo of the newest change (also Ctrl+Z).
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { GitCommitHorizontalIcon, Undo2Icon } from "lucide-react";
import { useMemo, useState } from "react";
import { toast } from "sonner";
import type { Tray } from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import { Badge, Label, Textarea } from "@/components/ui/primitives.tsx";
import { Dialog, SheetContent } from "@/components/ui/overlays.tsx";
import { ChangeProblemBox } from "@/components/change-problem.tsx";
import { apiGet, apiPost, ApiFailure } from "@/lib/api.ts";
import { useShortcuts, type Shortcut } from "@/lib/hotkeys.ts";
import { relativeTime } from "@/lib/utils.ts";
import { useAppStore } from "@/app/store.ts";
import { useWriteAccess } from "@/features/gate/gate-banner.tsx";

/**
 * The tray's data.
 *
 * @param enabled - Fetch it.
 * @returns The query.
 */
function useTray(enabled: boolean) {
  return useQuery({
    queryKey: ["tray"],
    queryFn: ({ signal }) => apiGet<Tray>("/api/tray", signal),
    enabled,
  });
}

/**
 * Undo of the newest change, shared by the panel and Ctrl+Z.
 *
 * @returns The mutation.
 */
function useUndo() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (changeId: string) => apiPost("/api/tray/undo", { changeId }),
    onSuccess: () => {
      toast.success("Undone");
      void queryClient.invalidateQueries();
    },
    onError: (error) => toast.error(error instanceof ApiFailure ? error.message : String(error)),
  });
}

/**
 * The panel.
 *
 * @param props - Open state and its setter.
 * @returns The element.
 */
function TrayPanel({
  open,
  onOpenChange,
}: {
  /** Open. */ open: boolean;
  /** Setter. */ onOpenChange: (open: boolean) => void;
}) {
  const tray = useTray(open);
  const undo = useUndo();
  const access = useWriteAccess();
  const queryClient = useQueryClient();
  const [message, setMessage] = useState("");
  const [outside, setOutside] = useState<string[]>([]);
  const [problem, setProblem] = useState<{ code: string; message: string } | null>(null);
  const [messageOf, setMessageOf] = useState<Tray | undefined>(undefined);
  // A new tray proposes a new message (adjusted during render).
  if (tray.data && tray.data !== messageOf) {
    setMessageOf(tray.data);
    setMessage(tray.data.proposedMessage);
  }
  const commit = useMutation({
    mutationFn: () => apiPost<{ commit: string }>("/api/tray/commit", { message, includeOutside: outside }),
    onMutate: () => setProblem(null),
    onSuccess: (answer) => {
      toast.success(`Committed ${answer.commit.slice(0, 8)} on main`);
      setOutside([]);
      void queryClient.invalidateQueries();
      onOpenChange(false);
    },
    onError: (error) =>
      setProblem(
        error instanceof ApiFailure
          ? { code: error.code, message: error.message }
          : { code: "network", message: String(error) },
      ),
  });
  const pending = tray.data?.pending ?? [];
  const newest = pending.at(-1);
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <SheetContent title={`Uncommitted changes (${pending.length})`}>
        <div className="flex flex-col gap-4">
          <p className="text-sm text-muted-foreground">
            Changes made in the app stay uncommitted until you commit them here. The loop starts only on a
            clean tree, so they are committed automatically before you start or resume it from the app.
            Nothing is ever pushed.
          </p>
          {pending.length === 0 ? <p className="text-sm">Nothing to commit.</p> : null}
          <ol className="flex flex-col gap-1.5">
            {pending.map((change) => (
              <li key={change.id} className="rounded-md border p-2 text-sm">
                <div className="flex items-start gap-2">
                  <span className="flex-1">{change.summary}</span>
                  <span className="shrink-0 text-xs text-muted-foreground">{relativeTime(change.at)}</span>
                </div>
                {change.reason ? <div className="text-xs text-muted-foreground">{change.reason}</div> : null}
                <div className="mt-1 flex flex-wrap gap-1">
                  {change.files.map((f) => (
                    <Badge key={f.path} variant="outline" className="font-mono text-[11px]">
                      {f.after === null ? "deleted " : f.before === null ? "new " : ""}
                      {f.path.replace(/^backlog\//, "")}
                    </Badge>
                  ))}
                </div>
                {change.id === newest?.id ? (
                  <Button
                    size="sm"
                    variant="ghost"
                    className="mt-1"
                    disabled={undo.isPending || !access.writable}
                    onClick={() => undo.mutate(change.id)}
                  >
                    <Undo2Icon /> Undo
                  </Button>
                ) : null}
              </li>
            ))}
          </ol>
          {(tray.data?.outside.length ?? 0) > 0 ? (
            <fieldset className="flex flex-col gap-1 rounded-md border p-2">
              <legend className="px-1 text-xs font-medium">
                Changed outside the app (not included unless ticked)
              </legend>
              {tray.data!.outside.map((path) => (
                <label key={path} className="flex items-center gap-2 font-mono text-xs">
                  <input
                    type="checkbox"
                    checked={outside.includes(path)}
                    onChange={(e) =>
                      setOutside((o) => (e.target.checked ? [...o, path] : o.filter((p) => p !== path)))
                    }
                  />
                  {path}
                </label>
              ))}
            </fieldset>
          ) : null}
          {pending.length > 0 || outside.length > 0 ? (
            <>
              <div>
                <Label htmlFor="commit-message">Commit message</Label>
                <Textarea
                  id="commit-message"
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  rows={8}
                />
              </div>
              <ChangeProblemBox problem={problem} />
              <Button
                disabled={commit.isPending || !message.trim() || !access.writable}
                onClick={() => commit.mutate()}
              >
                <GitCommitHorizontalIcon /> {commit.isPending ? "Committing…" : "Commit on main"}
              </Button>
              {!access.writable ? <p className="text-xs text-muted-foreground">{access.reason}</p> : null}
            </>
          ) : null}
        </div>
      </SheetContent>
    </Dialog>
  );
}

/**
 * The tray counter in the top bar; opens the panel. Ctrl+Z undoes the newest change.
 *
 * @returns The element.
 */
export function TrayButton() {
  const pending = useAppStore((s) => s.state?.tray.pending ?? 0);
  const [open, setOpen] = useState(false);
  const tray = useTray(pending > 0);
  const undo = useUndo();
  const shortcuts = useMemo<Shortcut[]>(
    () => [
      {
        keys: "ctrl+z",
        label: "Undo the newest uncommitted change",
        run: () => {
          const newest = tray.data?.pending.at(-1);
          if (newest) undo.mutate(newest.id);
        },
      },
    ],
    [tray.data, undo],
  );
  useShortcuts(shortcuts);
  return (
    <>
      <Button
        variant={pending > 0 ? "secondary" : "ghost"}
        size="sm"
        onClick={() => setOpen(true)}
        aria-label={`${pending} uncommitted change${pending === 1 ? "" : "s"}`}
        className={pending > 0 ? "border border-warn/50" : "text-muted-foreground"}
      >
        <GitCommitHorizontalIcon /> {pending > 0 ? `${pending} uncommitted` : "committed"}
      </Button>
      <TrayPanel open={open} onOpenChange={setOpen} />
    </>
  );
}
