// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Bulk changes (FR-033; user story 6): the bar shown while rows are marked, with block,
 * unblock, move and set-a-field for all marked items. The server runs one backlog command per item
 * through the write queue, each validated by the tool on its own, and answers per item - so one
 * refused item never hides the others' results.
 */

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { SECTION_NAMES, type Legend, type SectionName } from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import { Input, Label, NativeSelect } from "@/components/ui/primitives.tsx";
import { Dialog, DialogContent, DialogFooter } from "@/components/ui/overlays.tsx";
import { apiPost, ApiFailure } from "@/lib/api.ts";

/** The answer of `POST /api/bulk`. */
interface BulkAnswer {
  /** One result per item. */
  results: { slug: string; ok: boolean; refused?: string; findings?: unknown[] }[];
}

/** The bulk operations offered. */
type BulkKind = "block" | "unblock" | "move" | "set";

/** Fields a bulk `set` may change. */
const BULK_FIELDS = ["severity", "area", "who", "effort", "type"] as const;

/**
 * The bar of bulk actions and its dialog.
 *
 * @param props - The marked slugs, the board revision, the legend, and a function that clears
 *   the marks.
 * @returns The element, or nothing when no row is marked.
 */
export function BulkBar({
  slugs,
  revision,
  legend,
  onClear,
  disabledReason,
}: {
  /** The marked items. */
  slugs: string[];
  /** The board revision. */
  revision: string | null;
  /** The legend (field values). */
  legend: Legend | null;
  /** Clears the marks. */
  onClear: () => void;
  /** Why changes are not allowed now (empty when allowed). */
  disabledReason: string;
}) {
  const queryClient = useQueryClient();
  const [kind, setKind] = useState<BulkKind | null>(null);
  const [reason, setReason] = useState("");
  const [section, setSection] = useState<SectionName>("Next");
  const [field, setField] = useState<(typeof BULK_FIELDS)[number]>("severity");
  const [value, setValue] = useState("");
  const [answer, setAnswer] = useState<BulkAnswer | null>(null);
  const run = useMutation({
    mutationFn: (operation: Record<string, unknown>) =>
      apiPost<BulkAnswer>("/api/bulk", { base: { board: revision ?? undefined }, slugs, operation }),
    onSuccess: (result) => {
      setAnswer(result);
      void queryClient.invalidateQueries();
    },
    onError: (error) =>
      setAnswer({
        results: [
          { slug: "-", ok: false, refused: error instanceof ApiFailure ? error.message : String(error) },
        ],
      }),
  });
  if (slugs.length === 0) return null;
  /** Sends the chosen operation. */
  const submit = (): void => {
    if (kind === "block") run.mutate({ kind, reason: reason.trim() });
    else if (kind === "unblock") run.mutate({ kind, ...(reason.trim() ? { note: reason.trim() } : {}) });
    else if (kind === "move")
      run.mutate({ kind, section, ...(reason.trim() ? { reason: reason.trim() } : {}) });
    else if (kind === "set")
      run.mutate({
        kind,
        set: { [field]: field === "severity" ? Number(value) : value },
        ...(reason.trim() ? { reason: reason.trim() } : {}),
      });
  };
  const values =
    field === "area"
      ? legend?.areas
      : field === "who"
        ? legend?.who
        : field === "effort"
          ? legend?.efforts
          : field === "type"
            ? legend?.types
            : null;
  return (
    <div
      role="region"
      aria-label="Bulk actions"
      className="sticky bottom-0 z-30 flex flex-wrap items-center gap-2 border-t bg-card px-4 py-2 shadow-lg"
    >
      <span className="text-sm font-medium">{slugs.length} marked</span>
      {(["block", "unblock", "move", "set"] as const).map((k) => (
        <Button
          key={k}
          size="sm"
          variant="outline"
          disabled={disabledReason !== ""}
          title={disabledReason}
          onClick={() => setKind(k)}
        >
          {k === "set" ? "Set a field" : k[0]!.toUpperCase() + k.slice(1)}…
        </Button>
      ))}
      <Button size="sm" variant="ghost" className="ml-auto" onClick={onClear}>
        Clear the marks (Esc)
      </Button>
      <Dialog
        open={kind !== null}
        onOpenChange={(open) => {
          if (!open) {
            setKind(null);
            setAnswer(null);
          }
        }}
      >
        <DialogContent
          title={`${kind ?? ""} ${slugs.length} items`}
          description="One command per item; each is validated on its own."
          wide
        >
          {answer ? (
            <ul className="flex max-h-[50vh] flex-col gap-1 overflow-y-auto text-sm">
              {answer.results.map((r) => (
                <li key={r.slug} className={r.ok ? "text-ok" : "text-bad"}>
                  {r.ok ? "✓" : "✗"} {r.slug}
                  {r.refused ? `: ${r.refused}` : ""}
                </li>
              ))}
            </ul>
          ) : (
            <form
              className="flex flex-col gap-3"
              onSubmit={(e) => {
                e.preventDefault();
                submit();
              }}
            >
              {kind === "move" ? (
                <div>
                  <Label htmlFor="bulk-section">Section</Label>
                  <NativeSelect
                    id="bulk-section"
                    value={section}
                    onChange={(e) => setSection(e.target.value as SectionName)}
                  >
                    {SECTION_NAMES.filter((s) => s !== "In progress").map((s) => (
                      <option key={s}>{s}</option>
                    ))}
                  </NativeSelect>
                </div>
              ) : null}
              {kind === "set" ? (
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <Label htmlFor="bulk-field">Field</Label>
                    <NativeSelect
                      id="bulk-field"
                      value={field}
                      onChange={(e) => {
                        setField(e.target.value as (typeof BULK_FIELDS)[number]);
                        // A value of the previous field (severity 5) is no value of this one.
                        setValue("");
                      }}
                    >
                      {BULK_FIELDS.map((f) => (
                        <option key={f}>{f}</option>
                      ))}
                    </NativeSelect>
                  </div>
                  <div>
                    <Label htmlFor="bulk-value">Value</Label>
                    {values ? (
                      <NativeSelect id="bulk-value" value={value} onChange={(e) => setValue(e.target.value)}>
                        <option value="">choose…</option>
                        {values.map((v) => (
                          <option key={v.value}>{v.value}</option>
                        ))}
                      </NativeSelect>
                    ) : (
                      <Input
                        id="bulk-value"
                        type="number"
                        min={0}
                        max={10}
                        value={value}
                        onChange={(e) => setValue(e.target.value)}
                      />
                    )}
                  </div>
                </div>
              ) : null}
              <div>
                <Label htmlFor="bulk-reason">
                  {kind === "block" ? "Reason (required)" : "Reason or note (optional)"}
                </Label>
                <Input
                  id="bulk-reason"
                  value={reason}
                  required={kind === "block"}
                  onChange={(e) => setReason(e.target.value)}
                />
              </div>
              <DialogFooter>
                <Button type="submit" disabled={run.isPending || (kind === "set" && value === "")}>
                  {run.isPending ? "Working…" : `Apply to ${slugs.length}`}
                </Button>
              </DialogFooter>
            </form>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
