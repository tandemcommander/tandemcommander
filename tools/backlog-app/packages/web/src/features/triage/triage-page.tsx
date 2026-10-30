// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Inbox triage (FR-027; analysis A4 §3.6): the Inbox items one after another with a
 * suggested place, accepted, adjusted or skipped with single keys - `n` Next at the suggested
 * position, `d` Decisions, `p` Person steps, `k` park, `x` reject, `s` skip, digits set the
 * severity. The suggestion follows the admission rules and the severity order; *Check with AI*
 * asks the local Claude for a second opinion (a proposal, applied only on confirmation).
 */

import { getRouteApi, useNavigate } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { suggestPlacement, type ItemRowView, type SectionName } from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import { Alert, Card, Kbd } from "@/components/ui/primitives.tsx";
import { ChangeProblemBox } from "@/components/change-problem.tsx";
import { useChange } from "@/lib/changes.ts";
import { useShortcuts, type Shortcut } from "@/lib/hotkeys.ts";
import { useBoard, useItem } from "@/lib/queries.ts";
import { useWriteAccess } from "@/features/gate/gate-banner.tsx";
import { ItemView } from "@/features/item/item-view.tsx";
import { ReasonDialog } from "@/features/item/dialogs.tsx";
import { JobCard, useAiJob } from "@/features/ai/ai-job.tsx";

/** The route. */
const route = getRouteApi("/triage");

/**
 * The triage page.
 *
 * @returns The element.
 */
export function TriagePage() {
  const { at } = route.useSearch();
  const navigate = useNavigate();
  const board = useBoard("");
  const access = useWriteAccess();
  const [skipped, setSkipped] = useState<string[]>([]);
  const [reasonKind, setReasonKind] = useState<"park" | "reject" | null>(null);
  const ai = useAiJob();
  const { mutation, problem } = useChange();
  const inbox = useMemo(
    () =>
      board.data?.sections
        .find((s) => s.name === "Inbox")
        ?.rows.filter((r): r is ItemRowView => r.kind === "item") ?? [],
    [board.data],
  );
  const pending = inbox.filter((r) => !skipped.includes(r.slug));
  const current = pending.find((r) => r.slug === at) ?? pending[0] ?? null;
  const item = useItem(current?.slug ?? null);
  /**
   * The rows of a section.
   *
   * @param name - The section.
   * @returns Its item rows.
   */
  const rowsOf = (name: SectionName): ItemRowView[] =>
    board.data?.sections
      .find((s) => s.name === name)
      ?.rows.filter((r): r is ItemRowView => r.kind === "item") ?? [];
  const suggestion = current
    ? suggestPlacement(
        current,
        rowsOf(
          current.type === "decision"
            ? "Decisions for the maintainer"
            : current.type === "person-step" || current.who === "person"
              ? "Person steps"
              : "Next",
        ),
      )
    : null;

  /**
   * Places the current item.
   *
   * @param section - Target section.
   * @param position - Position (default: the end).
   */
  const place = (section: SectionName, position?: number): void => {
    if (!current || !item.data) return;
    mutation.mutate({
      path: `/api/items/${current.slug}/move`,
      body: {
        base: { board: board.data?.revision, item: item.data.revision },
        section,
        ...(position ? { position } : {}),
      },
    });
  };
  /**
   * Sets the current item's severity.
   *
   * @param severity - 0-10.
   */
  const setSeverity = (severity: number): void => {
    if (!current || !item.data) return;
    mutation.mutate({
      path: `/api/items/${current.slug}/fields`,
      body: { base: { item: item.data.revision }, set: { severity }, reason: `triage: severity ${severity}` },
    });
  };
  /** Skips the current item for this session. */
  const skip = (): void => {
    if (current) setSkipped((s) => [...s, current.slug]);
    void navigate({ to: "/triage", search: { at: "" }, replace: true });
  };

  const shortcuts = useMemo<Shortcut[]>(() => {
    if (!current || !access.writable || reasonKind) return [{ keys: "s", label: "Skip", run: skip }];
    return [
      {
        keys: "n",
        label: "Place as suggested",
        run: () => suggestion && place(suggestion.section, suggestion.position),
      },
      { keys: "d", label: "To Decisions", run: () => place("Decisions for the maintainer") },
      { keys: "p", label: "To Person steps", run: () => place("Person steps") },
      { keys: "k", label: "Park", run: () => setReasonKind("park") },
      { keys: "x", label: "Reject", run: () => setReasonKind("reject") },
      { keys: "s", label: "Skip", run: skip },
      { keys: "l", label: "Leave in the Inbox", run: skip },
      ...Array.from({ length: 10 }, (_, n) => ({
        keys: String(n),
        label: `Severity ${n}`,
        run: () => setSeverity(n),
      })),
      {
        keys: "+",
        label: "Severity +1",
        run: () => current && setSeverity(Math.min(10, current.severity + 1)),
      },
      {
        keys: "-",
        label: "Severity -1",
        run: () => current && setSeverity(Math.max(0, current.severity - 1)),
      },
    ];
    // place / setSeverity read the latest item through closures of this render.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [current, access.writable, reasonKind, suggestion, item.data]);
  useShortcuts(shortcuts);

  if (!board.data) return null;
  if (!current) {
    return (
      <div className="mx-auto max-w-3xl p-4">
        <h1 className="text-lg font-semibold">Triage</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          {inbox.length === 0
            ? "The Inbox is empty. Nothing to triage."
            : "Every Inbox item was skipped in this session."}{" "}
          Last triaged {board.data.lastTriaged ?? "never"}.
        </p>
      </div>
    );
  }
  const proposal =
    ai.job?.state === "done"
      ? (ai.job.proposal as {
          verdict?: string;
          section?: SectionName;
          position?: number;
          reason?: string;
        } | null)
      : null;
  return (
    <div className="mx-auto grid w-full max-w-6xl gap-4 p-4 lg:grid-cols-[1fr_20rem]">
      <div className="flex min-w-0 flex-col gap-2">
        <h1 className="text-lg font-semibold">
          Triage{" "}
          <span className="text-sm font-normal text-muted-foreground">
            {inbox.length - skipped.length} left
          </span>
        </h1>
        <Card className="overflow-hidden">
          <ItemView slug={current.slug} compact />
        </Card>
      </div>
      <aside className="flex flex-col gap-3">
        {!access.writable ? <Alert tone="info">{access.reason}</Alert> : null}
        {suggestion ? (
          <Card className="flex flex-col gap-2 p-3 text-sm">
            <div className="font-medium">
              Suggested: {suggestion.section} #{suggestion.position}
            </div>
            <div className="text-xs text-muted-foreground">{suggestion.why}</div>
            <Button
              disabled={!access.writable || mutation.isPending}
              onClick={() => place(suggestion.section, suggestion.position)}
            >
              Accept <Kbd>n</Kbd>
            </Button>
          </Card>
        ) : null}
        <div className="grid grid-cols-2 gap-2">
          <Button
            variant="outline"
            disabled={!access.writable}
            onClick={() => place("Decisions for the maintainer")}
          >
            Decisions <Kbd>d</Kbd>
          </Button>
          <Button variant="outline" disabled={!access.writable} onClick={() => place("Person steps")}>
            Person <Kbd>p</Kbd>
          </Button>
          <Button variant="outline" disabled={!access.writable} onClick={() => setReasonKind("park")}>
            Park <Kbd>k</Kbd>
          </Button>
          <Button variant="outline" disabled={!access.writable} onClick={() => setReasonKind("reject")}>
            Reject <Kbd>x</Kbd>
          </Button>
          <Button variant="ghost" onClick={skip} className="col-span-2">
            Skip for now <Kbd>s</Kbd>
          </Button>
        </div>
        <p className="text-xs text-muted-foreground">
          Severity: <Kbd>0</Kbd>–<Kbd>9</Kbd>, <Kbd>+</Kbd>/<Kbd>-</Kbd> (now {current.severity}).
        </p>
        <ChangeProblemBox problem={problem} />
        <Button
          variant="secondary"
          disabled={ai.starting || ai.job?.state === "running"}
          onClick={() => ai.start("triage-check", { slug: current.slug })}
        >
          Check with AI
        </Button>
        {ai.job ? <JobCard job={ai.job} onCancel={ai.cancel} /> : null}
        {proposal ? (
          <Card className="flex flex-col gap-2 p-3 text-sm">
            <div className="font-medium">AI: {proposal.verdict ?? "?"}</div>
            {proposal.reason ? <div className="text-xs">{proposal.reason}</div> : null}
            {proposal.section ? (
              <Button
                size="sm"
                disabled={!access.writable}
                onClick={() => place(proposal.section!, proposal.position)}
              >
                Place at {proposal.section}
                {proposal.position ? ` #${proposal.position}` : ""}
              </Button>
            ) : null}
          </Card>
        ) : null}
      </aside>
      {reasonKind && item.data ? (
        <ReasonDialog
          item={item.data}
          boardRevision={board.data.revision}
          legend={null}
          kind={reasonKind}
          onClose={() => setReasonKind(null)}
        />
      ) : null}
    </div>
  );
}
