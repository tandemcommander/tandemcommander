// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The only module of the application that starts processes (research R7).
 *
 * Rules it enforces for every child:
 * - an absolute executable and an argument array, never a shell (`shell: false`); `cmd.exe`,
 *   `.cmd` and `.bat` are never started, so no text is ever interpreted by a command processor;
 * - user text never travels on a command line: it is written to the child's stdin as JSON (the
 *   backlog tool's `--input-json -`), so it is not limited by the Windows command-line length,
 *   cannot be mistaken for an option and is not visible in process listings;
 * - UTF-8 in both directions (`PYTHONUTF8`, `PYTHONIOENCODING`, `StringDecoder`);
 * - stdin is closed unless something is written to it - an inherited pipe stdin stalled Python
 *   children in the measurements of analysis A2 §2.2;
 * - every child is registered, so the server can end the trees of its own children when it shuts
 *   down; the backlog loop is never one of them (it runs in its own console window, research R13).
 */

import { spawn, type ChildProcess } from "node:child_process";
import { existsSync, statSync } from "node:fs";
import { delimiter, isAbsolute, join } from "node:path";
import { StringDecoder } from "node:string_decoder";

/** Options of {@link runProcess} and {@link startProcess}. */
export interface ProcessOptions {
  /** Working directory (always the repository root for the tools). */
  cwd: string;
  /** Text written to stdin and then closed; absent = stdin closed immediately. */
  stdin?: string;
  /** Extra environment variables (merged over the server's environment). */
  env?: Record<string, string>;
  /** Kill the process tree after this many milliseconds (default: no limit). */
  timeoutMs?: number;
  /**
   * The process starts something that must outlive it and the app - the loop in its own console
   * window, which Windows records as its child: a timeout or the app's shutdown ends only this
   * process, never its descendants (review note: `taskkill /T` killed a loop being started).
   */
  keepDescendants?: boolean;
  /** Called with each complete stdout line as it arrives (streams, AI jobs). */
  onStdoutLine?: (line: string) => void;
}

/** The outcome of a finished process. */
export interface ProcessResult {
  /** Exit code, or null when the process was killed by a signal. */
  code: number | null;
  /** Everything written to stdout, decoded as UTF-8. */
  stdout: string;
  /** Everything written to stderr, decoded as UTF-8. */
  stderr: string;
  /** True when the timeout killed the process. */
  timedOut: boolean;
}

/** A started process and the promise of its result. */
export interface StartedProcess {
  /** The Node child handle. */
  child: ChildProcess;
  /** Resolves when the process has exited and its output is complete. */
  done: Promise<ProcessResult>;
}

/** Process ids of the children this server started and that are still running. */
const liveChildren = new Set<number>();

/** The live children whose descendants must survive them ({@link ProcessOptions.keepDescendants}). */
const keepDescendantsOf = new Set<number>();

/** Cache of resolved executables by name. */
const resolved = new Map<string, string>();

/**
 * Finds an executable on `PATH` the way Windows does for a bare name (`PATHEXT` order), so that
 * the child is started by absolute path and no command processor is involved.
 *
 * @param name - A bare program name (`git`, `python`) or an absolute path.
 * @returns The absolute path of the executable.
 * @throws Error when it cannot be found.
 */
export function resolveExecutable(name: string): string {
  const cached = resolved.get(name);
  if (cached) return cached;
  if (isAbsolute(name)) {
    if (!existsSync(name)) throw new Error(`executable not found: ${name}`);
    resolved.set(name, name);
    return name;
  }
  // Only real executables: .cmd / .bat would need cmd.exe and are refused by Node anyway.
  const extensions = [".exe", ".com"];
  for (const dir of (process.env["PATH"] ?? "").split(delimiter)) {
    if (!dir) continue;
    for (const ext of name.toLowerCase().endsWith(".exe") ? [""] : extensions) {
      const candidate = join(dir, name + ext);
      // The Microsoft Store alias `WindowsApps\python.exe` is a zero-byte reparse point that opens
      // the Store instead of running Python; skip it so a real installation is found.
      if (
        existsSync(candidate) &&
        !(dir.toLowerCase().includes("windowsapps") && statSync(candidate).size === 0)
      ) {
        resolved.set(name, candidate);
        return candidate;
      }
    }
  }
  throw new Error(`executable not found on PATH: ${name}`);
}

/**
 * The Python interpreter the backlog tools run with: `PYTHON` like the `bin/` scripts, else
 * `python` from `PATH`.
 *
 * @returns The absolute path of the interpreter.
 */
export function pythonExecutable(): string {
  return resolveExecutable(process.env["PYTHON"] ?? "python");
}

/**
 * The environment every child gets: the server's own plus UTF-8 settings for Python.
 *
 * @param extra - Variables to add or override.
 * @returns The merged environment.
 */
function childEnvironment(extra: Record<string, string> | undefined): NodeJS.ProcessEnv {
  return {
    ...process.env,
    PYTHONUTF8: "1",
    PYTHONIOENCODING: "utf-8",
    // Git must never wait for an editor or a pager and must not take optional index locks
    // (a run may be using the repository at the same time, analysis A2 §5.2).
    GIT_TERMINAL_PROMPT: "0",
    GIT_PAGER: "cat",
    GIT_OPTIONAL_LOCKS: "0",
    ...extra,
  };
}

/**
 * Starts a process and returns its handle and the promise of its result.
 *
 * @param file - Executable (bare name or absolute path; resolved through {@link resolveExecutable}).
 * @param args - Arguments; passed as an array, never through a shell.
 * @param options - Working directory, stdin text, environment, timeout, line callback.
 * @returns The started process.
 */
export function startProcess(file: string, args: readonly string[], options: ProcessOptions): StartedProcess {
  const executable = resolveExecutable(file);
  const child = spawn(executable, args, {
    cwd: options.cwd,
    env: childEnvironment(options.env),
    windowsHide: true,
    stdio: [options.stdin === undefined ? "ignore" : "pipe", "pipe", "pipe"],
  });
  if (child.pid !== undefined) {
    liveChildren.add(child.pid);
    if (options.keepDescendants) keepDescendantsOf.add(child.pid);
  }

  const done = new Promise<ProcessResult>((resolve, reject) => {
    // Decoders keep a multi-byte character that is split between two chunks intact.
    const outDecoder = new StringDecoder("utf8");
    const errDecoder = new StringDecoder("utf8");
    let stdout = "";
    let stderr = "";
    let pendingLine = "";
    let timedOut = false;

    /**
     * Appends decoded stdout text and reports every completed line to the callback.
     *
     * @param text - Newly decoded text.
     */
    const takeStdout = (text: string): void => {
      stdout += text;
      if (!options.onStdoutLine) return;
      pendingLine += text;
      let newline = pendingLine.indexOf("\n");
      while (newline >= 0) {
        options.onStdoutLine(pendingLine.slice(0, newline).replace(/\r$/, ""));
        pendingLine = pendingLine.slice(newline + 1);
        newline = pendingLine.indexOf("\n");
      }
    };

    child.stdout?.on("data", (chunk: Buffer) => takeStdout(outDecoder.write(chunk)));
    child.stderr?.on("data", (chunk: Buffer) => {
      stderr += errDecoder.write(chunk);
    });

    const timer =
      options.timeoutMs === undefined
        ? undefined
        : setTimeout(() => {
            timedOut = true;
            if (child.pid !== undefined) void killTree(child.pid, !options.keepDescendants);
          }, options.timeoutMs);

    child.on("error", (error) => {
      if (timer) clearTimeout(timer);
      if (child.pid !== undefined) forget(child.pid);
      reject(error);
    });
    child.on("close", (code) => {
      if (timer) clearTimeout(timer);
      if (child.pid !== undefined) forget(child.pid);
      takeStdout(outDecoder.end());
      stderr += errDecoder.end();
      if (options.onStdoutLine && pendingLine) options.onStdoutLine(pendingLine);
      resolve({ code, stdout, stderr, timedOut });
    });
  });

  if (options.stdin !== undefined && child.stdin) {
    // An early exit of the child closes the pipe; that is reported through `close`, not here.
    child.stdin.on("error", () => undefined);
    child.stdin.end(options.stdin, "utf8");
  }
  return { child, done };
}

/**
 * Runs a process to completion.
 *
 * @param file - Executable.
 * @param args - Arguments (an array; never a shell).
 * @param options - See {@link ProcessOptions}.
 * @returns The exit code and the decoded output.
 */
export async function runProcess(
  file: string,
  args: readonly string[],
  options: ProcessOptions,
): Promise<ProcessResult> {
  return startProcess(file, args, options).done;
}

/**
 * Ends a process and all its descendants with `taskkill /T /F` (the same mechanism the loop uses
 * for claude). Called by full path because Git's tools shadow System32 names on `PATH` (memory
 * rule *Git tools shadow System32*).
 *
 * @param pid - The root process of the tree.
 * @param tree - False ends only the process itself (`/T` left out).
 * @returns Resolves when taskkill has finished; failures (the process is already gone) are ignored.
 */
export async function killTree(pid: number, tree = true): Promise<void> {
  const systemRoot = process.env["SystemRoot"] ?? "C:\\Windows";
  const taskkill = join(systemRoot, "System32", "taskkill.exe");
  await new Promise<void>((resolve) => {
    const child = spawn(taskkill, ["/PID", String(pid), ...(tree ? ["/T"] : []), "/F"], {
      windowsHide: true,
      stdio: "ignore",
    });
    child.on("error", () => resolve());
    child.on("close", () => resolve());
  });
}

/**
 * Ends the trees of every child this server started that is still running (at shutdown).
 *
 * @returns Resolves when all have been asked to end.
 */
export async function killAllChildren(): Promise<void> {
  await Promise.all([...liveChildren].map((pid) => killTree(pid, !keepDescendantsOf.has(pid))));
  liveChildren.clear();
  keepDescendantsOf.clear();
}

/**
 * Drops a finished child from the bookkeeping.
 *
 * @param pid - Its process id.
 */
function forget(pid: number): void {
  liveChildren.delete(pid);
  keepDescendantsOf.delete(pid);
}

/**
 * Process ids of the children that are still running (for tests and diagnostics).
 *
 * @returns A copy of the set of live child pids.
 */
export function liveChildPids(): number[] {
  return [...liveChildren];
}
