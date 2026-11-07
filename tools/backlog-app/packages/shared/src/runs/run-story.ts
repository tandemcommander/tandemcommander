// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The story of a run (feature 415, `specs/415-live-run-dashboard/contracts/story-rules.md`):
 * the normalised trace events told in human sentences - grouped by phase, each with a label, an
 * outcome and an importance; routine reads and edits collapsed into one line; a subagent's work
 * folded under its agent; the agent's own messages kept as Markdown. Critical entries (failed
 * builds and tests, a stop, usage limits, review findings, new backlog items, person steps) and
 * decisions are flagged for their own tabs. The rules read only what the run did, never invent: a
 * call without a description of its own gets a plain sentence from its kind.
 *
 * Entries are replaced, never mutated, when they change (a result arrives, a group grows), so a
 * view can compare them by identity; {@link RunStory.view} hands out a fresh array.
 */

import type { Phase, TraceEvent } from "../schemas/runs.ts";
import { checkSubjects, programsOf } from "./command-parse.ts";
import { isSourcePath, RunState, safeParse } from "./run-state.ts";

/** Labels of story entries (rendered as coloured pills). */
export type StoryLabel =
  | "PHASE"
  | "SPEC KIT"
  | "BUILD"
  | "TEST"
  | "PROBE"
  | "CHECK"
  | "COMMIT"
  | "GIT"
  | "BACKLOG"
  | "EDIT"
  | "READ"
  | "SEARCH"
  | "SCREENSHOT"
  | "AGENT"
  | "REVIEW"
  | "SHELL"
  | "PLAN"
  | "TRANSLATE"
  | "WEB"
  | "DECISION"
  | "MESSAGE"
  | "LIMIT"
  | "RESTART"
  | "STOP"
  | "ERROR"
  | "INFO";

/** Outcome of an entry. */
export type StoryOutcome = "running" | "ok" | "fail" | "warn" | "info";

/** Importance of an entry. */
export type StoryImportance = "critical" | "high" | "normal" | "low";

/** Kind of an entry. */
export type StoryKind =
  | "phase"
  | "action"
  | "group"
  | "agent"
  | "message"
  | "attempt"
  | "limit"
  | "turn"
  | "session"
  | "unreadable";

/** One line under a group or an agent. */
export interface StoryChild {
  /** When (ISO), if known. */
  at: string | null;
  /** The label. */
  label: StoryLabel;
  /** The sentence. */
  title: string;
  /** The outcome. */
  outcome: StoryOutcome;
  /** The tool call, if it is one. */
  toolUseId: string | null;
}

/** One human line of the run. */
export interface StoryEntry {
  /** Stable id: the event's offset and its number within the line. */
  id: string;
  /** When it began (ISO), if known. */
  at: string | null;
  /** When it ended (ISO), if known. */
  endedAt: string | null;
  /** The run phase when it began. */
  phase: Phase;
  /** The kind. */
  kind: StoryKind;
  /** The label. */
  label: StoryLabel;
  /** The sentence (plain text; backticks mark code). */
  title: string;
  /** More text shown when opened (Markdown for messages and agent reports), or null. */
  detail: string | null;
  /** The outcome. */
  outcome: StoryOutcome;
  /** How much it matters. */
  importance: StoryImportance;
  /** The tool call it stands for. */
  toolUseId: string | null;
  /** The tool's name, if it is a call. */
  tool: string | null;
  /** Lines of a group or a subagent (at most {@link MAX_CHILDREN}). */
  children: StoryChild[];
  /** All lines, also those beyond the cap. */
  childCount: number;
  /** The latest status of an agent or a background command. */
  status: string | null;
  /** The image a SCREENSHOT entry shows. */
  image: string | null;
  /** Why it is critical, when it is. */
  critical: string | null;
  /** A critical failure a later run of the same kind passed (a build that built later). */
  resolved: boolean;
  /** True when it states a decision. */
  decision: boolean;
}

/** A file the run changed. */
export interface StoryFile {
  /** The path as the trace names it. */
  path: string;
  /** The path relative to the repository (best effort). */
  rel: string;
  /** The component (`backlog-app/web`, `plugins/ftp`, ...). */
  component: string;
  /** How often it was changed. */
  edits: number;
}

/** The current activity. */
export interface StoryNow {
  /** The sentence. */
  title: string;
  /** The label. */
  label: StoryLabel;
  /** Since when (ISO), if known. */
  since: string | null;
  /** True while a call is in flight. */
  running: boolean;
}

/** Most entries kept (older routine entries are dropped first). */
const MAX_ENTRIES = 6000;

/** Most lines kept under one group or agent. */
export const MAX_CHILDREN = 200;

/** Human names of the phases. */
export const PHASE_TITLES: Readonly<Record<Phase, string>> = {
  starting: "Starting the run",
  selection: "Choosing and locking the item",
  measure: "Measuring the problem on the current code",
  specify: "Writing the specification",
  clarify: "Settling the open questions",
  plan: "Designing the solution",
  tasks: "Breaking the work into tasks",
  analyze: "Checking spec, plan and tasks for gaps",
  implement: "Implementing",
  verify: "Verifying: builds, tests and probes",
  review: "Independent review",
  close: "Closing the item and writing the records",
  merge: "Merging into main",
  done: "Finished",
  stopped: "Stopped - the item is blocked",
  triage: "Triaging the Inbox",
};

/** Image file extensions. */
const IMAGE = /\.(png|jpe?g|gif|bmp|webp)$/i;

/** Tools that read or search. */
const READ_TOOLS = new Set(["Read", "Grep", "Glob", "LS", "LSP", "NotebookRead"]);

/** Tools that change files. */
const EDIT_TOOLS = new Set(["Edit", "Write", "MultiEdit", "NotebookEdit"]);

/** Words of a message that states a decision. */
const DECISION_WORDS =
  /\b(decid(e|ed|ing)|chose|chosen|choose|going with|i will|i'll|instead of|conservative|recommended option|autonomous run:)|→ A:/i;

/** Phases in which an agent message may report review findings. */
const AFTER_IMPLEMENT = new Set<Phase>(["implement", "verify", "review", "close"]);

/** A count of MUST findings in words or digits ("1 MUST", "one MUST", "2 MUST findings"). */
const MUST_COUNT = /\b([1-9]\d*|one|two|three|four|five)\s+MUST\b/i;

/**
 * Whether a message reports open MUST findings of a review: a count above zero ("Review 3 has 1
 * MUST", "found one MUST"), never "no MUST", "0 MUST" or "the MUST is fixed".
 *
 * @param text - The message.
 * @returns True for a reported finding.
 */
export function mustFinding(text: string): boolean {
  return MUST_COUNT.test(text);
}

/** A review without a MUST finding, or a MUST reported fixed. */
const MUST_CLEARED =
  /\b(?:found|has|had|have|reports?|with|shows?|brings?|gave|gives)\s+(?:no|0|zero)\s+MUST\b|^\W*(?:review \d+\W+)?(?:no|0)\s+MUST\b|\bthe MUST(?: finding)?(?: of review \d+)? (?:is|was) (?:now )?fixed\b|\breview \d+'s MUST (?:is|was) (?:now )?fixed\b/im;

/** Words that keep a MUST open although a message mentions it fixed or none. */
const MUST_STILL_OPEN =
  /still open|stays open|remains? open|brings? it back|reopen|next:? the MUST|not (?:yet )?fixed|\bbut\b[^.\n]{0,40}\bMUST\b/i;

/** A MUST reported and fixed in the same breath ("found one MUST, which is fixed"). */
const MUST_FIXED_AT_ONCE =
  /\b(?:which|that) (?:is|was|are|were) (?:now )?fixed\b|\bnow fixed\b|\bfixed it\b/i;

/** Labels whose failure a later pass of the same kind resolves. */
const RESOLVABLE = new Set<StoryLabel>(["BUILD", "TEST", "PROBE", "CHECK"]);

/** A call meant to fail: a negative control (its failure proves a test). */
const EXPECTED_FAILURE = new RegExp(
  [
    "negative control",
    "mutant",
    "mutation",
    "on purpose",
    "expected to fail",
    "should fail",
    "must fail",
    "fails? as expected",
    "before[- ]the[- ]fix",
    "before[- ]?probe",
    "\\bthe HEAD\\b",
    "before (?:the )?review fix",
    "mutated",
    "with control [A-Z]\\b",
    "with the [\\w -]{0,30}\\bbug\\b",
    "on the installed",
    "without the fix",
    "\\bpre-(?:fix|restore|change)\\b",
    "old (?:code|build|handler|binary)",
    "at HEAD",
    "unchanged build",
    "baseline",
    "reproduc",
    "with the [\\w -]{0,30}(?:removed|disabled|reverted|altered|broken|undone)",
    "\\b(?:altered|reverted|sabotaged)\\b",
  ].join("|"),
  "i",
);

/** Phases in which a failure is a measurement of the problem, not a problem of the run. */
const MEASURING = new Set<Phase>([
  "starting",
  "selection",
  "measure",
  "specify",
  "clarify",
  "plan",
  "tasks",
  "analyze",
]);

/** Top-level folders of the repository, to cut absolute paths to relative ones. */
const ROOT_FOLDERS = [
  "tools",
  "src",
  "specs",
  "backlog",
  "translations",
  "help",
  "setup",
  "architecture",
  "bin",
  "doc",
  ".claude",
  ".specify",
  ".agent-traces",
];

/**
 * A path relative to the repository: below the session's root when it is known, else cut before
 * the first known top-level folder; a temporary file as `%TEMP%`.
 *
 * @param path - A path as the trace names it.
 * @param root - The repository root (the session's working directory), when known.
 * @returns The shorter path, with forward slashes.
 */
export function relativePath(path: string, root: string | null = null): string {
  const p = path.replace(/\\/g, "/");
  // The repository root the session runs in (system/init's cwd), when known: exact.
  if (root) {
    const r = root.replace(/\\/g, "/").replace(/\/+$/, "");
    if (p.toLowerCase().startsWith(`${r.toLowerCase()}/`)) return p.slice(r.length + 1);
  }
  const temp = p.search(/\/AppData\/Local\/Temp\//i);
  // Otherwise the first known top-level folder (after the temporary folder, for a repository
  // that lives there); a temporary file without one is shown under %TEMP%.
  let best = -1;
  const from = temp >= 0 ? temp + "/AppData/Local/Temp/".length : 0;
  for (const folder of ROOT_FOLDERS) {
    const at = p.indexOf(`/${folder}/`, from);
    if (at >= 0 && (best < 0 || at < best)) best = at;
  }
  if (best >= 0) return p.slice(best + 1);
  if (temp >= 0) return `%TEMP%/${p.slice(temp + "/AppData/Local/Temp/".length)}`;
  if (/^(\.?[\w-]+\/)/.test(p) && !/^[A-Za-z]:/.test(p)) return p;
  const parts = p.split("/").filter(Boolean);
  return parts.slice(-3).join("/");
}

/**
 * The component a file belongs to (for the file map).
 *
 * @param rel - A relative path ({@link relativePath}).
 * @returns The component's name.
 */
export function componentOf(rel: string): string {
  const s = rel.split("/").filter(Boolean);
  if (s[0] === "%TEMP%") return "temporary files";
  if (s[0] === "tools" && s[1] === "backlog-app") {
    if (s[2] === "packages" && s[3]) return `backlog-app/${s[3]}`;
    return s.length > 3 ? `backlog-app/${s[2]}` : "backlog-app";
  }
  if (s[0] === "tools" && s[1] && s.length > 2) return `tools/${s[1]}`;
  if (s[0] === "src" && s[1] === "plugins" && s[2] && s.length > 3) return `plugins/${s[2]}`;
  if (s[0] === "src" && s[1] && s.length > 2) return `src/${s[1]}`;
  if (s[0] === "specs") return "feature records";
  if (s.length === 1) return "repository root";
  return s[0] ?? "other";
}

/**
 * The file name of a path.
 *
 * @param path - Any path.
 * @returns Its last part.
 */
function baseName(path: string): string {
  const parts = path.replace(/\\/g, "/").split("/");
  return parts[parts.length - 1] || path;
}

/**
 * Shortens a text to a sentence-sized title.
 *
 * @param text - Any text.
 * @param max - Most characters.
 * @returns The text on one line, cut with an ellipsis.
 */
function short(text: string, max = 160): string {
  const one = text.replace(/\s+/g, " ").trim();
  return one.length > max ? `${one.slice(0, max - 1)}…` : one;
}

/**
 * The first sentence of a message, without Markdown markers.
 *
 * @param text - The message.
 * @returns The sentence.
 */
export function firstSentence(text: string): string {
  const withoutCode = text.replace(/```[\s\S]*?```/g, " ");
  // A heading alone says little ("Extension Hooks"): the first line of prose after it, if any.
  const lines = withoutCode.split(/\n/).filter((l) => l.trim());
  const prose = lines.find((l) => !/^\s*#/.test(l) && !/^\s*\|/.test(l)) ?? lines[0] ?? "";
  const line = prose
    .replace(/^#+\s*/, "")
    .replace(/\*\*|__/g, "")
    .replace(/^\s*[-*]\s+/, "")
    .trim();
  const match = /^(.+?[.!?])(\s|$)/.exec(line.trim());
  return short(match ? match[1]! : line, 160);
}

/** How a shell command is told. */
interface CommandKind {
  /** The label. */
  label: StoryLabel;
  /** The sentence when the call has no description. */
  title: string;
  /** The verdict rule of its result. */
  verdict: "build" | "saltests" | "tests" | "probe" | "encoding" | "commit" | "backlog" | "plain";
  /** Importance when it succeeds. */
  importance: StoryImportance;
  /** Critical reason when it succeeds (a new backlog item, a block). */
  criticalOnOk: string | null;
}

/**
 * A quoted value after an option of a command line.
 *
 * @param command - The command line.
 * @param option - The option, e.g. `--title` or `-m`.
 * @returns The value, or null.
 */
function optionValue(command: string, option: string): string | null {
  const escaped = option.replace(/[-]/g, "\\-");
  const match = new RegExp(`${escaped}\\s+(?:'([^']*)'|"([^"]*)"|(\\S+))`).exec(command);
  if (!match) return null;
  return (match[1] ?? match[2] ?? match[3] ?? "").trim() || null;
}

/** Sentences of the backlog tool's commands. */
const BACKLOG_TITLES: Readonly<Record<string, string>> = {
  verify: "Records the measurement in the backlog",
  start: "Starts the item as a feature",
  "run-log": "Writes the run's row of the journal",
  remove: "Closes the item in the backlog",
  check: "Checks the backlog's consistency",
  next: "Asks the backlog for the next item",
  show: "Reads a backlog item",
  list: "Lists backlog items",
  move: "Moves a backlog item",
  log: "Adds a line to an item's log",
  set: "Changes an item's fields",
  body: "Rewrites a section of an item",
  step: "Ticks a step of an item",
  sync: "Rewrites the backlog overview",
  unblock: "Unblocks an item",
  decide: "Records a decision",
};

/**
 * Classifies a shell command (contracts/story-rules.md, *Main-thread tool calls*).
 *
 * @param command - The command line (the event's summary).
 * @returns How it is told.
 */
export function classifyCommand(command: string): CommandKind {
  const c = command;
  // What runs, not what the text mentions (review S-A of 415): a heredoc that writes "build.cmd"
  // into a fix-log, `grep msbuild` or `sed ... run-story.test.ts` run no build and no tests.
  const progs = programsOf(command);
  /**
   * Whether one of the programs runs.
   *
   * @param names - Program names (lower case).
   * @returns True when any runs.
   */
  const runs = (...names: string[]): boolean => names.some((n) => progs.includes(n));
  /**
   * A kind with defaults.
   *
   * @param label - The label.
   * @param title - The sentence.
   * @param verdict - The verdict rule.
   * @param more - Other fields.
   * @returns The kind.
   */
  const kind = (
    label: StoryLabel,
    title: string,
    verdict: CommandKind["verdict"],
    more: Partial<CommandKind> = {},
  ): CommandKind => ({ label, title, verdict, importance: "normal", criticalOnOk: null, ...more });
  if (runs("backlog.sh", "backlog.py")) {
    const sub = /\b(?:backlog\.sh|backlog\.py)\s+(?:--input-json\s+-\s+)?([a-z-]+)(?:\s+([a-z-]+))?/.exec(c);
    const verb = sub?.[1] ?? "";
    if (verb === "new") {
      const title = optionValue(c, "--title");
      const person = /--type\s+['"]?person-step/.test(c);
      return kind(
        "BACKLOG",
        `Adds ${person ? "a person step" : "an item"} to the backlog${title ? `: ${title}` : ""}`,
        "backlog",
        {
          importance: "high",
          criticalOnOk: person
            ? "A step owed to a person was recorded"
            : "A new item waits for the maintainer's triage",
        },
      );
    }
    if (verb === "block")
      return kind("STOP", "Stops and blocks the item", "backlog", {
        importance: "critical",
        criticalOnOk: "The run stopped and blocked the item",
      });
    if (verb === "lock") {
      const what = sub?.[2] ?? "";
      const titles: Record<string, string> = {
        acquire: "Takes the run lock",
        release: "Releases the run lock",
        update: "Updates the run lock",
        status: "Checks the run lock",
      };
      return kind("BACKLOG", titles[what] ?? "Uses the run lock", "backlog", {
        importance: what === "acquire" || what === "release" ? "normal" : "low",
      });
    }
    const title = BACKLOG_TITLES[verb] ?? "Uses the backlog tool";
    return kind("BACKLOG", title, "backlog", {
      importance: verb === "remove" || verb === "start" ? "high" : "normal",
    });
  }
  if (runs("backlog-loop.sh", "loop.py")) return kind("BACKLOG", "Talks to the backlog loop", "plain");
  if (runs("build.cmd", "rebuild.cmd", "build_langs.cmd", "msbuild", "msbuild.exe"))
    return kind("BUILD", "Builds the program", "build", { importance: "high" });
  // saltests counts only when its program runs (a path to saltests.cpp in a grep is a search).
  if (runs("saltests.exe")) return kind("TEST", "Runs the unit rules (saltests)", "saltests");
  if (runs("run_on_hidden_desktop.ps1"))
    return kind("PROBE", "Runs a GUI probe on the hidden desktop", "probe");
  if (runs("check_encoding.py")) return kind("CHECK", "Runs the encoding guard", "encoding");
  if (
    runs(
      "npm check",
      "npm test",
      "npm test:e2e",
      "npm typecheck",
      "npm lint",
      "npx vitest",
      "npx playwright",
      "npx tsc",
      "npx eslint",
      "vitest",
      "playwright",
      "pytest",
      "-m unittest",
      "-m pytest",
    ) ||
    progs.some((p) => /^test_[\w-]+\.py$/.test(p))
  )
    return kind("TEST", "Runs the tests", "tests");
  if (runs("-m translate.merge", "-m translate.slt"))
    return kind("TRANSLATE", "Refreshes the translations", "plain");
  if (runs("git commit")) {
    const message = optionValue(c, "-m");
    return kind("COMMIT", message ? `Commits: ${message}` : "Commits the changes", "commit");
  }
  const git = [
    "merge",
    "checkout",
    "switch",
    "branch",
    "rebase",
    "worktree",
    "stash",
    "tag",
    "reset",
    "restore",
  ].find((sub) => runs(`git ${sub}`));
  if (git) return kind("GIT", `Git: ${git}`, "plain");
  return kind("SHELL", `Runs \`${short(c, 80)}\``, "plain");
}

/**
 * The verdict of a command's result.
 *
 * @param verdict - The rule.
 * @param text - The result's text (its beginning and its end).
 * @param isError - The tool reported an error (a non-zero exit).
 * @returns The outcome and a short note.
 */
export function judgeResult(
  verdict: CommandKind["verdict"],
  text: string,
  isError: boolean,
): { outcome: StoryOutcome; note: string | null; failed?: "build" | "tests" | "probe" } {
  /**
   * The verdict of a `saltests` summary line, if the text has one.
   *
   * @returns The verdict, or null.
   */
  const saltests = (): { outcome: StoryOutcome; note: string; failed?: "tests" } | null => {
    const m = /saltests:\s*([\d,]+)\s*checks,\s*(\d+)\s*failed/.exec(text);
    if (!m) return null;
    const failed = Number(m[2]);
    return failed === 0
      ? { outcome: "ok", note: `${m[1]} checks, 0 failed` }
      : { outcome: "fail", note: `${failed} of ${m[1]} checks failed`, failed: "tests" };
  };
  switch (verdict) {
    case "build": {
      // Only the build's own words fail a build (contracts/story-rules.md): a command that builds
      // and then runs saltests or a probe ends non-zero when those fail - their summary says so.
      if (/BUILD FAILED|\berror (C|LNK|MSB|RC)\d+/i.test(text))
        return { outcome: "fail", note: "build failed", failed: "build" };
      const salt = saltests();
      if (salt && salt.outcome === "fail") return salt;
      const probeFails = /\bFAIL[:=]?\s+([1-9]\d*)\b/.exec(text);
      if (probeFails) return { outcome: "fail", note: `${probeFails[1]} FAIL`, failed: "probe" };
      if (/BUILD SUCCEEDED/.test(text))
        return { outcome: "ok", note: salt ? `build succeeded, ${salt.note}` : "build succeeded" };
      if (isError) return { outcome: "warn", note: "ended with an error" };
      return { outcome: "ok", note: salt?.note ?? null };
    }
    case "saltests": {
      const salt = saltests();
      if (salt) return salt;
      return isError
        ? { outcome: "fail", note: "the unit rules failed", failed: "tests" }
        : { outcome: "ok", note: null };
    }
    case "tests": {
      // vitest prints "Test Files  20 passed" before "Tests  366 passed": its Tests line counts
      // the tests; other runners' summaries come last, so the last count is taken otherwise.
      const tests = /\bTests\s+(?:(\d+)\s+failed\s*\|\s*)?(?:(\d+)\s+passed)?/.exec(text);
      /**
       * The last count before a word ("40 passed").
       *
       * @param word - `passed` or `failed`.
       * @returns The count, or null when the text has none.
       */
      const last = (word: string): number | null => {
        const all = [...text.matchAll(new RegExp(`(\\d+)\\s+${word}`, "g"))];
        return all.length ? Number(all[all.length - 1]![1]) : null;
      };
      const failedCount = tests?.[1] ? Number(tests[1]) : tests?.[2] ? 0 : (last("failed") ?? 0);
      const passedCount = tests?.[2] ? Number(tests[2]) : last("passed");
      if (failedCount > 0)
        return {
          outcome: "fail",
          note: `${failedCount} failed${passedCount !== null ? `, ${passedCount} passed` : ""}`,
        };
      if (isError) return { outcome: "fail", note: "the tests failed" };
      return { outcome: "ok", note: passedCount !== null ? `${passedCount} passed` : null };
    }
    case "probe": {
      /**
       * How many rows a probe reports with a word: a summary line counts its rows ("Rows: PASS
       * 29, FAIL 0"); otherwise each occurrence of the word counts once.
       *
       * @param word - `PASS` or `FAIL`.
       * @returns The count.
       */
      const counted = (word: string): number => {
        const sums = [...text.matchAll(new RegExp(`\\b${word}[:=]?\\s+(\\d+)\\b`, "g"))];
        if (sums.length > 0) return sums.reduce((n, m) => n + Number(m[1]), 0);
        return (text.match(new RegExp(`\\b${word}\\b`, "g")) ?? []).length;
      };
      const fails = counted("FAIL");
      const passes = counted("PASS");
      if (fails > 0) return { outcome: "fail", note: `${fails} FAIL, ${passes} PASS` };
      if (isError) return { outcome: "fail", note: "the probe failed" };
      return { outcome: "ok", note: passes > 0 ? `${passes} PASS` : null };
    }
    case "encoding": {
      const m = /TOTAL:\s*(\d+)/.exec(text);
      if (m) {
        return Number(m[1]) === 0
          ? { outcome: "ok", note: "no findings" }
          : { outcome: "fail", note: `${m[1]} findings` };
      }
      return isError ? { outcome: "fail", note: null } : { outcome: "ok", note: null };
    }
    case "commit": {
      const m = /\[([^\]\s]+)\s+([0-9a-f]{7,40})\]\s*(.*)/.exec(text);
      if (m) return { outcome: "ok", note: `${m[2]} on ${m[1]}` };
      return isError ? { outcome: "warn", note: "nothing committed" } : { outcome: "ok", note: null };
    }
    case "backlog":
    case "plain":
    default:
      return isError ? { outcome: "warn", note: "ended with an error" } : { outcome: "ok", note: null };
  }
}

/**
 * The verdict of a command that runs checks (feature 415, review 3): each check by its own words
 * in the result - the build by `BUILD FAILED` or an error code, saltests by its summary, a probe
 * by its FAIL rows, tests by their counts, the encoding guard by its total. The first failing
 * check is blamed. A non-zero exit without such words fails a command of one check that only
 * speaks through its exit code (saltests, a probe, tests); a combined command, or a build, ends
 * with a warning instead.
 *
 * @param checks - The command's checks ({@link checkSubjects}).
 * @param text - The result's text (its beginning and its end).
 * @param isError - A non-zero exit.
 * @returns The outcome, a note and the failing check.
 */
export function judgeChecks(
  checks: readonly string[],
  text: string,
  isError: boolean,
): { outcome: StoryOutcome; note: string | null; failed?: string } {
  const notes: string[] = [];
  const build = checks.includes("build");
  if (build && /BUILD FAILED|\berror (C|LNK|MSB|RC)\d+/i.test(text))
    return { outcome: "fail", note: "build failed", failed: "build" };
  if (checks.includes("saltests")) {
    const m = /saltests:\s*([\d,]+)\s*checks,\s*(\d+)\s*failed/.exec(text);
    if (m && Number(m[2]) > 0)
      return { outcome: "fail", note: `${m[2]} of ${m[1]} checks failed`, failed: "saltests" };
    if (m) notes.push(`${m[1]} checks, 0 failed`);
  }
  const probe = checks.find((c) => c.startsWith("probe:"));
  if (probe) {
    const verdict = judgeResult("probe", text, false);
    if (verdict.outcome === "fail") return { ...verdict, failed: probe };
    if (verdict.note) notes.push(verdict.note);
  }
  if (checks.includes("encoding")) {
    const m = /TOTAL:\s*(\d+)/.exec(text);
    if (m && Number(m[1]) > 0) return { outcome: "fail", note: `${m[1]} findings`, failed: "encoding" };
    if (m) notes.push("no findings");
  }
  const tests = checks.find((c) => c.startsWith("tests:"));
  if (tests) {
    const verdict = judgeResult("tests", text, false);
    if (verdict.outcome === "fail") return { ...verdict, failed: tests };
    if (verdict.note) notes.push(verdict.note);
  }
  if (build && /BUILD SUCCEEDED/.test(text)) notes.unshift("build succeeded");
  if (isError && notes.length === 0) {
    const only = checks.length === 1 ? checks[0]! : null;
    if (only && only !== "build")
      return {
        outcome: "fail",
        note:
          only === "saltests"
            ? "the unit rules failed"
            : only.startsWith("probe:")
              ? "the probe failed"
              : only === "encoding"
                ? null
                : "the tests failed",
        failed: only,
      };
    return { outcome: "warn", note: "ended with an error" };
  }
  return {
    outcome: isError ? "warn" : "ok",
    note: notes.length ? notes.join(", ") : isError ? "ended with an error" : null,
  };
}

/** The state of a group being filled. */
interface OpenGroup {
  /** The entry's id. */
  id: string;
  /** `READ` (reads and searches) or `EDIT`. */
  label: "READ" | "EDIT";
  /** Files named by its calls, in order, without repeats. */
  files: string[];
  /** Number of searches (reads group). */
  searches: number;
  /** Search patterns (reads group). */
  patterns: string[];
}

/** The story fold of one run. */
export class RunStory {
  /** The phase machine (shared with the summary card). */
  readonly state: RunState;

  /** The entries, oldest first. */
  private entries: StoryEntry[] = [];

  /** Index of an entry by its id. */
  private index = new Map<string, number>();

  /** The entry of a tool call, by tool-use id. */
  private readonly byTool = new Map<string, string>();

  /** The root agent entry of a subagent's tool call, by tool-use id. */
  private readonly agentOf = new Map<string, string>();

  /** How each tool call's result is judged. */
  private readonly verdicts = new Map<string, CommandKind>();

  /** The checks each check entry ran (for resolving), by entry id. */
  private readonly subjects = new Map<string, string[]>();

  /** True once the run changed a source file (failures before it measure the problem). */
  private sourceChanged = false;

  /** Check entries opened while the run was still measuring (before implement, no source changed). */
  private readonly measuring = new Set<string>();

  /** The check whose failure made an entry critical, by entry id. */
  private readonly failedCheck = new Map<string, string>();

  /** The group being filled. */
  private group: OpenGroup | null = null;

  /** Images the run opened or wrote, by path. */
  private readonly imageList = new Map<string, { path: string; at: string | null }>();

  /** Files the run changed, by path. */
  private readonly fileMap = new Map<string, StoryFile>();

  /** Commits seen in results. */
  private readonly commitList: { hash: string; subject: string }[] = [];

  /** The phase of the last entry. */
  private lastPhase: Phase;

  /** Attempts whose session line was shown. */
  private readonly sessions = new Set<number>();

  /** The attempt the events belong to. */
  private attempt = 1;

  /** The repository root the session runs in (from `system/init`), when known. */
  private root: string | null = null;

  /** Counts changes (a view re-renders when it moves). */
  version = 0;

  /**
   * Creates an empty story.
   *
   * @param kind - `item` or `triage`.
   */
  constructor(kind: "item" | "triage") {
    this.state = new RunState(kind);
    this.lastPhase = this.state.phase;
  }

  /**
   * The entries (a fresh array; the entries themselves are never mutated).
   *
   * @returns The entries, oldest first.
   */
  view(): StoryEntry[] {
    return this.entries.slice();
  }

  /**
   * The critical entries, newest first.
   *
   * @returns The entries.
   */
  critical(): StoryEntry[] {
    return this.entries.filter((e) => e.critical !== null).reverse();
  }

  /**
   * The entries that state decisions, oldest first.
   *
   * @returns The entries.
   */
  decisions(): StoryEntry[] {
    return this.entries.filter((e) => e.decision);
  }

  /**
   * The images the run opened or wrote, in order of first use.
   *
   * @returns Their paths and times.
   */
  images(): { path: string; at: string | null }[] {
    return [...this.imageList.values()];
  }

  /**
   * The files the run changed.
   *
   * @returns The files, most edited first.
   */
  files(): StoryFile[] {
    return [...this.fileMap.values()].sort((a, b) => b.edits - a.edits || a.rel.localeCompare(b.rel));
  }

  /**
   * The commits the run's results showed.
   *
   * @returns Hash and subject, oldest first.
   */
  commits(): { hash: string; subject: string }[] {
    return this.commitList.slice();
  }

  /**
   * What happens now: the latest call in flight, else the latest entry.
   *
   * @returns The activity, or null for an empty story.
   */
  now(): StoryNow | null {
    for (let i = this.entries.length - 1; i >= 0; i--) {
      const e = this.entries[i]!;
      if (e.kind === "phase" || e.kind === "turn" || e.kind === "session") continue;
      if (e.outcome === "running") {
        const child = e.kind === "group" ? e.children.at(-1) : null;
        return {
          title: child && child.outcome === "running" ? child.title : e.title,
          label: e.label,
          since: (child?.at ?? e.at) || null,
          running: true,
        };
      }
      if (i < this.entries.length - 8) break;
    }
    const last = [...this.entries].reverse().find((e) => e.kind !== "turn" && e.kind !== "session");
    return last
      ? { title: last.title, label: last.label, since: last.endedAt ?? last.at, running: false }
      : null;
  }

  /**
   * The latest main-thread message of the agent.
   *
   * @returns Its text, or null.
   */
  latestMessage(): StoryEntry | null {
    for (let i = this.entries.length - 1; i >= 0; i--)
      if (this.entries[i]!.kind === "message") return this.entries[i]!;
    return null;
  }

  /**
   * A one-line digest of each of the last entries (for the chat snapshot).
   *
   * @param count - Most lines.
   * @returns The lines, oldest first.
   */
  digest(count: number): string[] {
    return this.entries
      .filter((e) => e.importance !== "low")
      .slice(-count)
      .map((e) => storyLine(e));
  }

  /**
   * A path relative to the repository.
   *
   * @param path - A path as the trace names it.
   * @returns The relative path.
   */
  private rel(path: string): string {
    return relativePath(path, this.root);
  }

  /**
   * Adds an entry.
   *
   * @param event - The event that opened it.
   * @param fields - The entry's fields.
   * @returns The new entry's id.
   */
  private push(
    event: TraceEvent,
    fields: Partial<StoryEntry> & Pick<StoryEntry, "kind" | "label" | "title">,
  ): string {
    let n = 0;
    let id = `${event.offset}:${n}`;
    while (this.index.has(id)) id = `${event.offset}:${++n}`;
    const entry: StoryEntry = {
      id,
      at: event.at,
      endedAt: null,
      phase: this.state.phase,
      detail: null,
      outcome: "info",
      importance: "normal",
      toolUseId: null,
      tool: null,
      children: [],
      childCount: 0,
      status: null,
      image: null,
      critical: null,
      resolved: false,
      decision: false,
      ...fields,
    };
    this.index.set(id, this.entries.length);
    this.entries.push(entry);
    this.version++;
    if (this.entries.length > MAX_ENTRIES) this.trim();
    return id;
  }

  /**
   * Replaces an entry with a changed copy.
   *
   * @param id - The entry's id.
   * @param patch - The changes, or a function of the old entry giving them.
   */
  private update(id: string, patch: Partial<StoryEntry> | ((old: StoryEntry) => Partial<StoryEntry>)): void {
    const i = this.index.get(id);
    if (i === undefined) return;
    const old = this.entries[i]!;
    this.entries[i] = { ...old, ...(typeof patch === "function" ? patch(old) : patch) };
    this.version++;
  }

  /**
   * Adds a line under an entry (a group's call, a subagent's step).
   *
   * @param id - The entry.
   * @param child - The line.
   */
  private addChild(id: string, child: StoryChild): void {
    this.update(id, (old) => ({
      children: old.children.length < MAX_CHILDREN ? [...old.children, child] : old.children,
      childCount: old.childCount + 1,
    }));
  }

  /** Drops the oldest routine entries when there are too many. */
  private trim(): void {
    const drop = new Set<string>();
    for (const e of this.entries) {
      if (drop.size >= 1000) break;
      if ((e.importance === "low" || e.kind === "group") && !e.critical) drop.add(e.id);
    }
    if (drop.size === 0) for (const e of this.entries.slice(0, 1000)) if (!e.critical) drop.add(e.id);
    this.entries = this.entries.filter((e) => !drop.has(e.id) || e.outcome === "running");
    this.index = new Map(this.entries.map((e, i) => [e.id, i]));
  }

  /**
   * Folds one event.
   *
   * @param event - A normalised trace event.
   */
  apply(event: TraceEvent): void {
    this.state.apply(event);
    // A phase change opens its section before the entry of the event that caused it.
    if (this.state.phase !== this.lastPhase) {
      this.lastPhase = this.state.phase;
      this.group = null;
      this.push(event, {
        kind: "phase",
        label: "PHASE",
        title: PHASE_TITLES[this.state.phase],
        outcome: this.state.phase === "stopped" ? "fail" : "info",
        importance: this.state.phase === "stopped" ? "critical" : "high",
        critical: this.state.phase === "stopped" ? "The run took the stop path" : null,
      });
    }
    if (event.parentToolUseId !== null) {
      this.subagent(event);
      return;
    }
    switch (event.kind) {
      case "tool-use":
        this.toolUse(event);
        return;
      case "tool-result":
        this.toolResult(event);
        return;
      case "assistant-text":
        this.message(event);
        return;
      case "task":
        this.task(event);
        return;
      case "attempt":
        this.attemptLine(event);
        return;
      case "init":
        if (event.info?.cwd) this.root = event.info.cwd;
        if (!this.sessions.has(this.attempt)) {
          this.sessions.add(this.attempt);
          this.push(event, {
            kind: "session",
            label: "INFO",
            title: `Claude session starts${event.name ? ` (${event.name})` : ""}`,
            importance: "low",
          });
        }
        return;
      case "rate-limit": {
        const status = event.info?.limits?.status ?? event.name ?? "";
        if (status && !status.startsWith("allowed")) {
          this.group = null;
          this.push(event, {
            kind: "limit",
            label: "LIMIT",
            title: "Usage limit reached - the loop waits until it resets",
            outcome: "warn",
            importance: "critical",
            critical: "The usage limit stopped the run for now",
          });
        }
        return;
      }
      case "result": {
        const cost = event.info?.costUsd;
        const previous = this.entries.at(-1);
        if (!event.isError && previous?.kind === "turn" && previous.outcome !== "fail") {
          // Wakeups of a waiting run end turn after turn: one line, the latest figures.
          this.update(previous.id, {
            title: `The agent's turns end${cost !== undefined ? ` - $${cost.toFixed(2)} reported so far` : ""}`,
            endedAt: event.at,
            childCount: previous.childCount + 1,
          });
          return;
        }
        this.push(event, {
          kind: "turn",
          label: event.isError ? "ERROR" : "INFO",
          title: event.isError
            ? "A turn of the agent ended with an error"
            : `The agent's turn ends${cost !== undefined ? ` - $${cost.toFixed(2)} reported so far` : ""}`,
          detail: event.text,
          outcome: event.isError ? "fail" : "info",
          importance: event.isError ? "critical" : "low",
          critical: event.isError ? "A turn ended with an error" : null,
        });
        return;
      }
      case "unparsable":
        this.push(event, {
          kind: "unreadable",
          label: "ERROR",
          title: "An unreadable line in the trace",
          detail: event.summary,
          outcome: "warn",
          importance: "normal",
        });
        return;
      default:
        return;
    }
  }

  /**
   * A main-thread tool call.
   *
   * @param event - The tool-use event.
   */
  private toolUse(event: TraceEvent): void {
    const name = event.name ?? "?";
    const info = event.info ?? {};
    const toolUseId = event.toolUseId;
    const file = info.filePath ?? null;
    const description = info.description ?? null;
    const base = { toolUseId, tool: name, outcome: "running" as StoryOutcome };
    // An image read or written: a screenshot of the gallery, never hidden in a group.
    if ((name === "Read" || name === "Write") && file && IMAGE.test(file)) {
      this.group = null;
      if (!this.imageList.has(file)) this.imageList.set(file, { path: file, at: event.at });
      const id = this.push(event, {
        ...base,
        kind: "action",
        label: "SCREENSHOT",
        title:
          name === "Read" ? `Looks at the screenshot ${baseName(file)}` : `Saves the image ${baseName(file)}`,
        image: file,
        importance: "high",
      });
      if (toolUseId) this.byTool.set(toolUseId, id);
      return;
    }
    if (READ_TOOLS.has(name) || EDIT_TOOLS.has(name)) {
      this.groupCall(event, name, file);
      return;
    }
    this.group = null;
    if (name === "Agent" || name === "Task") {
      const review =
        this.state.phase === "review" || /\breview|refute/i.test(description ?? "") ? "REVIEW" : "AGENT";
      const id = this.push(event, {
        ...base,
        kind: "agent",
        label: review,
        title: `${review === "REVIEW" ? "Review agent" : "Agent"}: ${short(description ?? event.summary, 140)}`,
        detail: info.subagentType ? `Agent type: ${info.subagentType}` : null,
        importance: "high",
        status: "started",
      });
      if (toolUseId) {
        this.byTool.set(toolUseId, id);
        this.agentOf.set(toolUseId, id);
      }
      return;
    }
    if (name === "Skill") {
      const skill = (description ?? event.summary).split(/\s+/)[0] ?? "";
      const speckit = /^speckit-(.+)$/.exec(skill);
      const id = this.push(event, {
        ...base,
        kind: "action",
        label: speckit ? "SPEC KIT" : "INFO",
        title: speckit ? `Runs Spec Kit *${speckit[1]}*` : `Uses the skill ${skill}`,
        importance: speckit ? "high" : "normal",
      });
      if (toolUseId) this.byTool.set(toolUseId, id);
      return;
    }
    if (name === "Bash" || name === "PowerShell") {
      const command = info.command ?? event.summary;
      const kind = classifyCommand(command);
      const id = this.push(event, {
        ...base,
        kind: "action",
        label: kind.label,
        // The call's own description says what it is for; the kind's sentence otherwise. A new
        // item, a block and a commit keep the sentence that names what they record.
        title:
          description && kind.verdict !== "commit" && !kind.criticalOnOk
            ? short(description)
            : short(kind.title),
        detail: `\`\`\`\n${event.summary}\n\`\`\``,
        importance: kind.importance,
      });
      if (toolUseId) {
        this.byTool.set(toolUseId, id);
        this.verdicts.set(toolUseId, kind);
        if (RESOLVABLE.has(kind.label)) this.subjects.set(id, checkSubjects(command));
        // Before implementing and before any source changed, a failing check measures the
        // problem (stop-rules 2.1) - also in a run that never calls the implement skill.
        if (MEASURING.has(this.state.phase) && !this.sourceChanged) this.measuring.add(id);
      }
      return;
    }
    if (name === "ToolSearch") {
      const id = this.push(event, {
        ...base,
        kind: "action",
        label: "INFO",
        title: "Loads the definitions of more tools",
        importance: "low",
      });
      if (toolUseId) this.byTool.set(toolUseId, id);
      return;
    }
    if (name === "TodoWrite") {
      const id = this.push(event, {
        ...base,
        kind: "action",
        label: "PLAN",
        title: "Updates its to-do list",
        importance: "low",
      });
      if (toolUseId) this.byTool.set(toolUseId, id);
      return;
    }
    if (name === "WebFetch" || name === "WebSearch") {
      const id = this.push(event, {
        ...base,
        kind: "action",
        label: "WEB",
        title: `Looks up ${short(event.summary, 100)}`,
      });
      if (toolUseId) this.byTool.set(toolUseId, id);
      return;
    }
    const id = this.push(event, {
      ...base,
      kind: "action",
      label: "INFO",
      title: `${name}: ${short(description ?? event.summary, 120)}`,
      importance: "low",
    });
    if (toolUseId) this.byTool.set(toolUseId, id);
  }

  /**
   * A read, search or edit: joins the open group of its kind or opens one.
   *
   * @param event - The tool-use event.
   * @param name - The tool.
   * @param file - The file it names, if any.
   */
  private groupCall(event: TraceEvent, name: string, file: string | null): void {
    const label: "READ" | "EDIT" = EDIT_TOOLS.has(name) ? "EDIT" : "READ";
    if (label === "EDIT" && file && isSourcePath(file, this.root)) this.sourceChanged = true;
    if (label === "EDIT" && file) {
      const rel = this.rel(file);
      const known = this.fileMap.get(file);
      this.fileMap.set(file, {
        path: file,
        rel,
        component: componentOf(rel),
        edits: (known?.edits ?? 0) + 1,
      });
    }
    if (!this.group || this.group.label !== label) {
      const id = this.push(event, {
        kind: "group",
        label,
        title: "",
        outcome: "running",
        tool: name,
        importance: label === "EDIT" ? "normal" : "low",
      });
      this.group = { id, label, files: [], searches: 0, patterns: [] };
    }
    const group = this.group;
    const isSearch = name === "Grep" || name === "Glob" || name === "LSP";
    if (file && !group.files.includes(file)) group.files.push(file);
    if (isSearch) {
      group.searches++;
      if (group.patterns.length < 3) group.patterns.push(short(event.summary, 40));
    }
    const childTitle =
      label === "EDIT"
        ? `${name === "Write" ? "Writes" : "Edits"} ${file ? this.rel(file) : event.summary}`
        : isSearch
          ? `Searches for \`${short(event.summary, 80)}\``
          : `Reads ${file ? this.rel(file) : short(event.summary, 80)}`;
    this.addChild(group.id, {
      at: event.at,
      label: isSearch ? "SEARCH" : label,
      title: childTitle,
      outcome: "running",
      toolUseId: event.toolUseId,
    });
    this.update(group.id, {
      title: groupTitle(group, (f) => this.rel(f)),
      outcome: "running",
      endedAt: null,
    });
    if (event.toolUseId) this.byTool.set(event.toolUseId, group.id);
  }

  /**
   * A main-thread tool result: the outcome of its entry.
   *
   * @param event - The tool-result event.
   */
  private toolResult(event: TraceEvent): void {
    const toolUseId = event.toolUseId;
    if (!toolUseId) return;
    const id = this.byTool.get(toolUseId);
    if (!id) return;
    const i = this.index.get(id);
    if (i === undefined) return;
    const entry = this.entries[i]!;
    const text = `${event.text ?? event.summary}\n${event.info?.tail ?? ""}`;
    if (entry.kind === "group") {
      const childOutcome: StoryOutcome = event.isError ? "warn" : "ok";
      this.update(id, (old) => {
        const children = old.children.map((c) =>
          c.toolUseId === toolUseId ? { ...c, outcome: childOutcome } : c,
        );
        const running = children.some((c) => c.outcome === "running");
        const warned = children.some((c) => c.outcome === "warn");
        return {
          children,
          outcome: running ? "running" : warned ? "warn" : "ok",
          endedAt: running ? null : event.at,
        };
      });
      return;
    }
    if (entry.kind === "agent") {
      this.update(id, {
        outcome: event.isError ? "fail" : "ok",
        endedAt: event.at,
        status: event.isError ? "failed" : "finished",
        detail: `${entry.detail ? `${entry.detail}\n\n` : ""}${event.text ?? event.summary}`,
      });
      return;
    }
    const kind = this.verdicts.get(toolUseId);
    if (kind) {
      // A command's checks (build, saltests, probes, tests, the encoding guard) are judged
      // together: each by its own words, the failing one blamed (reviews 1 - 3 of 415).
      const checks = this.subjects.get(id) ?? [];
      let verdict: { outcome: StoryOutcome; note: string | null; failed?: string } = checks.length
        ? judgeChecks(checks, text, event.isError)
        : judgeResult(kind.verdict, text, event.isError);
      // A failure on purpose is the expected result, not a problem: a negative control, a mutant,
      // a check of the code before the fix - and every check before implementing, which measures
      // the problem (stop-rules 2.1).
      const measuring = this.measuring.has(id);
      const onPurpose = EXPECTED_FAILURE.test(entry.title);
      if (verdict.outcome === "fail" && (onPurpose || measuring)) {
        const why = measuring && !onPurpose ? "failed while measuring the problem" : "failed, as intended";
        verdict = { outcome: "warn", note: `${why}${verdict.note ? ` (${verdict.note})` : ""}` };
      }
      const failed = verdict.outcome === "fail";
      const blamed = failed ? (verdict.failed ?? checks[0] ?? null) : null;
      const reason =
        blamed === "build"
          ? "The build failed"
          : blamed?.startsWith("probe:")
            ? "A GUI probe failed"
            : blamed === "encoding"
              ? "The encoding guard found problems"
              : kind.label === "BUILD" && !blamed
                ? "The build failed"
                : kind.label === "PROBE" && !blamed
                  ? "A GUI probe failed"
                  : kind.label === "CHECK" && !blamed
                    ? "The encoding guard found problems"
                    : "Tests failed";
      // The verdict's note adds the figures ("2 failed, 364 passed"), not the same words again.
      const note =
        verdict.note && !reason.toLowerCase().includes(verdict.note.toLowerCase()) ? `: ${verdict.note}` : "";
      const critical =
        failed && kind.verdict !== "plain" && kind.verdict !== "backlog" && kind.verdict !== "commit"
          ? `${reason}${note}`
          : verdict.outcome === "ok"
            ? kind.criticalOnOk
            : null;
      if (blamed) this.failedCheck.set(id, blamed);
      // A pass resolves the failures of a check it ran too (the same probe, the same tests, the
      // build) - not those of another probe, nor a saltests failure by a plain build; a pass on
      // purpose (a probe of the old build) resolves nothing.
      if (verdict.outcome === "ok" && checks.length && !onPurpose) {
        for (const e of this.entries) {
          const check = this.failedCheck.get(e.id);
          if (e.critical && !e.resolved && e.id !== id && check && checks.includes(check))
            this.update(e.id, { resolved: true });
        }
      }
      if (kind.verdict === "commit" && verdict.outcome === "ok") {
        const m = /\[([^\]\s]+)\s+([0-9a-f]{7,40})\]\s*(.*)/.exec(text);
        if (m) this.commitList.push({ hash: m[2]!, subject: short(m[3] ?? "", 200) });
      }
      this.update(id, (old) => ({
        outcome: verdict.outcome,
        endedAt: event.at,
        title:
          verdict.note && !old.title.includes(verdict.note) ? `${old.title} - ${verdict.note}` : old.title,
        detail: `${old.detail ?? ""}\n\n${resultExcerpt(event)}`.trim(),
        importance: critical ? "critical" : verdict.outcome === "fail" ? "high" : old.importance,
        critical,
      }));
      return;
    }
    this.update(id, (old) => ({
      outcome: event.isError ? "warn" : "ok",
      endedAt: event.at,
      detail:
        old.kind === "action" && event.isError
          ? `${old.detail ?? ""}\n\n${resultExcerpt(event)}`.trim()
          : old.detail,
    }));
  }

  /**
   * A main-thread message of the agent.
   *
   * @param event - The assistant-text event.
   */
  private message(event: TraceEvent): void {
    this.group = null;
    const text = event.text ?? event.summary;
    const decision = DECISION_WORDS.test(text);
    const finding =
      AFTER_IMPLEMENT.has(this.state.phase) && mustFinding(text) && !MUST_FIXED_AT_ONCE.test(text);
    // A later review without a MUST, or a MUST reported fixed, resolves the findings before it.
    if (
      !finding &&
      AFTER_IMPLEMENT.has(this.state.phase) &&
      MUST_CLEARED.test(text) &&
      !MUST_STILL_OPEN.test(text)
    ) {
      for (const e of this.entries)
        if (e.kind === "message" && e.critical && !e.resolved) this.update(e.id, { resolved: true });
    }
    this.push(event, {
      kind: "message",
      label: finding ? "REVIEW" : decision ? "DECISION" : "MESSAGE",
      title: firstSentence(text),
      detail: text,
      outcome: "info",
      importance: finding ? "critical" : decision ? "high" : "normal",
      critical: finding ? "The review reports a MUST finding" : null,
      decision,
    });
  }

  /**
   * A task event: the progress of a subagent or a background command.
   *
   * @param event - The task event.
   */
  private task(event: TraceEvent): void {
    const toolUseId = event.toolUseId;
    if (!toolUseId) return;
    const id = this.agentOf.get(toolUseId) ?? this.byTool.get(toolUseId);
    if (!id) return;
    const status = event.info?.taskStatus || event.summary;
    if (!status) return;
    this.update(id, { status: short(status, 160) });
  }

  /**
   * An event of a subagent: a line under its agent.
   *
   * @param event - The event (it has a parent tool-use id).
   */
  private subagent(event: TraceEvent): void {
    const parent = event.parentToolUseId!;
    const id = this.agentOf.get(parent);
    if (!id) return;
    if (event.kind === "tool-use") {
      if (event.toolUseId) this.agentOf.set(event.toolUseId, id);
      const name = event.name ?? "?";
      const info = event.info ?? {};
      const file = info.filePath;
      if (file && IMAGE.test(file) && (name === "Read" || name === "Write") && !this.imageList.has(file))
        this.imageList.set(file, { path: file, at: event.at });
      const label: StoryLabel =
        name === "Bash" || name === "PowerShell"
          ? classifyCommand(info.command ?? event.summary).label
          : EDIT_TOOLS.has(name)
            ? "EDIT"
            : READ_TOOLS.has(name)
              ? name === "Read"
                ? "READ"
                : "SEARCH"
              : "INFO";
      const title =
        info.description && (name === "Bash" || name === "PowerShell")
          ? short(info.description)
          : file
            ? `${name === "Read" ? "Reads" : EDIT_TOOLS.has(name) ? "Edits" : name} ${this.rel(file)}`
            : `${name}: ${short(event.summary, 100)}`;
      this.addChild(id, { at: event.at, label, title, outcome: "running", toolUseId: event.toolUseId });
      this.update(id, { status: short(title, 160) });
      return;
    }
    if (event.kind === "tool-result" && event.toolUseId) {
      const toolUseId = event.toolUseId;
      const childOutcome: StoryOutcome = event.isError ? "warn" : "ok";
      this.update(id, (old) => ({
        children: old.children.map((c) => (c.toolUseId === toolUseId ? { ...c, outcome: childOutcome } : c)),
      }));
      return;
    }
    if (event.kind === "assistant-text") {
      this.addChild(id, {
        at: event.at,
        label: "MESSAGE",
        title: `says: ${firstSentence(event.text ?? event.summary)}`,
        outcome: "info",
        toolUseId: null,
      });
    }
  }

  /**
   * An attempt separator.
   *
   * @param event - The attempt event.
   */
  private attemptLine(event: TraceEvent): void {
    const info = event.text ? (safeParse(event.text) as { attempt?: number; reason?: string }) : {};
    this.attempt = info.attempt ?? this.attempt + 1;
    this.group = null;
    // Calls still running when a new process starts were cut off.
    for (const e of this.entries) {
      if (e.outcome === "running")
        this.update(e.id, { outcome: "warn", status: "cut off", endedAt: event.at });
    }
    if (this.attempt > 1) {
      this.push(event, {
        kind: "attempt",
        label: "RESTART",
        title: `The run continues after ${info.reason && info.reason !== "-" ? info.reason : "an interruption"} (attempt ${this.attempt})`,
        outcome: "warn",
        importance: "high",
      });
    }
  }
}

/**
 * The title of a group from its calls.
 *
 * @param group - The group.
 * @param rel - Makes a path relative to the repository.
 * @returns The sentence.
 */
function groupTitle(group: OpenGroup, rel: (path: string) => string): string {
  const names = group.files.map((f) => rel(f));
  const list = names.slice(0, 3).map((n) => baseName(n));
  const more = names.length > 3 ? ` and ${names.length - 3} more` : "";
  if (group.label === "EDIT") {
    if (names.length === 1) return `Edits \`${baseName(names[0]!)}\` (${componentOf(names[0]!)})`;
    return `Changes ${names.length} files: ${list.join(", ")}${more}`;
  }
  const reads = names.length;
  if (reads === 0)
    return group.searches === 1
      ? `Searches the code for ${group.patterns[0] ?? ""}`
      : `Searches the code (${group.searches} searches)`;
  const searches = group.searches > 0 ? ` and searches ${group.searches} times` : "";
  if (reads === 1 && group.searches === 0) return `Reads \`${list[0]}\``;
  return `Reads ${reads} file${reads === 1 ? "" : "s"}${searches}: ${list.join(", ")}${more}`;
}

/**
 * The beginning and end of a result for an entry's detail.
 *
 * @param event - The tool-result event.
 * @returns A fenced excerpt.
 */
function resultExcerpt(event: TraceEvent): string {
  const head = (event.text ?? event.summary).slice(0, 1200);
  const tail = event.info?.tail ? `\n…\n${event.info.tail.slice(-600)}` : "";
  return `\`\`\`\n${head}${tail}\n\`\`\``;
}

/**
 * One line of an entry for a digest.
 *
 * @param entry - The entry.
 * @returns `HH:MM LABEL outcome - title`.
 */
export function storyLine(entry: StoryEntry): string {
  const time = entry.at ? localClock(entry.at) : "--:--";
  const outcome = entry.outcome === "info" ? "" : ` ${entry.outcome}`;
  return short(
    `${time} ${entry.label}${outcome} - ${entry.title}${entry.status && entry.kind === "agent" ? ` (${entry.status})` : ""}`,
    300,
  );
}

/**
 * The local clock time of an ISO time.
 *
 * @param iso - An ISO time.
 * @returns `HH:MM` in the local time zone.
 */
export function localClock(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "--:--";
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}
