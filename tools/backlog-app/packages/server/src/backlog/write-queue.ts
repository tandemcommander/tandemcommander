// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The write queue: every change of the backlog, one at a time, under the edit lock and
 * behind a fresh evaluation of the write gate (research R9, R12; FR-023, FR-024).
 *
 * Order of one operation:
 * 1. wait for the previous operation (the tool takes no lock of its own: two changing commands at
 *    once can lose rows, analysis A1 §3);
 * 2. take the edit lock - from now on a resumed loop waits;
 * 3. refresh the loop and repository state and evaluate the gate again; closed = refused;
 * 4. compare the revisions the user's view was based on with the files now (`changed-underneath`);
 * 5. run the operation (the tool), record it in the tray;
 * 6. release the lock, reload the read model, publish the gate.
 */

import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { ApiError } from "@backlog-app/shared";
import type { Services } from "../services.ts";
import { EditLock } from "./edit-lock.ts";

/** The revisions a view was based on. */
export interface Base {
  /** SHA-256 of `BACKLOG.md`. */
  board?: string | undefined;
  /** SHA-256 of the item's `desc.md`. */
  item?: string | undefined;
}

/**
 * The SHA-256 of a file's bytes (open-read-close), or null when it does not exist.
 *
 * @param path - The file.
 * @returns The hex digest or null.
 */
export function fileHash(path: string): string | null {
  try {
    return createHash("sha256").update(readFileSync(path)).digest("hex");
  } catch {
    return null;
  }
}

/** The serial queue of changes. */
export class WriteQueue {
  /** The server's services. */
  private readonly services: Services;

  /** The edit lock. */
  readonly lock: EditLock;

  /** The end of the queue (the last operation's promise). */
  private tail: Promise<unknown> = Promise.resolve();

  /**
   * Creates the queue.
   *
   * @param services - The server's services.
   */
  constructor(services: Services) {
    this.services = services;
    this.lock = new EditLock(services.ctx.repo.commonDir);
  }

  /**
   * Resolves when every queued operation has finished.
   *
   * @returns Resolves when idle.
   */
  async idle(): Promise<void> {
    let tail = this.tail;
    for (;;) {
      await tail;
      if (tail === this.tail) return;
      tail = this.tail;
    }
  }

  /**
   * Runs one operation in the queue.
   *
   * @param purpose - What it changes (written into the edit lock).
   * @param base - The revisions the view was based on, or null for operations without a view.
   * @param slug - The item whose revision `base.item` refers to.
   * @param operation - The change itself.
   * @returns The operation's result.
   */
  run<T>(purpose: string, base: Base | null, slug: string | null, operation: () => Promise<T>): Promise<T> {
    const next = this.tail.then(
      () => this.execute(purpose, base, slug, operation),
      () => this.execute(purpose, base, slug, operation),
    );
    // Keep the chain alive after a failure.
    this.tail = next.catch(() => undefined);
    return next;
  }

  /**
   * One operation (see the file overview for the order).
   *
   * @param purpose - What it changes.
   * @param base - The view's revisions.
   * @param slug - The item of `base.item`.
   * @param operation - The change.
   * @returns The operation's result.
   */
  private async execute<T>(
    purpose: string,
    base: Base | null,
    slug: string | null,
    operation: () => Promise<T>,
  ): Promise<T> {
    this.lock.acquire(purpose);
    try {
      await Promise.all([this.services.loop.fresh(), this.services.repo.fresh()]);
      const gate = this.services.gate();
      if (!gate.writable) throw new ApiError("gate-closed", gate.reason, gate);
      const root = this.services.ctx.repo.root;
      if (base?.board) {
        const now = fileHash(join(root, "backlog", "BACKLOG.md"));
        if (now !== base.board) {
          throw new ApiError(
            "changed-underneath",
            "the backlog changed since this view was loaded - it was reloaded",
            { board: now },
          );
        }
      }
      if (base?.item && slug) {
        const now = fileHash(join(root, "backlog", "items", slug, "desc.md"));
        if (now !== base.item) {
          throw new ApiError(
            "changed-underneath",
            "this item changed since it was loaded - it was reloaded",
            { item: now },
          );
        }
      }
      return await operation();
    } finally {
      // The lock goes first (the loop must not wait for our reading); then the answer waits until
      // the read model shows the change, so the page's next reads are not stale.
      this.lock.release();
      await this.services.read.fresh().catch(() => undefined);
      void this.services.repo.refresh().then(() => this.services.publishGate());
    }
  }
}
