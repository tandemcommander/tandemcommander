// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The write gate in the page (FR-023, analysis A4 §4.1): a banner when the backlog is
 * read-only and why, and the hook every changing control uses to disable itself with the reason.
 */

import type { WriteGate } from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import { useAppStore } from "@/app/store.ts";
import { useLoopCommand } from "@/features/loop/loop-status.tsx";

/** What a changing control needs to know. */
export interface WriteAccess {
  /** True when the backlog may be changed now. */
  writable: boolean;
  /** Why not (shown as the control's tooltip), empty when writable. */
  reason: string;
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
  if (!connected) return { writable: false, reason: "the connection to the app is lost", gate };
  if (!gate) return { writable: false, reason: "starting up", gate };
  return { writable: gate.writable, reason: gate.reason, gate };
}

/**
 * The banner under the top bar while the backlog is read-only.
 *
 * @returns The element, or nothing while writable.
 */
export function GateBanner() {
  const gate = useAppStore((s) => s.state?.gate ?? null);
  const pause = useLoopCommand("pause");
  if (!gate || gate.writable) return null;
  if (gate.state === "degraded" && gate.reason.startsWith("starting")) return null;
  const tone =
    gate.state === "merge-in-progress" || gate.state === "degraded" || gate.state === "stale-lock"
      ? "border-bad/50 bg-bad/8"
      : "border-info/40 bg-info/8";
  return (
    <div role="status" className={`flex flex-wrap items-center gap-2 border-b px-4 py-1.5 text-sm ${tone}`}>
      <span className="font-medium">Read-only:</span>
      <span>{gate.reason}</span>
      {gate.state === "loop-between-runs" ? (
        <Button
          size="sm"
          variant="outline"
          className="ml-auto"
          disabled={pause.isPending}
          onClick={() => pause.mutate()}
        >
          Pause the loop to make changes
        </Button>
      ) : null}
    </div>
  );
}
