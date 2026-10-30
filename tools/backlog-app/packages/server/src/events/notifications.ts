// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Notifications (research R21; FR-020): events derived from state transitions of the loop,
 * the runs and the backlog, kept in `events.jsonl` in the app's state folder so the Home page can
 * show what happened while no tab was open, and pushed to every open tab (`notify`).
 *
 * Derived events:
 * - a run ended (with its outcome; a blocked run needs attention);
 * - the loop stopped for a person (urgent: it stays until opened);
 * - the loop waits for a usage limit, and the wait is over;
 * - the loop has waited on its precheck for more than ten minutes (often uncommitted changes);
 * - the loop ended (with its reason);
 * - runs added items to the Inbox;
 * - the consistency check found problems.
 */

import { appendFileSync, readFileSync } from "node:fs";
import { z } from "zod";
import { NotificationEventSchema, type LoopView, type NotificationEvent } from "@backlog-app/shared";
import type { ServerContext } from "../context.ts";

/** The event log in the state folder. */
const LOG = "events.jsonl";

/** Minutes of precheck waiting after which the maintainer is told. */
const PRECHECK_MINUTES = 10;

/** Events of the derivation, before they get an id and a time. */
export type DerivedEvent = Omit<NotificationEvent, "id" | "at">;

/** What the derivation remembers between two observations. */
export interface Observation {
  /** The loop view. */
  loop: LoopView | null;
  /** Inbox item count. */
  inbox: number | null;
  /** Check findings count. */
  check: number | null;
}

/** State of the waiting detector. */
export interface WaitTracker {
  /** When the current waiting episode started (ms), or null. */
  since: number | null;
  /** True when this episode was already announced. */
  announced: boolean;
}

/**
 * Derives the events of one transition (pure; tested).
 *
 * @param previous - The previous observation.
 * @param next - The new observation.
 * @param wait - The waiting detector (updated in place).
 * @param now - The current time (ms).
 * @returns The events to announce.
 */
export function deriveEvents(
  previous: Observation,
  next: Observation,
  wait: WaitTracker,
  now: number,
): DerivedEvent[] {
  const events: DerivedEvent[] = [];
  const before = previous.loop;
  const after = next.loop;
  if (after && before) {
    if (after.shown === "stopped-for-person" && before.shown !== "stopped-for-person") {
      events.push({
        kind: "stopped-for-person",
        severity: "urgent",
        title: "The loop stopped and needs you",
        text: after.detail,
        link: "/loop",
      });
    }
    /**
     * Whether the loop waits for a usage limit (between attempts, or inside claude).
     *
     * @param v - A loop view.
     * @returns True while limited.
     */
    const limited = (v: LoopView): boolean => v.shown === "limit" || v.usage?.status === "rejected";
    if (limited(after) && !limited(before)) {
      events.push({
        kind: "usage-limit",
        severity: "attention",
        title: "Waiting for the usage limit",
        text: after.until
          ? `The loop continues after ${after.until.replace("T", " ")}.`
          : "The loop continues when the limit resets.",
        link: "/loop",
      });
    } else if (!limited(after) && limited(before) && after.live) {
      events.push({
        kind: "usage-limit-over",
        severity: "info",
        title: "The usage-limit wait is over",
        text: "The loop continues.",
        link: "/live",
      });
    }
    if (before.live && !after.live && after.shown !== "stopped-for-person") {
      events.push({
        kind: "loop-ended",
        severity: after.lastEnd?.reason === "max-blocked" || after.shown === "dead" ? "attention" : "info",
        title: "The loop ended",
        text: after.lastEnd ? `Reason: ${after.lastEnd.reason}.` : after.detail,
        link: "/loop",
      });
    }
  }
  // Waiting on the precheck: one announcement per waiting episode.
  if (after?.live && after.shown === "waiting") {
    wait.since ??= now;
    if (!wait.announced && now - wait.since > PRECHECK_MINUTES * 60_000) {
      wait.announced = true;
      events.push({
        kind: "precheck-wait",
        severity: "attention",
        title: `The loop has waited for ${PRECHECK_MINUTES} minutes`,
        text: after.detail,
        link: "/loop",
      });
    }
  } else {
    wait.since = null;
    wait.announced = false;
  }
  if (previous.inbox !== null && next.inbox !== null && next.inbox > previous.inbox && after?.live) {
    const added = next.inbox - previous.inbox;
    events.push({
      kind: "inbox-added",
      severity: "info",
      title: `${added} new Inbox item${added === 1 ? "" : "s"}`,
      text: "Runs added findings to the Inbox.",
      link: "/backlog/inbox",
    });
  }
  if (previous.check === 0 && next.check !== null && next.check > 0) {
    events.push({
      kind: "check-findings",
      severity: "attention",
      title: "The backlog check found problems",
      text: `${next.check} finding${next.check === 1 ? "" : "s"}.`,
      link: "/check",
    });
  }
  return events;
}

/** The notification log and the announcement of new events. */
export class Notifications {
  /** The server context. */
  private readonly ctx: ServerContext;

  /** The id of the last event. */
  private lastId: number;

  /** The previous observation. */
  private previous: Observation = { loop: null, inbox: null, check: null };

  /** The waiting detector. */
  private readonly wait: WaitTracker = { since: null, announced: false };

  /**
   * Opens the log.
   *
   * @param ctx - The server context.
   */
  constructor(ctx: ServerContext) {
    this.ctx = ctx;
    this.lastId = this.all().at(-1)?.id ?? 0;
  }

  /**
   * Every logged event, oldest first.
   *
   * @returns The events.
   */
  all(): NotificationEvent[] {
    let text: string;
    try {
      text = readFileSync(this.ctx.state.file(LOG), "utf8");
    } catch {
      return [];
    }
    const events: NotificationEvent[] = [];
    for (const line of text.split("\n")) {
      if (!line.trim()) continue;
      try {
        const parsed = NotificationEventSchema.safeParse(JSON.parse(line));
        if (parsed.success) events.push(parsed.data);
      } catch {
        // A damaged line is skipped.
      }
    }
    return events;
  }

  /**
   * Events after an id.
   *
   * @param since - The last id the client has seen.
   * @returns The newer events, oldest first.
   */
  after(since: number): NotificationEvent[] {
    return this.all().filter((e) => e.id > since);
  }

  /**
   * Logs and announces one event.
   *
   * @param event - The event.
   * @returns The stored event.
   */
  announce(event: DerivedEvent): NotificationEvent {
    const stored: NotificationEvent = { ...event, id: ++this.lastId, at: new Date().toISOString() };
    // One append per line; the file is never rewritten.
    appendFileSync(
      this.ctx.state.file(LOG),
      `${JSON.stringify(z.object({}).loose().parse(stored))}\n`,
      "utf8",
    );
    this.ctx.hub.publish("notify", stored);
    return stored;
  }

  /**
   * Observes the state and announces what changed.
   *
   * @param next - The new observation.
   */
  observe(next: Observation): void {
    // The first observation only sets the baseline (a restart is not news).
    if (this.previous.loop === null && this.previous.inbox === null) {
      this.previous = next;
      return;
    }
    for (const event of deriveEvents(this.previous, next, this.wait, Date.now())) this.announce(event);
    this.previous = {
      loop: next.loop ?? this.previous.loop,
      inbox: next.inbox ?? this.previous.inbox,
      check: next.check ?? this.previous.check,
    };
  }
}
