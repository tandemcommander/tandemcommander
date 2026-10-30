// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Polls the loop's status and publishes changes (research R13, R15).
 *
 * Every two seconds the monitor runs `loop.py status --json` (a short Python process that reads
 * the loop's files with the loop's own retries) and derives the view. A changed view is published
 * as `loop.changed`; other modules (the write gate, the live run, notifications) subscribe through
 * {@link LoopMonitor.onChange}. A failed poll keeps the previous view: a status that cannot be read
 * for a moment is no news.
 */

import type { LoopView } from "@backlog-app/shared";
import { LOOP_PY, type ServerContext } from "../context.ts";
import { pythonExecutable, runProcess } from "../proc/spawn.ts";
import { deriveLoopView, RawStatusSchema, type RawStatus } from "./view.ts";

/** Milliseconds between polls. */
const POLL_MS = 2000;

/** A listener of view changes. */
export type LoopListener = (view: LoopView, raw: RawStatus, previous: LoopView | null) => void;

/** The poller of the loop's status. */
export class LoopMonitor {
  /** The latest view, null before the first successful poll. */
  private current: LoopView | null = null;

  /** The latest raw status. */
  private currentRaw: RawStatus | null = null;

  /** The poll timer. */
  private timer: NodeJS.Timeout | null = null;

  /** True while a poll runs (polls never overlap). */
  private polling = false;

  /** The poll in flight, for {@link LoopMonitor.idle}. */
  private inFlight: Promise<LoopView | null> | null = null;

  /** True after {@link LoopMonitor.stop}: no further polls. */
  private stopped = false;

  /** Listeners of changes. */
  private readonly listeners = new Set<LoopListener>();

  /** The server context. */
  private readonly ctx: ServerContext;

  /**
   * Creates the monitor.
   *
   * @param ctx - The server context.
   */
  constructor(ctx: ServerContext) {
    this.ctx = ctx;
  }

  /** Starts polling. */
  start(): void {
    void this.refresh();
    this.timer = setInterval(() => void this.refresh(), POLL_MS);
  }

  /** Stops polling. */
  stop(): void {
    this.stopped = true;
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  /**
   * The latest view.
   *
   * @returns The view, or null before the first poll.
   */
  get view(): LoopView | null {
    return this.current;
  }

  /**
   * The latest raw status (the run record, the trace path, ...).
   *
   * @returns The raw status, or null before the first poll.
   */
  get raw(): RawStatus | null {
    return this.currentRaw;
  }

  /**
   * Subscribes to view changes.
   *
   * @param listener - Called with the new view, the raw status and the previous view.
   * @returns The unsubscribe function.
   */
  onChange(listener: LoopListener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  /**
   * Polls once now (also after a control command, so the answer reflects it at once).
   *
   * @returns The view after the poll.
   */
  async refresh(): Promise<LoopView | null> {
    if (this.stopped) return this.current;
    if (this.polling) return this.current;
    this.polling = true;
    const poll = this.poll();
    this.inFlight = poll;
    try {
      return await poll;
    } finally {
      this.inFlight = null;
      this.polling = false;
    }
  }

  /**
   * Resolves when no poll is running.
   *
   * @returns Resolves when idle.
   */
  async idle(): Promise<void> {
    while (this.inFlight) await this.inFlight;
  }

  /**
   * Runs `status --json` once and publishes a changed view.
   *
   * @returns The view after the poll.
   */
  private async poll(): Promise<LoopView | null> {
    try {
      const result = await runProcess(
        pythonExecutable(),
        ["-X", "utf8", LOOP_PY, "status", "--json", "--root", this.ctx.repo.root],
        { cwd: this.ctx.repo.root, timeoutMs: 20_000 },
      );
      if (result.code !== 0) return this.current;
      const parsed = RawStatusSchema.safeParse(JSON.parse(result.stdout));
      if (!parsed.success) return this.current;
      const view = deriveLoopView(parsed.data);
      const previous = this.current;
      this.currentRaw = parsed.data;
      // Heartbeat ages change every poll; compare without them so a quiet loop publishes nothing.
      const changed =
        previous === null ||
        JSON.stringify({ ...previous, heartbeatAge: 0 }) !== JSON.stringify({ ...view, heartbeatAge: 0 });
      this.current = view;
      if (changed) {
        this.ctx.hub.publish("loop.changed", view);
        for (const listener of this.listeners) listener(view, parsed.data, previous);
      }
      return view;
    } catch {
      return this.current;
    }
  }
}
