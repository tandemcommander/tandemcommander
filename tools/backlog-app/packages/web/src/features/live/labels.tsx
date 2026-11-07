// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Labels and icons of the run story (feature 415): a label is short text in a monospace
 * font on a background of its colour with rounded ends, an icon per kind of step, and the
 * outcome of a step in colour. Colours come only from the app's theme tokens, so both themes
 * keep the contrast of the rest of the app.
 */

import {
  BotIcon,
  CircleAlertIcon,
  CircleCheckIcon,
  CircleXIcon,
  FileTextIcon,
  FlagIcon,
  FlaskConicalIcon,
  GaugeIcon,
  GitBranchIcon,
  GitCommitHorizontalIcon,
  GlobeIcon,
  HammerIcon,
  ImageIcon,
  InfoIcon,
  LanguagesIcon,
  LightbulbIcon,
  ListChecksIcon,
  ListTodoIcon,
  LoaderIcon,
  MessageSquareTextIcon,
  MonitorIcon,
  OctagonXIcon,
  PencilLineIcon,
  RotateCwIcon,
  ScanSearchIcon,
  SearchIcon,
  ShieldCheckIcon,
  SparklesIcon,
  TerminalIcon,
  TriangleAlertIcon,
  type LucideIcon,
} from "lucide-react";
import type { StoryLabel, StoryOutcome } from "@backlog-app/shared";
import { cn } from "@/lib/utils.ts";

/** The colour tone of a label (a theme token). */
type Tone = "primary" | "purple" | "orange" | "teal" | "ok" | "info" | "yellow" | "muted" | "warn" | "bad";

/** Classes of each tone: tinted background, coloured text and border. */
const TONE: Readonly<Record<Tone, string>> = {
  primary: "border-primary/35 bg-primary/12 text-primary",
  purple: "border-status-new/35 bg-status-new/12 text-status-new",
  orange: "border-sev-high/35 bg-sev-high/12 text-sev-high",
  teal: "border-status-in-progress/35 bg-status-in-progress/12 text-status-in-progress",
  ok: "border-ok/35 bg-ok/12 text-ok",
  info: "border-info/35 bg-info/12 text-info",
  yellow: "border-sev-medium/35 bg-sev-medium/12 text-sev-medium",
  muted: "border-border bg-muted text-muted-foreground",
  warn: "border-warn/40 bg-warn/14 text-warn",
  bad: "border-bad/40 bg-bad/12 text-bad",
};

/** Tone and icon of every label. */
export const LABELS: Readonly<Record<StoryLabel, { tone: Tone; icon: LucideIcon; text: string }>> = {
  PHASE: { tone: "primary", icon: FlagIcon, text: "phase" },
  "SPEC KIT": { tone: "purple", icon: SparklesIcon, text: "spec kit" },
  BUILD: { tone: "orange", icon: HammerIcon, text: "build" },
  TEST: { tone: "teal", icon: FlaskConicalIcon, text: "test" },
  PROBE: { tone: "purple", icon: MonitorIcon, text: "probe" },
  CHECK: { tone: "teal", icon: ShieldCheckIcon, text: "check" },
  COMMIT: { tone: "ok", icon: GitCommitHorizontalIcon, text: "commit" },
  GIT: { tone: "info", icon: GitBranchIcon, text: "git" },
  BACKLOG: { tone: "yellow", icon: ListTodoIcon, text: "backlog" },
  EDIT: { tone: "info", icon: PencilLineIcon, text: "edit" },
  READ: { tone: "muted", icon: FileTextIcon, text: "read" },
  SEARCH: { tone: "muted", icon: SearchIcon, text: "search" },
  SCREENSHOT: { tone: "purple", icon: ImageIcon, text: "screenshot" },
  AGENT: { tone: "primary", icon: BotIcon, text: "agent" },
  REVIEW: { tone: "orange", icon: ScanSearchIcon, text: "review" },
  SHELL: { tone: "muted", icon: TerminalIcon, text: "shell" },
  PLAN: { tone: "muted", icon: ListChecksIcon, text: "to-do" },
  TRANSLATE: { tone: "info", icon: LanguagesIcon, text: "translate" },
  WEB: { tone: "info", icon: GlobeIcon, text: "web" },
  DECISION: { tone: "warn", icon: LightbulbIcon, text: "decision" },
  MESSAGE: { tone: "primary", icon: MessageSquareTextIcon, text: "agent says" },
  LIMIT: { tone: "warn", icon: GaugeIcon, text: "limit" },
  RESTART: { tone: "warn", icon: RotateCwIcon, text: "restart" },
  STOP: { tone: "bad", icon: OctagonXIcon, text: "stop" },
  ERROR: { tone: "bad", icon: CircleAlertIcon, text: "error" },
  INFO: { tone: "muted", icon: InfoIcon, text: "info" },
};

/**
 * A label: a rounded pill in the label's colour.
 *
 * @param props - The label and extra classes.
 * @returns The element.
 */
export function StoryLabelPill({
  label,
  className,
}: {
  /** The label. */ label: StoryLabel;
  /** Extra classes. */ className?: string;
}) {
  const style = LABELS[label];
  return (
    <span
      className={cn(
        "inline-flex shrink-0 items-center rounded-full border px-1.5 py-px font-mono text-[10px] leading-4 font-semibold tracking-wide whitespace-nowrap uppercase",
        TONE[style.tone],
        className,
      )}
    >
      {style.text}
    </span>
  );
}

/**
 * The icon of a label, in its colour.
 *
 * @param props - The label and extra classes.
 * @returns The element.
 */
export function StoryIcon({
  label,
  className,
}: {
  /** The label. */ label: StoryLabel;
  /** Extra classes. */ className?: string;
}) {
  const style = LABELS[label];
  const Icon = style.icon;
  return (
    <span
      className={cn(
        "inline-flex size-6 shrink-0 items-center justify-center rounded-full border",
        TONE[style.tone],
        className,
      )}
      aria-hidden
    >
      <Icon className="size-3.5" />
    </span>
  );
}

/** Words and look of each outcome. */
const OUTCOMES: Readonly<
  Record<Exclude<StoryOutcome, "info">, { text: string; icon: LucideIcon; className: string }>
> = {
  running: { text: "running", icon: LoaderIcon, className: "text-primary" },
  ok: { text: "done", icon: CircleCheckIcon, className: "text-ok" },
  fail: { text: "failed", icon: CircleXIcon, className: "text-bad" },
  warn: { text: "warning", icon: TriangleAlertIcon, className: "text-warn" },
};

/**
 * The outcome of a step: an icon and a word in its colour (nothing for plain information).
 *
 * @param props - The outcome and whether to show the word.
 * @returns The element, or null.
 */
export function OutcomeMark({
  outcome,
  withText = false,
}: {
  /** The outcome. */ outcome: StoryOutcome;
  /** Show the word too. */ withText?: boolean;
}) {
  if (outcome === "info") return null;
  const look = OUTCOMES[outcome];
  const Icon = look.icon;
  return (
    <span className={cn("inline-flex shrink-0 items-center gap-1 text-xs font-medium", look.className)}>
      <Icon
        className={cn("size-3.5", outcome === "running" && "animate-spin motion-reduce:animate-none")}
        aria-hidden
      />
      {withText ? look.text : <span className="sr-only">{look.text}</span>}
    </span>
  );
}

/**
 * A sentence of the story with its marks: `code` in a monospace chip, *emphasis* in italics.
 *
 * @param props - The text.
 * @returns The element.
 */
export function StoryText({ text }: { /** The sentence. */ text: string }) {
  const parts = text.split(/(`[^`]+`|\*[^*]+\*)/g).filter(Boolean);
  return (
    <>
      {parts.map((part, i) =>
        part.startsWith("`") && part.endsWith("`") && part.length > 2 ? (
          <code key={i} className="rounded bg-muted px-1 py-px font-mono text-[0.85em]">
            {part.slice(1, -1)}
          </code>
        ) : part.startsWith("*") && part.endsWith("*") && part.length > 2 ? (
          <em key={i}>{part.slice(1, -1)}</em>
        ) : (
          <span key={i}>{part}</span>
        ),
      )}
    </>
  );
}
