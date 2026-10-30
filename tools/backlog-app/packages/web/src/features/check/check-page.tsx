// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The consistency check (FR-012): the findings of the backlog tool's 18 rules grouped by
 * rule, links to the items, and the mechanical fix the tool offers (`sync` rewrites the derived
 * cells and the numbering). Fixes that need git (conflict markers, a broken header) stay in the
 * terminal.
 */

import { Link } from "@tanstack/react-router";
import { useMemo } from "react";
import type { Finding } from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import { Alert, Skeleton } from "@/components/ui/primitives.tsx";
import { ChangeProblemBox } from "@/components/change-problem.tsx";
import { useChange } from "@/lib/changes.ts";
import { useCheck } from "@/lib/queries.ts";
import { useWriteAccess } from "@/features/gate/gate-banner.tsx";

/**
 * The item slug of a finding's path, if it is an item file.
 *
 * @param finding - The finding.
 * @returns The slug, or null.
 */
function slugOf(finding: Finding): string | null {
  return /^backlog\/items\/([a-z0-9-]+)\//.exec(finding.path)?.[1] ?? null;
}

/**
 * The check page.
 *
 * @returns The element.
 */
export function CheckPage() {
  const check = useCheck();
  const access = useWriteAccess();
  const { mutation, problem } = useChange();
  const groups = useMemo(() => {
    const map = new Map<string, Finding[]>();
    for (const f of check.data?.findings ?? []) map.set(f.rule, [...(map.get(f.rule) ?? []), f]);
    return [...map];
  }, [check.data]);
  return (
    <div className="mx-auto flex w-full max-w-5xl flex-col gap-3 p-4">
      <div className="flex items-center gap-2">
        <h1 className="text-lg font-semibold">Check</h1>
        <Button
          size="sm"
          variant="outline"
          className="ml-auto"
          disabled={!access.writable || mutation.isPending}
          title={access.writable ? "Rewrite the derived cells and numbering of BACKLOG.md" : access.reason}
          onClick={() => mutation.mutate({ path: "/api/check/sync", body: {} })}
        >
          Run sync
        </Button>
      </div>
      <ChangeProblemBox problem={problem} />
      {check.isLoading ? <Skeleton className="h-24" /> : null}
      {check.data?.total === 0 ? <Alert tone="ok">The backlog is consistent: no findings.</Alert> : null}
      {groups.map(([rule, findings]) => (
        <section key={rule} aria-label={rule}>
          <h2 className="text-sm font-semibold">
            {rule} <span className="font-normal text-muted-foreground">({findings.length})</span>
          </h2>
          <ul className="mt-1 flex flex-col gap-1 text-sm">
            {findings.map((f) => {
              const slug = slugOf(f);
              return (
                <li key={`${f.path}:${f.line}:${f.message}`} className="font-mono text-xs">
                  {slug ? (
                    <Link
                      to="/items/$slug"
                      params={{ slug }}
                      search={{ tab: "" }}
                      className="text-primary hover:underline"
                    >
                      {f.path}:{f.line}
                    </Link>
                  ) : (
                    `${f.path}:${f.line}`
                  )}{" "}
                  <span className="font-sans">{f.message}</span>
                </li>
              );
            })}
          </ul>
        </section>
      ))}
    </div>
  );
}
