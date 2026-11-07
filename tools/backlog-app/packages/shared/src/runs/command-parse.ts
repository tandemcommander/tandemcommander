// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Which programs a shell command runs (feature 415, reviews 2 and 3): the story tells a
 * build, a test run or a GUI probe only when the command runs one - not when its text mentions
 * one in a quoted pattern, a heredoc, a commit message or the arguments of `grep`.
 *
 * The runs use both Bash and PowerShell, so the reading knows both: single and double quotes (a
 * backslash-escaped quote in Bash), line continuations (a backslash or a backtick at a line end),
 * heredoc bodies, parts split at `;`, `|`, `||`, `&&`, a background `&`, line ends, braces and
 * parentheses outside quotes (`foreach (…) { … }`, `(…) | …`, `$(…)`), assignments (`$o = …`,
 * `NAME=value`), the call operators `&` and `.`, and the launchers `cmd /c`,
 * `Start-Process [-FilePath]`, `powershell -File`, `powershell -Command`, `bash -c` and
 * `timeout N`. It is a reading for labels, not a shell: a command it cannot read is told as a
 * plain command.
 */

/** A word of a command and whether it was quoted. */
interface Word {
  /** The text without its quotes. */
  text: string;
  /** True when (part of) it was quoted. */
  quoted: boolean;
  /** The text before its first quote (`BL=` of `BL="python …"`), the whole text when unquoted. */
  lead: string;
}

/** Words that open a block or a loop: the part has no program of its own (its body is a part). */
const KEYWORDS = new Set([
  "foreach",
  "for",
  "if",
  "elseif",
  "else",
  "while",
  "do",
  "until",
  "try",
  "catch",
  "finally",
  "switch",
  "return",
  "then",
  "fi",
  "done",
  "measure-command",
  "invoke-command",
  "foreach-object",
  "where-object",
  "%",
  "?",
  "function",
]);

/** Prefix words that are not the program (`time make`, `nohup x`). */
const PREFIXES = new Set(["&", ".", "call", "time", "exec", "nohup", "command", "env", "sudo"]);

/**
 * The file name of a path, lower case; `saltests` and `saltests.exe` are one program.
 *
 * @param token - A path or a name.
 * @returns The name.
 */
export function programName(token: string): string {
  const parts = token.replace(/\\/g, "/").split("/");
  const name = (parts[parts.length - 1] ?? token).toLowerCase();
  return name === "saltests" ? "saltests.exe" : name;
}

/**
 * Leaves out the bodies of heredocs (`<<'END' … END`); a body without its end (a command cut
 * short) is left out to the end.
 *
 * @param text - The command.
 * @returns The command without heredoc bodies.
 */
function withoutHeredocs(text: string): string {
  return text.replace(/<<-?\s*(['"]?)([A-Za-z_]\w*)\1[^\n]*\n[\s\S]*?(?:\n[ \t]*\2[ \t]*(?=\n|$)|$)/g, "\n");
}

/**
 * Splits a command into parts of words, outside quotes only.
 *
 * @param text - The command (heredocs removed).
 * @returns The parts.
 */
function parts(text: string): Word[][] {
  const result: Word[][] = [];
  let words: Word[] = [];
  let word = "";
  let quoted = false;
  let lead: string | null = null;
  let quote: '"' | "'" | null = null;
  let varBraces = 0;
  /** Ends the current word. */
  const endWord = (): void => {
    if (word !== "" || quoted) words.push({ text: word, quoted, lead: lead ?? word });
    word = "";
    quoted = false;
    lead = null;
  };
  /** Ends the current part. */
  const endPart = (): void => {
    endWord();
    if (words.length) result.push(words);
    words = [];
  };
  for (let i = 0; i < text.length; i++) {
    const ch = text[i]!;
    const next = text[i + 1] ?? "";
    if (quote) {
      // `\"` escapes a quote in Bash; in PowerShell a backslash is a path's ("$env:TEMP\x\"):
      // after a backslash path in the string, or before a separator, it ends the string.
      const after = text[i + 2] ?? "";
      const pathEnd = /\\|\$env:/i.test(word) || after === "" || /[\s;|)]/.test(after);
      if (ch === "\\" && quote === '"' && next === '"' && !pathEnd) {
        word += '"';
        i++;
      } else if (ch === quote) {
        quote = null;
      } else {
        word += ch;
      }
      continue;
    }
    if (ch === '"' || ch === "'") {
      if (lead === null) lead = word;
      quote = ch;
      quoted = true;
      continue;
    }
    // `${name}`, `${#arr[@]}`: a variable, part of the word (not a block).
    if (ch === "{" && text[i - 1] === "$") {
      varBraces++;
      word += ch;
      continue;
    }
    if (ch === "}" && varBraces > 0) {
      varBraces--;
      word += ch;
      continue;
    }
    // Bash's `'\''` (a quote inside a single-quoted text): an escaped quote outside quotes.
    if (ch === "\\" && (next === "'" || next === '"')) {
      if (lead === null) lead = word;
      word += next;
      quoted = true;
      i++;
      continue;
    }
    // A comment runs to the line end (`#` at the start of a word).
    if (ch === "#" && word === "") {
      while (i + 1 < text.length && text[i + 1] !== "\n") i++;
      continue;
    }
    if (ch === " " || ch === "\t" || ch === "\r") {
      endWord();
      continue;
    }
    if (ch === "\n" || ch === ";" || ch === "{" || ch === "}" || ch === "(" || ch === ")") {
      endPart();
      continue;
    }
    if (ch === "|") {
      endPart();
      if (next === "|") i++;
      continue;
    }
    if (ch === "&") {
      if (next === "&") {
        endPart();
        i++;
        continue;
      }
      // `2>&1`, `*>&1`: part of a redirection.
      if (text[i - 1] === ">") {
        word += ch;
        continue;
      }
      // At the start of a part the call operator; after words a background `&`.
      if (words.length === 0 && word === "") {
        words.push({ text: "&", quoted: false, lead: "&" });
        continue;
      }
      endPart();
      continue;
    }
    word += ch;
  }
  endPart();
  return result;
}

/**
 * The programs a shell command runs, in lower case: the program of every part with what it
 * runs - the script of `powershell -File`, of `python` (or `-m <module>`), of `node` and `bash`;
 * the subcommand of `npm`, `npx` and `git`; and the commands of `cmd /c "…"`,
 * `powershell -Command "…"` and `bash -c "…"`, read in turn.
 *
 * @param command - The command line.
 * @param depth - Nesting of launchers (internal).
 * @returns Program names (`build.cmd`, `saltests.exe`, `npm check`, `git commit`,
 *   `-m translate.merge`, `run_on_hidden_desktop.ps1`, ...).
 */
export function programsOf(command: string, depth = 0): string[] {
  if (depth > 3) return [];
  const text = withoutHeredocs(command.replace(/\\\r?\n/g, " ").replace(/`\r?\n/g, " "));
  const found: string[] = [];
  // Variables the command sets (`BL="python tools/backlog/backlog.py"`, `$BL = '…'`): a `$BL`
  // in a program's place runs its value (review 5 of 415: the runs' usual backlog form).
  const vars = new Map<string, string>();
  for (const words of parts(text)) {
    let i = 0;
    let assignedTo: string | null = null;
    // Assignments, prefixes and launchers before the program.
    let assigned = false;
    let called = false;
    for (;;) {
      const w = words[i];
      if (!w) break;
      const t = w.text;
      const lower = t.toLowerCase();
      const name = /^([A-Za-z_]\w*)=/.exec(w.lead);
      if (name) {
        vars.set(name[1]!.toLowerCase(), t.slice(name[0].length));
        i++;
      } else if (!w.quoted && /^\$[\w:]+$/.test(t) && /^[+\-*/]?=$/.test(words[i + 1]?.text ?? "")) {
        assignedTo = t.slice(1).toLowerCase();
        i += 2;
        assigned = true;
      } else if (!w.quoted && /^\$[\w:]+[+\-*/]?=$/.test(t)) {
        assignedTo = t
          .slice(1)
          .replace(/[+\-*/]?=$/, "")
          .toLowerCase();
        i++;
        assigned = true;
      } else if (!w.quoted && PREFIXES.has(lower)) {
        if (lower === "&" || lower === ".") called = true;
        i++;
      } else if (lower === "timeout" && /^\d+[smh]?$/.test(words[i + 1]?.text ?? "")) i += 2;
      else break;
    }
    const first = words[i];
    if (!first) continue;
    // `$m = "a; .\\build.cmd"` assigns a text; only `& "…"` runs a quoted path after `=`.
    if (assigned && first.quoted && !called) {
      if (assignedTo && words.length === i + 1) vars.set(assignedTo, first.text);
      continue;
    }
    const variable = /^\$\{?([A-Za-z_]\w*)\}?$/.exec(first.text);
    const value = variable ? vars.get(variable[1]!.toLowerCase()) : undefined;
    if (value !== undefined) {
      const rest = words.slice(i + 1).map((w) => (w.quoted ? `"${w.text}"` : w.text));
      found.push(...programsOf([value, ...rest].join(" "), depth + 1));
      continue;
    }
    const prog = programName(first.text);
    if (KEYWORDS.has(prog)) continue;
    const rest = words.slice(i + 1);
    if (prog === "cmd" || prog === "cmd.exe") {
      const at = rest.findIndex((w) => /^\/\/?[ck]$/i.test(w.text));
      if (at >= 0)
        found.push(
          ...programsOf(
            rest
              .slice(at + 1)
              // `cmd /c "build.cmd full" 2>&1`: the quoted first word is itself a command line.
              .map((w, k) => (k === 0 || !w.quoted ? w.text : `"${w.text}"`))
              .join(" "),
            depth + 1,
          ),
        );
      else found.push(prog);
      continue;
    }
    if (prog === "start-process" || prog === "saps" || prog === "start") {
      let j = 0;
      while (j < rest.length && rest[j]!.text.startsWith("-") && !/^-filepath$/i.test(rest[j]!.text)) j++;
      if (rest[j] && /^-filepath$/i.test(rest[j]!.text)) j++;
      const target = rest[j];
      if (target) found.push(...programsOf(target.quoted ? `"${target.text}"` : target.text, depth + 1));
      continue;
    }
    found.push(prog);
    // The backlog tool's subcommand (`backlog block`, `backlog lock acquire`): phases and labels.
    const tool = [prog, ...words.slice(i + 1, i + 3).map((w) => programName(w.text))].findIndex((n) =>
      /^backlog\.(sh|py)$/.test(n),
    );
    if (tool >= 0) {
      const after = words.slice(i + 1 + tool);
      let j = 0;
      while (j < after.length && after[j]!.text.startsWith("-"))
        j += /^(--root|--input-json)$/.test(after[j]!.text) ? 2 : 1;
      const sub = after[j]?.text.toLowerCase();
      if (sub && /^[a-z-]+$/.test(sub)) {
        found.push(`backlog ${sub}`);
        const second = after[j + 1]?.text.toLowerCase();
        if (sub === "lock" && second) found.push(`backlog lock ${second}`);
      }
    }
    if (/^(powershell|pwsh)(\.exe)?$/.test(prog)) {
      const file = rest.findIndex((w) => /^-file$/i.test(w.text));
      if (file >= 0 && rest[file + 1]) found.push(programName(rest[file + 1]!.text));
      const inline = rest.findIndex((w) => /^-(command|c)$/i.test(w.text));
      if (inline >= 0) {
        const body = rest.slice(inline + 1);
        found.push(
          ...programsOf(body.length === 1 ? body[0]!.text : body.map((w) => w.text).join(" "), depth + 1),
        );
      }
    } else if (/^(bash|sh)(\.exe)?$/.test(prog)) {
      const inline = rest.findIndex((w) => w.text === "-c");
      if (inline >= 0 && rest[inline + 1]) found.push(...programsOf(rest[inline + 1]!.text, depth + 1));
      else {
        const script = rest.find((w) => !w.text.startsWith("-"));
        if (script) found.push(programName(script.text));
      }
    } else if (/^python[\d.]*(\.exe)?$|^py(\.exe)?$/.test(prog)) {
      const m = rest.findIndex((w) => w.text === "-m");
      if (m >= 0 && rest[m + 1]) found.push(`-m ${rest[m + 1]!.text.toLowerCase()}`);
      else if (!rest.some((w) => w.text === "-c")) {
        const script = rest.find((w) => /\.py$/i.test(w.text));
        if (script) found.push(programName(script.text));
      }
    } else if (/^node(\.exe)?$/.test(prog)) {
      const script = rest.find((w) => !w.text.startsWith("-"));
      if (script) found.push(programName(script.text));
    } else if (prog === "npm" || prog === "npx" || prog === "npm.cmd" || prog === "npx.cmd") {
      const base = prog.replace(/\.cmd$/, "");
      let j = 0;
      while (j < rest.length && rest[j]!.text.startsWith("-"))
        j += /^(--prefix|-w|--workspace|-C|--package|-p)$/.test(rest[j]!.text) ? 2 : 1;
      let sub = rest[j]?.text;
      if (base === "npm" && (sub === "run" || sub === "run-script")) {
        j++;
        while (j < rest.length && rest[j]!.text.startsWith("-"))
          j += /^(--prefix|-w|--workspace)$/.test(rest[j]!.text) ? 2 : 1;
        sub = rest[j]?.text;
      }
      if (sub) found.push(`${base} ${sub.toLowerCase()}`);
    } else if (prog === "git" || prog === "git.exe") {
      let j = 0;
      while (j < rest.length && rest[j]!.text.startsWith("-"))
        j += rest[j]!.text === "-C" || rest[j]!.text === "-c" ? 2 : 1;
      if (rest[j]) found.push(`git ${rest[j]!.text.toLowerCase()}`);
    }
  }
  return found;
}

/** Programs of a build. */
const BUILDS = ["build.cmd", "rebuild.cmd", "build_langs.cmd", "msbuild", "msbuild.exe"];

/** npm and npx commands that run tests. */
const TEST_RUNNERS = new Set([
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
]);

/**
 * The checks a command runs, for judging and resolving: a later pass resolves only failures of a
 * check it ran too (the same probe script, the same test files, the build, saltests).
 *
 * @param command - The command line.
 * @returns The checks, e.g. `build`, `saltests`, `encoding`, `probe:find_sort_probe`,
 *   `tests:check`.
 */
export function checkSubjects(command: string): string[] {
  const progs = programsOf(command);
  const checks: string[] = [];
  if (progs.some((p) => BUILDS.includes(p))) checks.push("build");
  if (progs.includes("saltests.exe")) checks.push("saltests");
  if (progs.includes("check_encoding.py")) checks.push("encoding");
  if (progs.includes("run_on_hidden_desktop.ps1")) {
    const scripts = [...command.matchAll(/([\w.-]+)\.ps1\b/gi)]
      .map((m) => m[1]!.toLowerCase())
      .filter((n) => n !== "run_on_hidden_desktop");
    checks.push(`probe:${[...new Set(scripts)].sort().join(",") || "?"}`);
  }
  const tests = progs.filter((p) => TEST_RUNNERS.has(p) || /^test_[\w-]+\.py$/.test(p));
  if (tests.length) {
    const files = [...command.matchAll(/([\w.-]+\.(?:spec|test)\.[jt]sx?)/g)].map((m) => m[1]!);
    checks.push(`tests:${files.length ? [...new Set(files)].sort().join(",") : tests.join(",")}`);
  }
  return checks;
}
