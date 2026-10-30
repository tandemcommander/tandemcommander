// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The change tray (research R11; FR-034, FR-035): every change the app made, uncommitted
 * until the maintainer commits it, with an undo of the newest changes.
 *
 * - Before an operation, the files under `backlog/` are read into memory (a snapshot; the backlog
 *   is a few megabytes and nothing else writes while the gate is open). The tool reports which
 *   files it wrote or deleted (`written`); their before-bytes are kept in the state folder, so an
 *   undo restores exactly what was there - also a closed item's `evidence/` files.
 * - An undo is allowed for the newest pending change only, and only while every file still has
 *   the content the change left (nothing else changed it since).
 * - A commit stages exactly the tray's paths under `backlog/` (plus outside changes the maintainer
 *   ticked) on `main`, with a message in the repository's style. The prefix `backlog(app):` keeps
 *   the commit from being attributed to a run (`traces.py` matches `[NNN]`, `backlog: <slug> ` and
 *   `backlog: auto-triage`, analysis A1 §7). Nothing is pushed.
 */

import { createHash, randomBytes } from "node:crypto";
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { z } from "zod";
import { ApiError, ChangeSchema, type Change, type Tray } from "@backlog-app/shared";
import type { ServerContext } from "../context.ts";
import { runProcess } from "../proc/spawn.ts";
import type { BacklogTool, ToolChange } from "./tool.ts";
import { GIT_TIMEOUT_MS, statusEntries } from "../repo/git.ts";

/** The tray file in the state folder. */
const TRAY_FILE = "tray.json";

/** Days after which committed and undone entries are dropped. */
const KEEP_DAYS = 7;

/** The stored before-bytes of one change. */
const UndoFileSchema = z.array(z.object({ path: z.string(), before: z.string().nullable() }));

/**
 * The SHA-256 of bytes.
 *
 * @param bytes - The content.
 * @returns The hex digest.
 */
function sha256(bytes: Buffer): string {
  return createHash("sha256").update(bytes).digest("hex");
}

/**
 * True for a `/`-separated path inside `backlog/` without empty, `.` or `..` segments and without
 * a backslash or a drive colon (so it cannot leave the folder whatever the platform).
 *
 * @param path - Repository-relative path.
 * @returns True when the path stays inside `backlog/`.
 */
export function isBacklogPath(path: string): boolean {
  const parts = path.split("/");
  return (
    parts[0] === "backlog" &&
    parts.length > 1 &&
    parts.every((p) => p !== "" && p !== "." && p !== ".." && !p.includes("\\") && !p.includes(":"))
  );
}

/**
 * Runs one changing tool command for the tray. If the command fails after it wrote something (a
 * crash, the time limit; a refusal writes nothing by the tool's contract), the files it changed
 * are recorded as a change marked "failed partway", so they can be undone or committed knowingly
 * instead of turning up as unexplained outside changes (review S3); then the error is rethrown.
 *
 * @param tray - The tray.
 * @param tool - The backlog tool.
 * @param args - The command.
 * @param texts - The user's texts for stdin.
 * @param failed - How to record a partial write.
 * @returns The tool's result and the snapshot taken before (for {@link ChangeTray.record}).
 */
export async function toolChangeForTray(
  tray: ChangeTray,
  tool: BacklogTool,
  args: string[],
  texts: Record<string, unknown>,
  failed: Pick<Change, "operation" | "slugs" | "summary" | "reason">,
): Promise<{ result: ToolChange; before: Snapshot }> {
  const before = tray.snapshot();
  try {
    return { result: await tool.change(args, texts), before };
  } catch (error) {
    const written = tray.changedSince(before);
    if (written.length > 0) {
      tray.record({
        ...failed,
        summary: `${failed.summary} (failed partway - check before committing)`,
        before,
        written,
      });
    }
    throw error;
  }
}

/** A snapshot of the `backlog/` folder: bytes by repository-relative path. */
export type Snapshot = Map<string, Buffer>;

/** The change tray of one repository. */
export class ChangeTray {
  /** The server context. */
  private readonly ctx: ServerContext;

  /** The last refresh of the counters (its `git status` may still run). */
  private counting: Promise<void> = Promise.resolve();

  /**
   * Creates the tray.
   *
   * @param ctx - The server context.
   */
  constructor(ctx: ServerContext) {
    this.ctx = ctx;
  }

  /**
   * Every entry, oldest first (pending, committed and undone).
   *
   * @returns The entries.
   */
  entries(): Change[] {
    return this.ctx.state.readJson(TRAY_FILE, z.array(ChangeSchema), []);
  }

  /**
   * The pending changes, oldest first.
   *
   * @returns The changes.
   */
  pending(): Change[] {
    return this.entries().filter((c) => c.state === "pending");
  }

  /**
   * Stores the entries, dropping old committed and undone ones.
   *
   * @param entries - The entries.
   */
  private save(entries: Change[]): void {
    const cutoff = Date.now() - KEEP_DAYS * 86_400_000;
    const kept = entries.filter((c) => c.state === "pending" || Date.parse(c.at) > cutoff);
    for (const dropped of entries.filter((c) => !kept.includes(c)))
      this.ctx.state.remove(`undo/${dropped.id}.json`);
    this.ctx.state.writeJson(TRAY_FILE, kept);
    void this.publishCounts();
  }

  /**
   * Tells every tab the tray's counters. The outside count needs `git status`, so the event goes
   * out once it is known; a failing git leaves it at 0 rather than holding the event back.
   *
   * @returns Resolves once the event is published.
   */
  publishCounts(): Promise<void> {
    const counting = (async () => {
      const outside = await this.outside().catch(() => []);
      this.ctx.hub.publish("tray.changed", { pending: this.pending().length, outside: outside.length });
    })();
    // Remember the last one so a shutdown can wait for its `git status` (stopAndDrain).
    this.counting = counting;
    return counting;
  }

  /**
   * Resolves once the last counter refresh finished (no `git status` of the tray runs any more).
   *
   * @returns Resolves when idle.
   */
  async idle(): Promise<void> {
    await this.counting;
  }

  /**
   * Reads every file under `backlog/` (the state before an operation).
   *
   * @returns The snapshot.
   */
  snapshot(): Snapshot {
    const root = this.ctx.repo.root;
    const files: Snapshot = new Map();
    /**
     * Adds the files of one folder, recursively.
     *
     * @param dir - Absolute folder path.
     */
    const add = (dir: string): void => {
      for (const name of readdirSync(dir)) {
        const path = join(dir, name);
        if (statSync(path).isDirectory()) add(path);
        else files.set(relative(root, path).replaceAll("\\", "/"), readFileSync(path));
      }
    };
    add(join(root, "backlog"));
    return files;
  }

  /**
   * The files under `backlog/` that differ from a snapshot (changed, created or deleted) - for a
   * tool call that failed after writing, or was killed by its time limit partway (review S3): its
   * report of written files is missing, so the folder itself is compared.
   *
   * @param before - The snapshot taken before the call.
   * @returns Repository-relative paths.
   */
  changedSince(before: Snapshot): string[] {
    const now = this.snapshot();
    const changed: string[] = [];
    for (const [path, bytes] of now) {
      const old = before.get(path);
      if (!old || !old.equals(bytes)) changed.push(path);
    }
    for (const path of before.keys()) if (!now.has(path)) changed.push(path);
    return changed;
  }

  /**
   * Records a change after the tool wrote it.
   *
   * @param input - What happened: operation, items, one-line summary, reason, the snapshot taken
   *   before, and the files the tool wrote or deleted.
   * @returns The new tray entry.
   */
  record(input: {
    /** The operation. */
    operation: Change["operation"];
    /** The items it concerned. */
    slugs: string[];
    /** One line for the tray and the commit message. */
    summary: string;
    /** The maintainer's reason. */
    reason: string | null;
    /** The snapshot taken before the operation. */
    before: Snapshot;
    /** Files the tool wrote or deleted (repository-relative). */
    written: string[];
  }): Change {
    const root = this.ctx.repo.root;
    // Time first, so ids sort by creation; the random part keeps two changes of one millisecond
    // apart. The id also names the undo file, so it holds only [0-9a-z-].
    const id = `${Date.now().toString(36)}-${randomBytes(3).toString("hex")}`;
    const undo: z.infer<typeof UndoFileSchema> = [];
    const files: Change["files"] = [];
    // Only the files the tool reports are kept, not the whole snapshot: a change touches a handful
    // of files, the snapshot is the whole folder.
    for (const path of [...new Set(input.written)].filter(isBacklogPath)) {
      // No before-bytes = the change created the file; undo deletes it.
      const old = input.before.get(path) ?? null;
      let now: Buffer | null;
      try {
        now = readFileSync(join(root, ...path.split("/")));
      } catch {
        now = null;
      }
      undo.push({ path, before: old ? old.toString("base64") : null });
      files.push({ path, before: old ? sha256(old) : null, after: now ? sha256(now) : null });
    }
    this.ctx.state.writeJson(`undo/${id}.json`, undo);
    const change: Change = {
      id,
      at: new Date().toISOString(),
      operation: input.operation,
      slugs: input.slugs,
      summary: input.summary,
      reason: input.reason,
      files,
      state: "pending",
      commit: null,
    };
    this.save([...this.entries(), change]);
    return change;
  }

  /**
   * Undoes the newest pending change (call it inside the write queue).
   *
   * @param changeId - The change; must be the newest pending one.
   * @returns The undone change.
   * @throws ApiError `refused` when it is not the newest or a file changed since.
   */
  undo(changeId: string): Change {
    const entries = this.entries();
    const pending = entries.filter((c) => c.state === "pending");
    const change = pending.at(-1);
    if (!change || change.id !== changeId) {
      throw new ApiError(
        "refused",
        "only the newest uncommitted change can be undone - undo the newer ones first",
      );
    }
    const root = this.ctx.repo.root;
    // Check every file before restoring any: an undo is all or nothing. A file whose content is not
    // what this change left was changed since (a terminal, Claude Code, the loop) - restoring it
    // would silently drop that later edit.
    for (const file of change.files) {
      let now: Buffer | null;
      try {
        now = readFileSync(join(root, ...file.path.split("/")));
      } catch {
        now = null;
      }
      const hash = now ? sha256(now) : null;
      if (hash !== file.after) {
        throw new ApiError(
          "refused",
          `${file.path} changed after this change (by something else) - it cannot be undone safely`,
        );
      }
    }
    // The undo file must exist and describe exactly this change's files, each under `backlog/`:
    // a missing or damaged file would "undo" nothing yet drop the change from the tray (review
    // S2), and a file edited by someone else must not make the app write elsewhere (review M2).
    const undo = this.ctx.state.readJson(`undo/${change.id}.json`, UndoFileSchema.nullable(), null);
    const expected = new Set(change.files.map((f) => f.path));
    if (
      !undo ||
      undo.length !== expected.size ||
      undo.some((f) => !expected.has(f.path) || !isBacklogPath(f.path))
    ) {
      throw new ApiError(
        "refused",
        "the saved state of this change is missing or damaged - it cannot be undone; restore the files with git",
      );
    }
    for (const file of undo) {
      const target = join(root, ...file.path.split("/"));
      if (file.before === null) {
        rmSync(target, { force: true });
      } else {
        mkdirSync(dirname(target), { recursive: true });
        writeFileSync(target, Buffer.from(file.before, "base64"));
      }
    }
    // A new item's folder is left empty after its files were removed; remove it too.
    for (const file of undo.filter((f) => f.before === null)) {
      const folder = dirname(join(root, ...file.path.split("/")));
      try {
        if (readdirSync(folder).length === 0) rmSync(folder, { recursive: true, force: true });
      } catch {
        // Already gone.
      }
    }
    change.state = "undone";
    this.save(entries);
    return change;
  }

  /**
   * Dirty paths under `backlog/` that no pending change explains (changed by a terminal or Claude
   * Code); they are committed only when the maintainer ticks them.
   *
   * @returns The paths.
   */
  async outside(): Promise<string[]> {
    const ours = new Set(this.pending().flatMap((c) => c.files.map((f) => f.path)));
    const dirty = await statusEntries(this.ctx.repo.root, ["backlog"]);
    return dirty.map((e) => e.path).filter((p) => !ours.has(p));
  }

  /**
   * The commit message the app proposes: subject `backlog(app): ...`, one body line per change,
   * and the reasons of closes (they are recorded nowhere else).
   *
   * @returns The message.
   */
  proposedMessage(): string {
    const pending = this.pending();
    if (pending.length === 0) return "";
    const counts = new Map<string, number>();
    for (const change of pending) counts.set(change.operation, (counts.get(change.operation) ?? 0) + 1);
    const parts = [...counts].map(([op, n]) =>
      n > 1 ? `${n} x ${op}` : pending.find((c) => c.operation === op)!.summary,
    );
    let subject = `backlog(app): ${parts.join("; ")}`;
    if (subject.length > 72)
      subject = `backlog(app): ${pending.length} changes (${[...counts.keys()].join(", ")})`;
    const body = pending.map((c) => `- ${c.summary}${c.reason ? ` - ${c.reason}` : ""}`);
    return `${subject}\n\n${body.join("\n")}\n`;
  }

  /**
   * The tray as the client sees it.
   *
   * @returns Pending changes, outside changes and the proposed message.
   */
  async view(): Promise<Tray> {
    return {
      pending: this.pending(),
      outside: await this.outside(),
      proposedMessage: this.proposedMessage(),
    };
  }

  /**
   * Commits the pending changes on `main` (call it inside the write queue, gate open).
   *
   * @param message - The commit message.
   * @param includeOutside - Outside paths the maintainer ticked.
   * @returns The commit hash.
   * @throws ApiError `refused` when nothing is pending, something else is staged, or git fails.
   */
  async commit(message: string, includeOutside: string[]): Promise<string> {
    const root = this.ctx.repo.root;
    const entries = this.entries();
    const pending = entries.filter((c) => c.state === "pending");
    const outside = new Set(await this.outside());
    const extra = includeOutside.filter((p) => outside.has(p));
    // Ticked outside paths count only when they are still outside changes now (the client may send
    // a stale list), and nothing outside `backlog/` is ever staged by the app.
    const paths = [...new Set([...pending.flatMap((c) => c.files.map((f) => f.path)), ...extra])].filter(
      isBacklogPath,
    );
    if (paths.length === 0) throw new ApiError("refused", "there is nothing to commit");
    // A tray file must still hold what the app's newest change of it left: an edit made outside
    // the app afterwards would otherwise be committed under the app's message (review note).
    const expected = new Map<string, string | null>();
    for (const change of pending) for (const file of change.files) expected.set(file.path, file.after);
    for (const [path, after] of expected) {
      let now: Buffer | null;
      try {
        now = readFileSync(join(root, ...path.split("/")));
      } catch {
        now = null;
      }
      if ((now ? sha256(now) : null) !== after) {
        throw new ApiError(
          "refused",
          `${path} was changed outside the app after the app changed it - commit it in a terminal, or put back the app's version first`,
        );
      }
    }
    // Never sweep in what someone else staged.
    const staged = await runProcess("git", ["diff", "--cached", "--name-only"], {
      cwd: root,
      timeoutMs: GIT_TIMEOUT_MS,
    });
    if (staged.stdout.trim()) {
      throw new ApiError(
        "refused",
        `other files are already staged - commit or unstage them in the terminal first:\n${staged.stdout.trim()}`,
      );
    }
    // A path that is neither on disk nor known to git (created and deleted again by two pending
    // changes) has nothing to commit, and git would refuse the whole pathspec for it.
    const tracked = await runProcess("git", ["ls-files", "-z", "--", ...paths], {
      cwd: root,
      timeoutMs: GIT_TIMEOUT_MS,
    });
    const known = new Set(tracked.stdout.split("\0").filter(Boolean));
    const committable = paths.filter((p) => known.has(p) || existsSync(join(root, ...p.split("/"))));
    if (committable.length === 0) throw new ApiError("refused", "there is nothing to commit");
    paths.splice(0, paths.length, ...committable);
    const add = await runProcess("git", ["add", "-A", "--", ...paths], {
      cwd: root,
      timeoutMs: GIT_TIMEOUT_MS,
    });
    if (add.code !== 0) throw new ApiError("refused", `git add failed: ${add.stderr.trim()}`);
    // The message goes on stdin (`-F -`), never on the command line. The pathspec limits the
    // commit to these paths even if something was staged between the check above and now.
    const commit = await runProcess("git", ["commit", "-q", "-F", "-", "--", ...paths], {
      cwd: root,
      // Commit hooks may run here; they get twice the usual limit.
      timeoutMs: 2 * GIT_TIMEOUT_MS,
      stdin: message.endsWith("\n") ? message : `${message}\n`,
    });
    if (commit.code !== 0) {
      // Unstage again (a failing hook, no identity): the index is left as it was, the files keep
      // their content and the changes stay pending.
      await runProcess("git", ["reset", "-q", "--", ...paths], { cwd: root, timeoutMs: GIT_TIMEOUT_MS });
      throw new ApiError("refused", `git commit failed: ${(commit.stderr || commit.stdout).trim()}`);
    }
    const hash = (
      await runProcess("git", ["rev-parse", "HEAD"], { cwd: root, timeoutMs: GIT_TIMEOUT_MS })
    ).stdout.trim();
    for (const change of pending) {
      change.state = "committed";
      change.commit = hash;
      this.ctx.state.remove(`undo/${change.id}.json`);
    }
    this.save(entries);
    return hash;
  }
}
