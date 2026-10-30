// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Questions about the backlog and its runs (FR-037; analysis A4 §3.13). A question that the
 * filter language can answer is offered as a filter first (instant, exact); any question can also
 * go to the local Claude, which only reads the repository and answers with links to the items and
 * runs it relied on. A question never changes the backlog.
 */

import { getRouteApi, Link, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { parseFilter } from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import { Alert, Card, Input } from "@/components/ui/primitives.tsx";
import { Markdown } from "@/components/markdown.tsx";
import { useLegend } from "@/lib/queries.ts";
import { useAppStore } from "@/app/store.ts";
import { JobCard, useAiJob } from "@/features/ai/ai-job.tsx";

/** The route. */
const route = getRouteApi("/ask");

/** The answer of an `ask` job. */
interface AskAnswer {
  /** The answer in Markdown. */
  answer: string;
  /** Items it relied on. */
  items?: string[];
  /** Runs it relied on. */
  runs?: string[];
}

/**
 * The Ask page.
 *
 * @returns The element.
 */
export function AskPage() {
  const { q } = route.useSearch();
  const navigate = useNavigate();
  const legend = useLegend();
  const branch = useAppStore((s) => s.state?.repo.branch ?? "?");
  const [question, setQuestion] = useState(q);
  const ai = useAiJob();
  // A question written in the filter language (only known keys, no errors) is a filter.
  const asFilter = legend.data ? parseFilter(question, legend.data) : null;
  const filterable =
    asFilter !== null && asFilter.errors.length === 0 && asFilter.terms.some((t) => t.kind === "field");
  const answer = ai.job?.state === "done" ? (ai.job.proposal as AskAnswer | null) : null;
  return (
    <div className="mx-auto flex w-full max-w-4xl flex-col gap-3 p-4">
      <h1 className="text-lg font-semibold">Ask</h1>
      <form
        className="flex gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          if (!question.trim()) return;
          void navigate({ to: "/ask", search: { q: question.trim() }, replace: true });
          ai.start("ask", { question: question.trim() });
        }}
      >
        <Input
          aria-label="Your question"
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          placeholder="e.g. which encoding bugs are agent-doable and small? what did the loop do last night?"
        />
        <Button type="submit" disabled={!question.trim() || ai.starting || ai.job?.state === "running"}>
          Ask Claude
        </Button>
      </form>
      {filterable ? (
        <Alert tone="info">
          This reads like a filter:{" "}
          <Link
            to="/backlog/$section"
            params={{ section: "all" }}
            search={{ q: question.trim(), sel: "" }}
            className="font-medium text-primary underline"
          >
            show the matching items
          </Link>
          .
        </Alert>
      ) : null}
      {branch !== "main" ? (
        <Alert tone="warn">The working tree is on {branch}; Claude reads that branch's files.</Alert>
      ) : null}
      {ai.job ? <JobCard job={ai.job} onCancel={ai.cancel} /> : null}
      {answer ? (
        <Card className="flex flex-col gap-2 p-4">
          <Markdown>{answer.answer}</Markdown>
          {answer.items?.length ? (
            <div className="flex flex-wrap gap-2 text-sm">
              Items:{" "}
              {answer.items.map((slug) => (
                <Link
                  key={slug}
                  to="/items/$slug"
                  params={{ slug }}
                  search={{ tab: "" }}
                  className="text-primary hover:underline"
                >
                  {slug}
                </Link>
              ))}
            </div>
          ) : null}
          {answer.runs?.length ? (
            <div className="flex flex-wrap gap-2 text-sm">
              Runs:{" "}
              {answer.runs.map((id) => (
                <Link key={id} to="/runs/$id" params={{ id }} className="text-primary hover:underline">
                  {id}
                </Link>
              ))}
            </div>
          ) : null}
        </Card>
      ) : null}
    </div>
  );
}
