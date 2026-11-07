// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Diagrams of the solution being built (feature 415, FR-009): the flow of the run (the
 * phases of the implementation as a chain, each in its state), a map of where the change happens
 * (the components of the files the run changed around the feature, sized by how often they were
 * edited, with the files listed per component), and the diagrams the feature's `plan.md` draws.
 * Inline SVG in the theme's colours - no diagram library.
 */

import { useMemo } from "react";
import { PHASE_ORDER, PHASE_TITLES, type Phase, type StoryFile } from "@backlog-app/shared";
import { cn } from "@/lib/utils.ts";

/** Short names of the phases for the flow. */
const FLOW_NAMES: Readonly<Partial<Record<Phase, string>>> = {
  selection: "Select item",
  measure: "Measure",
  specify: "Specify",
  clarify: "Clarify",
  plan: "Plan",
  tasks: "Tasks",
  analyze: "Analyze",
  implement: "Implement",
  verify: "Verify",
  review: "Review",
  close: "Close",
  merge: "Merge",
};

/**
 * The flow of the run: phases in two rows, in their state.
 *
 * @param props - The current phase and the phases reached.
 * @returns The element.
 */
export function FlowDiagram({
  phase,
  reached,
  live,
}: {
  /** The current phase. */ phase: Phase;
  /** Phases seen. */ reached: ReadonlySet<Phase>;
  /** The run is live. */ live: boolean;
}) {
  const phases = PHASE_ORDER.filter((p) => FLOW_NAMES[p]);
  const perRow = 6;
  const w = 150;
  const h = 46;
  const gapX = 40;
  const gapY = 56;
  const width = perRow * w + (perRow - 1) * gapX + 20;
  const height = 2 * h + gapY + 20;
  const index = PHASE_ORDER.indexOf(phase);
  /**
   * The box of a phase (second row runs right to left, a snake).
   *
   * @param i - Index in the flow.
   * @returns Its position.
   */
  const box = (i: number): { x: number; y: number } => {
    const row = Math.floor(i / perRow);
    const col = row === 0 ? i % perRow : perRow - 1 - (i % perRow);
    return { x: 10 + col * (w + gapX), y: 10 + row * (h + gapY) };
  };
  return (
    <figure className="flex flex-col gap-1">
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className="w-full max-w-5xl"
        role="img"
        aria-label={`The flow of the run; now: ${PHASE_TITLES[phase]}`}
      >
        <defs>
          <marker
            id="flow-arrow"
            viewBox="0 0 10 10"
            refX="9"
            refY="5"
            markerWidth="7"
            markerHeight="7"
            orient="auto-start-reverse"
          >
            <path d="M0,0 L10,5 L0,10 z" className="fill-muted-foreground" />
          </marker>
        </defs>
        {phases.slice(0, -1).map((p, i) => {
          const a = box(i);
          const b = box(i + 1);
          const sameRow = a.y === b.y;
          const d = sameRow
            ? a.x < b.x
              ? `M${a.x + w},${a.y + h / 2} L${b.x - 2},${b.y + h / 2}`
              : `M${a.x},${a.y + h / 2} L${b.x + w + 2},${b.y + h / 2}`
            : `M${a.x + w / 2},${a.y + h} L${b.x + w / 2},${b.y - 2}`;
          return (
            <path
              key={p}
              d={d}
              className="stroke-muted-foreground"
              strokeWidth={1.5}
              fill="none"
              markerEnd="url(#flow-arrow)"
            />
          );
        })}
        {phases.map((p, i) => {
          const { x, y } = box(i);
          const active = p === phase;
          const done = !active && (reached.has(p) || (phase !== "stopped" && PHASE_ORDER.indexOf(p) < index));
          return (
            <g key={p}>
              <rect
                x={x}
                y={y}
                width={w}
                height={h}
                rx={10}
                strokeWidth={active ? 2.5 : 1.2}
                className={cn(
                  active
                    ? "fill-primary/15 stroke-primary"
                    : done
                      ? "fill-ok/12 stroke-ok"
                      : "fill-muted stroke-border",
                  active && live && "animate-pulse motion-reduce:animate-none",
                )}
                strokeDasharray={!active && !done ? "5 4" : undefined}
              />
              <text
                x={x + w / 2}
                y={y + h / 2 + 5}
                textAnchor="middle"
                className={cn(
                  "text-[15px] font-semibold",
                  active ? "fill-primary" : done ? "fill-ok" : "fill-muted-foreground",
                )}
              >
                {done ? "✓ " : ""}
                {FLOW_NAMES[p]}
              </text>
            </g>
          );
        })}
      </svg>
      <figcaption className="text-xs text-muted-foreground">
        Green: done · blue: now · dashed: still ahead
        {phase === "stopped" ? " · the run stopped and blocked the item" : ""}.
      </figcaption>
    </figure>
  );
}

/** A component of the change and its files. */
interface Component {
  /** Its name. */
  name: string;
  /** Its files. */
  files: StoryFile[];
  /** All edits of its files. */
  edits: number;
}

/** Colours of components on the map (theme tokens, cycled). */
const COMPONENT_TONES = [
  "fill-primary/18 stroke-primary",
  "fill-status-new/18 stroke-status-new",
  "fill-sev-high/18 stroke-sev-high",
  "fill-status-in-progress/18 stroke-status-in-progress",
  "fill-info/18 stroke-info",
  "fill-sev-medium/18 stroke-sev-medium",
  "fill-ok/18 stroke-ok",
];

/** Text colours matching {@link COMPONENT_TONES}. */
const COMPONENT_TEXT = [
  "text-primary",
  "text-status-new",
  "text-sev-high",
  "text-status-in-progress",
  "text-info",
  "text-sev-medium",
  "text-ok",
];

/**
 * The map of where the change happens.
 *
 * @param props - The files changed and the feature's name.
 * @returns The element.
 */
export function ChangeMap({
  files,
  center,
}: {
  /** Files changed. */ files: StoryFile[];
  /** The centre's label. */ center: string;
}) {
  const components = useMemo(() => {
    const map = new Map<string, Component>();
    for (const f of files) {
      const c = map.get(f.component) ?? { name: f.component, files: [], edits: 0 };
      c.files.push(f);
      c.edits += f.edits;
      map.set(f.component, c);
    }
    return [...map.values()].sort((a, b) => b.edits - a.edits);
  }, [files]);
  if (components.length === 0) {
    return (
      <p className="text-sm text-muted-foreground">
        No file changed yet - the map grows as the run edits files.
      </p>
    );
  }
  const shown = components.slice(0, 10);
  const size = 520;
  const cx = size / 2;
  const cy = size / 2;
  const ring = 185;
  const most = Math.max(...shown.map((c) => c.edits));
  return (
    <div className="grid gap-4 xl:grid-cols-[minmax(0,520px)_minmax(0,1fr)]">
      <svg
        viewBox={`0 0 ${size} ${size}`}
        className="w-full max-w-[520px]"
        role="img"
        aria-label="Where the change happens"
      >
        {shown.map((c, i) => {
          const angle = (2 * Math.PI * i) / shown.length - Math.PI / 2;
          const x = cx + ring * Math.cos(angle);
          const y = cy + ring * Math.sin(angle);
          return (
            <line
              key={`l-${c.name}`}
              x1={cx}
              y1={cy}
              x2={x}
              y2={y}
              className="stroke-border"
              strokeWidth={1 + (4 * c.edits) / most}
            />
          );
        })}
        <circle cx={cx} cy={cy} r={56} className="fill-card stroke-primary" strokeWidth={2} />
        <text x={cx} y={cy - 4} textAnchor="middle" className="fill-foreground text-[14px] font-semibold">
          {center}
        </text>
        <text x={cx} y={cy + 14} textAnchor="middle" className="fill-muted-foreground text-[11px]">
          {files.length} files
        </text>
        {shown.map((c, i) => {
          const angle = (2 * Math.PI * i) / shown.length - Math.PI / 2;
          const x = cx + ring * Math.cos(angle);
          const y = cy + ring * Math.sin(angle);
          const r = 22 + 22 * Math.sqrt(c.edits / most);
          return (
            <g key={c.name}>
              <circle cx={x} cy={y} r={r} className="fill-card" />
              <circle
                cx={x}
                cy={y}
                r={r}
                strokeWidth={1.5}
                className={COMPONENT_TONES[i % COMPONENT_TONES.length]}
              />
              <text x={x} y={y - 2} textAnchor="middle" className="fill-foreground text-[11px] font-semibold">
                {c.name.length > 22 ? `${c.name.slice(0, 21)}…` : c.name}
              </text>
              <text x={x} y={y + 12} textAnchor="middle" className="fill-muted-foreground text-[10px]">
                {c.files.length} files · {c.edits} edits
              </text>
            </g>
          );
        })}
      </svg>
      <ul className="flex flex-col gap-2" aria-label="Files by component">
        {components.map((c, i) => (
          <li key={c.name} className="rounded-lg border bg-card p-2">
            <p className={cn("text-sm font-semibold", COMPONENT_TEXT[i % COMPONENT_TEXT.length])}>
              {c.name} <span className="text-xs font-normal text-muted-foreground">· {c.edits} edits</span>
            </p>
            <div className="mt-1 flex flex-wrap gap-1">
              {c.files.map((f) => (
                <span
                  key={f.path}
                  title={f.rel}
                  className="rounded border bg-muted/50 px-1.5 py-px font-mono text-[11px]"
                  style={{ fontWeight: f.edits >= 5 ? 700 : f.edits >= 2 ? 600 : 400 }}
                >
                  {f.rel.split("/").pop()}
                  {f.edits > 1 ? <span className="text-muted-foreground"> ×{f.edits}</span> : null}
                </span>
              ))}
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}

/**
 * The Architecture tab.
 *
 * @param props - Phase, reached phases, files, plan diagrams, and labels.
 * @returns The element.
 */
export function ArchitectureView({
  phase,
  reached,
  live,
  files,
  diagrams,
  center,
  kind,
}: {
  /** The current phase. */ phase: Phase;
  /** Phases seen. */ reached: ReadonlySet<Phase>;
  /** The run is live. */ live: boolean;
  /** Files changed. */ files: StoryFile[];
  /** Diagrams of `plan.md`. */ diagrams: { title: string; text: string }[];
  /** The centre of the change map. */ center: string;
  /** The run kind. */ kind: "item" | "triage";
}) {
  return (
    <div className="flex flex-col gap-6">
      {kind === "item" ? (
        <section aria-label="The flow of the run" className="flex flex-col gap-2">
          <h3 className="text-sm font-semibold">How the run proceeds</h3>
          <FlowDiagram phase={phase} reached={reached} live={live} />
        </section>
      ) : null}
      <section aria-label="Where the change happens" className="flex flex-col gap-2">
        <h3 className="text-sm font-semibold">Where the change happens</h3>
        <ChangeMap files={files} center={center} />
      </section>
      <section aria-label="Diagrams of the plan" className="flex flex-col gap-2">
        <h3 className="text-sm font-semibold">The design in the plan</h3>
        {diagrams.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            The feature's plan.md draws no diagram (yet). It is written in the plan phase.
          </p>
        ) : (
          diagrams.map((d, i) => (
            <figure key={i} className="rounded-lg border bg-card">
              <figcaption className="border-b px-3 py-1.5 text-xs font-semibold text-muted-foreground">
                {d.title}
              </figcaption>
              <pre className="overflow-x-auto p-3 font-mono text-xs leading-snug">{d.text}</pre>
            </figure>
          ))
        )}
      </section>
    </div>
  );
}
