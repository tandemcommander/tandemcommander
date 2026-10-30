// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Badges of item fields: severity, status, type and run outcome. Information is never
 * carried by colour alone (FR-042): every badge shows its value as text, the colour only helps.
 */

import { Badge } from "@/components/ui/primitives.tsx";
import { cn, severityBand } from "@/lib/utils.ts";

/** Text and background classes per severity band. */
const SEVERITY_CLASS: Record<ReturnType<typeof severityBand>, string> = {
  critical: "bg-sev-critical/15 text-sev-critical border-sev-critical/40",
  high: "bg-sev-high/15 text-sev-high border-sev-high/40",
  medium: "bg-sev-medium/15 text-sev-medium border-sev-medium/40",
  low: "bg-sev-low/12 text-sev-low border-sev-low/30",
  trivial: "bg-muted text-sev-trivial",
};

/**
 * The severity as a number in its band's colour.
 *
 * @param props - The severity.
 * @returns The element.
 */
export function SeverityBadge({ severity }: { /** 0-10. */ severity: number }) {
  return (
    <Badge
      className={cn("min-w-6 justify-center tabular-nums", SEVERITY_CLASS[severityBand(severity)])}
      title={`severity ${severity}`}
    >
      {severity}
    </Badge>
  );
}

/** Classes per status. */
const STATUS_CLASS: Record<string, string> = {
  new: "text-status-new border-status-new/40",
  open: "text-status-open border-status-open/40",
  blocked: "text-status-blocked border-status-blocked/50 bg-status-blocked/8",
  "in-progress": "text-status-in-progress border-status-in-progress/40 bg-status-in-progress/8",
  parked: "text-status-parked",
  rejected: "text-status-rejected",
};

/**
 * The status in its colour.
 *
 * @param props - The status.
 * @returns The element.
 */
export function StatusBadge({ status }: { /** Legend status. */ status: string }) {
  return (
    <Badge variant="outline" className={STATUS_CLASS[status]}>
      {status}
    </Badge>
  );
}

/**
 * The item type.
 *
 * @param props - The type.
 * @returns The element.
 */
export function TypeBadge({ type }: { /** Legend type. */ type: string }) {
  return <Badge variant="default">{type}</Badge>;
}

/** Classes per run outcome. */
const OUTCOME_CLASS: Record<string, string> = {
  closed: "text-ok border-ok/40 bg-ok/8",
  blocked: "text-bad border-bad/40 bg-bad/8",
  "not-reproduced": "text-muted-foreground",
  split: "text-info border-info/40",
  triaged: "text-info border-info/40",
  running: "text-ok border-ok/40",
  killed: "text-bad border-bad/40",
  failed: "text-bad border-bad/40 bg-bad/8",
  lost: "text-bad border-bad/40 bg-bad/8",
};

/**
 * A run outcome.
 *
 * @param props - The outcome.
 * @returns The element.
 */
export function OutcomeBadge({ outcome }: { /** Run outcome. */ outcome: string }) {
  return (
    <Badge variant="outline" className={OUTCOME_CLASS[outcome]}>
      {outcome}
    </Badge>
  );
}
