// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The triage's *Place at* chooser (feature 414): a target section among the ordered sections
 * and a position in it, filled with the place the severity rule gives there, applied as one move
 * with the position. Only the section the item's type and who admit can be chosen - the backlog
 * tool refuses the others ("change type / who with 'set' first") - the others are shown disabled
 * with that reason. Enter in the field places, Escape leaves the field; a position that is not a
 * whole number of at least 1 is refused in the page, one past the end is accepted and said to go
 * last (the tool appends it).
 */

import { useState } from "react";
import {
  positionBySeverity,
  readTriagePosition,
  TRIAGE_TARGETS,
  type ItemRowView,
  type SectionName,
} from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import { Tooltip } from "@/components/ui/overlays.tsx";
import { Card, Input, Kbd, Label, NativeSelect } from "@/components/ui/primitives.tsx";

/** The id of the position field (key `m` of the triage page focuses it). */
export const TRIAGE_POSITION_ID = "triage-position";

/** Brings the focus to the chooser's position field and selects its text (key `m`). */
export function focusTriagePosition(): void {
  const field = document.getElementById(TRIAGE_POSITION_ID);
  if (field instanceof HTMLInputElement && !field.disabled) {
    field.focus();
    field.select();
  }
}

/**
 * The chooser. Mount it with the current item's slug as its `key`: a new item starts again from its
 * admitting section and default.
 *
 * @param props - The item's severity, its admitting section, the rows of the sections, the state of
 * the page and the placing action.
 * @returns The element.
 */
export function PlaceChooser({
  severity,
  admitting,
  rowsOf,
  disabledReason,
  pending,
  onPlace,
}: {
  /** The Inbox item's severity (the default follows it). */
  severity: number;
  /** The section the item's type and who admit (`admittingSection`): preselected, the only one allowed. */
  admitting: SectionName;
  /** The item rows of a section in the board's order. */
  rowsOf: (section: SectionName) => ItemRowView[];
  /** Why nothing can be placed now (the write gate), or empty. */
  disabledReason: string;
  /** A change is being sent. */
  pending: boolean;
  /** Places the item: one move with the position. */
  onPlace: (section: SectionName, position: number) => void;
}) {
  const [section, setSection] = useState<SectionName>(
    TRIAGE_TARGETS.includes(admitting) ? admitting : "Next",
  );
  // What the maintainer typed; null while the field follows the default of the section (which
  // moves with the board and the item's severity).
  const [typed, setTyped] = useState<string | null>(null);
  const rows = rowsOf(section);
  const fallback = String(positionBySeverity(severity, rows));
  const text = typed ?? fallback;
  const read = readTriagePosition(text, rows.length);
  const hint = "hint" in read ? read.hint : read.last ? "past the end: the item goes last" : "";
  const refused = "hint" in read;
  const disabled = disabledReason !== "" || pending;

  /** Places at the typed position, unless it is refused. */
  const confirm = (): void => {
    if (disabled || "hint" in read) return;
    onPlace(section, read.position);
  };

  const body = (
    <Card className="flex flex-col gap-2 p-3 text-sm">
      <div className="font-medium">
        Place at <Kbd>m</Kbd>
      </div>
      <div className="grid grid-cols-[1fr_5rem] gap-2">
        <div>
          <Label htmlFor="triage-section">Section</Label>
          <NativeSelect
            id="triage-section"
            aria-label="Target section"
            value={section}
            disabled={disabled}
            onChange={(e) => {
              setSection(e.target.value as SectionName);
              setTyped(null);
            }}
          >
            {TRIAGE_TARGETS.map((s) => (
              <option key={s} value={s} disabled={s !== admitting}>
                {s === admitting ? s : `${s} - its type / who belong in ${admitting}`}
              </option>
            ))}
          </NativeSelect>
        </div>
        <div>
          <Label htmlFor="triage-position">Position</Label>
          <Input
            id={TRIAGE_POSITION_ID}
            type="text"
            inputMode="numeric"
            aria-label="Position in the target section"
            aria-invalid={refused}
            aria-describedby={hint ? "triage-position-hint" : undefined}
            className="text-right tabular-nums"
            value={text}
            disabled={disabled}
            onChange={(e) => setTyped(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                e.preventDefault();
                confirm();
              } else if (e.key === "Escape") {
                e.preventDefault();
                e.currentTarget.blur();
              }
            }}
          />
        </div>
      </div>
      {hint ? (
        <div
          id="triage-position-hint"
          className={refused ? "text-xs text-bad" : "text-xs text-muted-foreground"}
        >
          {hint}
        </div>
      ) : (
        <div className="text-xs text-muted-foreground">
          {rows.length} item(s) in {section} now; the default follows the severity.
        </div>
      )}
      <Button disabled={disabled || refused} onClick={confirm}>
        Place <Kbd>Enter</Kbd>
      </Button>
    </Card>
  );
  return disabledReason ? (
    <Tooltip content={disabledReason}>
      <div tabIndex={0}>{body}</div>
    </Tooltip>
  ) : (
    body
  );
}
