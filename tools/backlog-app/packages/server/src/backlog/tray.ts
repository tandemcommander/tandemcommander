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
import { mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { z } from "zod";
import { ApiError, ChangeSchema, type Change, type Tray } from "@backlog-app/shared";
import type { ServerContext } from "../context.ts";
import { runProcess } from "../proc/spawn.ts";
import { statusEntries } from "../repo/git.ts";

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

/** A snapshot of the `backlog/` folder: bytes by repository-relative path. */
export type Snapshot = Map<string, Buffer>;

/** The change tray of one repository. */
export class ChangeTray {
  /** The server context. */
  private readonly ctx: ServerContext;

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
    const outside = 0;
    this.ctx.hub.publish("tray.changed", {
      pending: kept.filter((c) => c.state === "pending").length,
      outside,
    });
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
    const id = `${Date.now().toString(36)}-${randomBytes(3).toString("hex")}`;
    const undo: z.infer<typeof UndoFileSchema> = [];
    const files: Change["files"] = [];
    for (const path of [...new Set(input.written)]) {
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
    const undo = this.ctx.state.readJson(`undo/${change.id}.json`, UndoFileSchema, []);
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
    const paths = [...new Set([...pending.flatMap((c) => c.files.map((f) => f.path)), ...extra])].filter(
      (p) => p.startsWith("backlog/"),
    );
    if (paths.length === 0) throw new ApiError("refused", "there is nothing to commit");
    // Never sweep in what someone else staged.
    const staged = await runProcess("git", ["diff", "--cached", "--name-only"], { cwd: root });
    if (staged.stdout.trim()) {
      throw new ApiError(
        "refused",
        `other files are already staged - commit or unstage them in the terminal first:\n${staged.stdout.trim()}`,
      );
    }
    const add = await runProcess("git", ["add", "-A", "--", ...paths], { cwd: root });
    if (add.code !== 0) throw new ApiError("refused", `git add failed: ${add.stderr.trim()}`);
    // The message goes on stdin (`-F -`), never on the command line.
    const commit = await runProcess("git", ["commit", "-q", "-F", "-"], {
      cwd: root,
      stdin: message.endsWith("\n") ? message : `${message}\n`,
    });
    if (commit.code !== 0) {
      await runProcess("git", ["reset", "-q", "--", ...paths], { cwd: root });
      throw new ApiError("refused", `git commit failed: ${(commit.stderr || commit.stdout).trim()}`);
    }
    const hash = (await runProcess("git", ["rev-parse", "HEAD"], { cwd: root })).stdout.trim();
    for (const change of pending) {
      change.state = "committed";
      change.commit = hash;
      this.ctx.state.remove(`undo/${change.id}.json`);
    }
    this.save(entries);
    return hash;
  }
}
