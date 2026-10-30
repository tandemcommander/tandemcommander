// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The new-item form (FR-031; analysis A4 §3.7): every field of the item format, the body
 * sections its type needs, an optional placement, and an AI draft from a sentence in any language
 * (recorded in English, applied to the form only - nothing is written before *Create*). All text
 * is kept as a local draft while typing and travels to the tool on stdin, byte-exact.
 */

import { getRouteApi, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { ORDERED_SECTIONS, type SectionName } from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import { Card, Input, Label, NativeSelect, Textarea } from "@/components/ui/primitives.tsx";
import { ChangeProblemBox } from "@/components/change-problem.tsx";
import { useChange } from "@/lib/changes.ts";
import { useDraft } from "@/lib/drafts.ts";
import { useBoard, useLegend } from "@/lib/queries.ts";
import { useWriteAccess } from "@/features/gate/gate-banner.tsx";
import { JobCard, useAiJob } from "@/features/ai/ai-job.tsx";

/** The route. */
const route = getRouteApi("/new");

/** The body sections per type (the item format's required sections, analysis A1 §2.2). */
const SECTIONS_OF: Record<string, string[]> = {
  decision: ["problem", "evidence", "expected", "question", "options", "recommendation"],
  "person-step": ["problem", "evidence", "expected", "steps"],
};

/** Hints of the body fields. */
const HINT: Record<string, string> = {
  problem: "What is wrong or missing, as the user sees it.",
  evidence: "How it was seen: commands, files, lines, measurements.",
  expected: "What should happen instead.",
  question: "The question the maintainer decides.",
  options: "- **A** ...\n- **B** ...",
  recommendation: "Which option and why.",
  steps: "- [ ] the first step a person does\n- [ ] ...",
  approach: "How it could be done (optional).",
  notes: "Anything else (optional).",
};

/** A draft proposal of the AI. */
interface DraftProposal {
  /** Title. */
  title?: string;
  /** Type. */
  type?: string;
  /** Severity. */
  severity?: number;
  /** Area. */
  area?: string;
  /** Who. */
  who?: string;
  /** Effort. */
  effort?: string;
  /** Problem. */
  problem?: string;
  /** Evidence. */
  evidence?: string;
  /** Expected. */
  expected?: string;
}

/**
 * The new-item page.
 *
 * @returns The element.
 */
export function NewItemPage() {
  const { type: typeParam, from } = route.useSearch();
  const navigate = useNavigate();
  const legend = useLegend();
  const board = useBoard("");
  const access = useWriteAccess();
  const ai = useAiJob();
  const [sentence, setSentence] = useDraft("new:sentence", "");
  const [title, setTitle] = useDraft("new:title", "");
  const [type, setType] = useState(typeParam || "bug");
  const [severity, setSeverity] = useState("4");
  const [area, setArea] = useState("");
  const [who, setWho] = useState("agent");
  const [effort, setEffort] = useState("?");
  const [related, setRelated] = useState(from ?? "");
  const [texts, setTexts] = useState<Record<string, string>>({});
  const [placeIn, setPlaceIn] = useState<SectionName | "">("");
  const [position, setPosition] = useState("");
  // The page stays mounted when only its address changes (`/new?from=a` -> `/new`, the "New item"
  // button): take over the new prefill instead of keeping the previous one (review).
  const [prefillOf, setPrefillOf] = useState(`${typeParam}|${from}`);
  if (prefillOf !== `${typeParam}|${from}`) {
    setPrefillOf(`${typeParam}|${from}`);
    setType(typeParam || "bug");
    setRelated(from ?? "");
  }
  const { mutation, problem } = useChange((result) => {
    // The draft is no longer needed once the item exists.
    setTitle("");
    setSentence("");
    const slug = result.change?.slugs[0];
    if (slug) void navigate({ to: "/items/$slug", params: { slug }, search: { tab: "" } });
  });
  const [draftJob, setDraftJob] = useState<string | null>(null);
  // Without a choice yet, the area is the legend's first one.
  if (!area && legend.data?.areas[0]) setArea(legend.data.areas[0].value);
  // Adopt a finished AI draft into the form once (the maintainer reviews and edits it before
  // Create); adjusted during render, keyed by the job.
  if (ai.job?.state === "done" && ai.job.proposal && ai.job.id !== draftJob) {
    setDraftJob(ai.job.id);
    const p = ai.job.proposal as DraftProposal;
    if (p.title) setTitle(p.title);
    if (p.type) setType(p.type);
    if (typeof p.severity === "number") setSeverity(String(p.severity));
    if (p.area) setArea(p.area);
    if (p.who) setWho(p.who);
    if (p.effort) setEffort(p.effort);
    setTexts((t) => ({
      ...t,
      ...(p.problem ? { problem: p.problem } : {}),
      ...(p.evidence ? { evidence: p.evidence } : {}),
      ...(p.expected ? { expected: p.expected } : {}),
    }));
  }
  const sections = [...(SECTIONS_OF[type] ?? ["problem", "evidence", "expected"]), "approach", "notes"];
  return (
    <div className="mx-auto flex w-full max-w-4xl flex-col gap-4 p-4">
      <h1 className="text-lg font-semibold">New item</h1>
      <Card className="flex flex-col gap-2 p-3">
        <Label htmlFor="sentence">
          Draft with AI from a sentence (Czech or English; the item is written in English)
        </Label>
        <div className="flex gap-2">
          <Input
            id="sentence"
            value={sentence}
            onChange={(e) => setSentence(e.target.value)}
            placeholder="e.g. Při kopírování do archivu se ztrácí…"
          />
          <Button
            variant="secondary"
            disabled={!sentence.trim() || ai.starting || ai.job?.state === "running"}
            onClick={() => ai.start("draft-item", { text: sentence.trim() })}
          >
            Draft
          </Button>
        </div>
        {ai.job ? <JobCard job={ai.job} onCancel={ai.cancel} /> : null}
      </Card>
      <form
        className="flex flex-col gap-3"
        onSubmit={(e) => {
          e.preventDefault();
          const body: Record<string, unknown> = {
            base: { board: board.data?.revision },
            title: title.trim(),
            type,
            severity: Number(severity),
            area,
            who,
            effort,
          };
          const relatedSlugs = related.split(/[\s,]+/).filter(Boolean);
          if (relatedSlugs.length) body["related"] = relatedSlugs;
          for (const key of sections) if (texts[key]?.trim()) body[key] = texts[key];
          if (placeIn)
            body["place"] = { section: placeIn, ...(position ? { position: Number(position) } : {}) };
          mutation.mutate({ path: "/api/items", body });
        }}
      >
        <div>
          <Label htmlFor="title">Title (one line)</Label>
          <Input
            id="title"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            required
            maxLength={200}
          />
        </div>
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-5">
          <div>
            <Label htmlFor="type">Type</Label>
            <NativeSelect id="type" value={type} onChange={(e) => setType(e.target.value)}>
              {(legend.data?.types ?? []).map((t) => (
                <option key={t.value}>{t.value}</option>
              ))}
            </NativeSelect>
          </div>
          <div>
            <Label htmlFor="severity">Severity</Label>
            <Input
              id="severity"
              type="number"
              min={0}
              max={10}
              value={severity}
              onChange={(e) => setSeverity(e.target.value)}
            />
          </div>
          <div>
            <Label htmlFor="area">Area</Label>
            <NativeSelect id="area" value={area} onChange={(e) => setArea(e.target.value)}>
              {(legend.data?.areas ?? []).map((a) => (
                <option key={a.value} title={a.meaning}>
                  {a.value}
                </option>
              ))}
            </NativeSelect>
          </div>
          <div>
            <Label htmlFor="who">Who</Label>
            <NativeSelect id="who" value={who} onChange={(e) => setWho(e.target.value)}>
              {(legend.data?.who ?? []).map((w) => (
                <option key={w.value}>{w.value}</option>
              ))}
            </NativeSelect>
          </div>
          <div>
            <Label htmlFor="effort">Effort</Label>
            <NativeSelect id="effort" value={effort} onChange={(e) => setEffort(e.target.value)}>
              {(legend.data?.efforts ?? []).map((v) => (
                <option key={v.value}>{v.value}</option>
              ))}
            </NativeSelect>
          </div>
        </div>
        <div>
          <Label htmlFor="related">Related items (slugs)</Label>
          <Input id="related" value={related} onChange={(e) => setRelated(e.target.value)} />
        </div>
        {sections.map((key) => (
          <div key={key}>
            <Label htmlFor={`text-${key}`}>{key[0]!.toUpperCase() + key.slice(1)}</Label>
            <Textarea
              id={`text-${key}`}
              rows={key === "problem" || key === "evidence" ? 5 : 3}
              value={texts[key] ?? ""}
              placeholder={HINT[key]}
              onChange={(e) => setTexts((t) => ({ ...t, [key]: e.target.value }))}
            />
          </div>
        ))}
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
          <div>
            <Label htmlFor="place">Place it</Label>
            <NativeSelect
              id="place"
              value={placeIn}
              onChange={(e) => setPlaceIn(e.target.value as SectionName | "")}
            >
              <option value="">in the Inbox (triage later)</option>
              {ORDERED_SECTIONS.filter((s) => s !== "In progress").map((s) => (
                <option key={s}>{s}</option>
              ))}
            </NativeSelect>
          </div>
          {placeIn ? (
            <div>
              <Label htmlFor="position">Position</Label>
              <Input
                id="position"
                type="number"
                min={1}
                value={position}
                placeholder="end"
                onChange={(e) => setPosition(e.target.value)}
              />
            </div>
          ) : null}
        </div>
        <ChangeProblemBox problem={problem} />
        <div className="flex justify-end gap-2">
          <Button
            type="submit"
            disabled={!access.writable || mutation.isPending || !title.trim()}
            title={access.writable ? "" : access.reason}
          >
            {mutation.isPending ? "Creating…" : "Create"}
          </Button>
        </div>
      </form>
    </div>
  );
}
