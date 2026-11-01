// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The write gate in the page (FR-023 of 344, analysis A4 §4.1; the channels of feature
 * 371): a banner when the backlog is read-only and why, a quiet note while changes are committed
 * at once (a loop lives) or land on `main` through the side worktree (a run is in progress), and
 * the hook every changing control uses to disable itself with the reason.
 */

import type { WriteChannel, WriteGate } from "@backlog-app/shared";
import { useAppStore } from "@/app/store.ts";

/** What a changing control needs to know. */
export interface WriteAccess {
  /** True when the backlog may be changed now. */
  writable: boolean;
  /** Why not (shown as the control's tooltip), empty when writable. */
  reason: string;
  /** How a change is applied now, null while not writable. */
  channel: WriteChannel | null;
  /** The item a run works on (never changed by the app), or null. */
  frozenSlug: string | null;
  /** The whole gate, null before the first state. */
  gate: WriteGate | null;
}

/**
 * The write access of changing controls.
 *
 * @returns Whether changes are allowed and why not.
 */
export function useWriteAccess(): WriteAccess {
  const gate = useAppStore((s) => s.state?.gate ?? null);
  const connected = useAppStore((s) => s.connected);
  if (!connected)
    return { writable: false, reason: "the connection to the app is lost", channel: null, frozenSlug: null, gate };
  if (!gate) return { writable: false, reason: "starting up", channel: null, frozenSlug: null, gate };
  return { writable: gate.writable, reason: gate.reason, channel: gate.channel, frozenSlug: gate.frozenSlug, gate };
}

/**
 * The reason a control of one item is disabled: the gate's reason, or that a run works on it.
 *
 * @param access - The write access.
 * @param slug - The item.
 * @returns The reason, empty when the item may be changed.
 */
export function itemReason(access: WriteAccess, slug: string): string {
  if (access.frozenSlug === slug) return "a run works on this item - it is never changed meanwhile";
  return access.writable ? "" : access.reason;
}

/** What the quiet note says per channel. */
const CHANNEL_NOTE: Record<WriteChannel, string | null> = {
  tray: null,
  commit: "The loop is alive: every change is committed on main at once (no tray, no undo).",
  "main-ref":
    "A run is in progress: every change lands on main at once and the run merges it at its end; the running item stays as it is.",
};

/**
 * The banner under the top bar while the backlog is read-only, or the note on how changes are
 * applied while the loop lives.
 *
 * @returns The element, or nothing on a plain writable main.
 */
export function GateBanner() {
  const gate = useAppStore((s) => s.state?.gate ?? null);
  if (!gate) return null;
  if (gate.writable) {
    const note = gate.channel ? CHANNEL_NOTE[gate.channel] : null;
    if (!note) return null;
    return (
      <div role="status" className="flex flex-wrap items-center gap-2 border-b border-info/40 bg-info/8 px-4 py-1.5 text-sm">
        <span className="font-medium">Live:</span>
        <span>
          {note}
          {gate.frozenSlug ? ` Running: ${gate.frozenSlug}.` : ""}
        </span>
      </div>
    );
  }
  if (gate.state === "degraded" && gate.reason.startsWith("starting")) return null;
  const tone =
    gate.state === "merge-in-progress" || gate.state === "degraded" || gate.state === "stale-lock"
      ? "border-bad/50 bg-bad/8"
      : "border-info/40 bg-info/8";
  const transient = gate.state === "run-starting" || gate.state === "run-on-main";
  return (
    <div role="status" className={`flex flex-wrap items-center gap-2 border-b px-4 py-1.5 text-sm ${tone}`}>
      <span className="font-medium">{transient ? "Read-only for a moment:" : "Read-only:"}</span>
      <span>{gate.reason}</span>
      {transient ? (
        <span className="text-xs text-muted-foreground">(the controls open again by themselves)</span>
      ) : null}
    </div>
  );
}
