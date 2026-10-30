// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The problem of a failed change, shown at the control (analysis A4 §4.2): the tool's text
 * verbatim and a plain-language line of what to do.
 */

import type { ChangeProblem } from "@/lib/changes.ts";
import { Alert } from "@/components/ui/primitives.tsx";

/** What to do, per error code. */
const ADVICE: Record<string, string> = {
  refused: "Nothing was written. Change the input and try again.",
  "changed-underneath":
    "The item or the backlog changed meanwhile (a run, a terminal or Claude Code). It was reloaded - check it and submit again; your text is kept.",
  "gate-closed": "The backlog is read-only right now - see the banner at the top.",
  busy: "Another backlog app is changing the backlog. Try again in a moment.",
  "invalid-request": "The input is not valid.",
};

/**
 * The problem box.
 *
 * @param props - The problem, or null.
 * @returns The element, or nothing.
 */
export function ChangeProblemBox({ problem }: { /** The problem. */ problem: ChangeProblem | null }) {
  if (!problem) return null;
  return (
    <Alert tone="bad">
      <div className="flex flex-col gap-1">
        <span className="font-medium whitespace-pre-wrap">{problem.message}</span>
        {ADVICE[problem.code] ? <span className="text-xs">{ADVICE[problem.code]}</span> : null}
      </div>
    </Alert>
  );
}
