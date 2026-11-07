// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The time index of a run's trace (feature 415, research R4): claude's `stream-json` lines
 * carry no time of their own, so a time of a byte offset is interpolated between anchors - the
 * run's start at offset 0, the moments the app read the file up to an offset, the attempts'
 * separators. A replayed trace, or a live trace the app started following late, gets plausible
 * times instead of none (or all the same one).
 */

/** One anchor: a byte offset of the trace and the time it was reached. */
export interface TimeAnchor {
  /** The byte offset. */
  offset: number;
  /** Epoch milliseconds. */
  ms: number;
}

/** Most anchors kept (thinned evenly beyond). */
const MAX_ANCHORS = 2000;

/** The time index of one trace. */
export class TimeIndex {
  /** Anchors sorted by offset, times never decreasing. */
  private anchors: TimeAnchor[] = [];

  /**
   * Creates an index.
   *
   * @param anchors - Initial anchors in any order.
   */
  constructor(anchors: readonly TimeAnchor[] = []) {
    for (const anchor of anchors) this.add(anchor.offset, anchor.ms);
  }

  /**
   * The number of anchors.
   *
   * @returns The count.
   */
  get size(): number {
    return this.anchors.length;
  }

  /**
   * Adds an anchor. A later offset never gets an earlier time than an earlier offset (a clock
   * step back is flattened), and an anchor at a known offset keeps the earlier time.
   *
   * @param offset - Byte offset.
   * @param ms - Epoch milliseconds.
   */
  add(offset: number, ms: number): void {
    if (!Number.isFinite(offset) || !Number.isFinite(ms) || offset < 0) return;
    const list = this.anchors;
    let i = list.length;
    while (i > 0 && list[i - 1]!.offset > offset) i--;
    if (i > 0 && list[i - 1]!.offset === offset) return;
    const before = i > 0 ? list[i - 1]!.ms : -Infinity;
    const after = i < list.length ? list[i]!.ms : Infinity;
    list.splice(i, 0, { offset, ms: Math.min(Math.max(ms, before), after) });
    if (list.length > MAX_ANCHORS) {
      // Keep the first and the last, every second one between.
      this.anchors = list.filter((_, n) => n === 0 || n === list.length - 1 || n % 2 === 0);
    }
  }

  /**
   * The time of a byte offset, interpolated between its neighbouring anchors.
   *
   * @param offset - Byte offset.
   * @returns Epoch milliseconds, or null without anchors.
   */
  timeAt(offset: number): number | null {
    const list = this.anchors;
    if (list.length === 0) return null;
    if (offset <= list[0]!.offset) return list[0]!.ms;
    const last = list[list.length - 1]!;
    if (offset >= last.offset) return last.ms;
    let lo = 0;
    let hi = list.length - 1;
    while (hi - lo > 1) {
      const mid = (lo + hi) >> 1;
      if (list[mid]!.offset <= offset) lo = mid;
      else hi = mid;
    }
    const a = list[lo]!;
    const b = list[hi]!;
    const span = b.offset - a.offset;
    return span <= 0 ? a.ms : Math.round(a.ms + ((b.ms - a.ms) * (offset - a.offset)) / span);
  }

  /**
   * The time of a byte offset as an ISO string.
   *
   * @param offset - Byte offset.
   * @returns The ISO time, or null without anchors.
   */
  isoAt(offset: number): string | null {
    const ms = this.timeAt(offset);
    return ms === null ? null : new Date(ms).toISOString();
  }

  /**
   * The anchors (for saving).
   *
   * @returns A copy.
   */
  toJSON(): TimeAnchor[] {
    return this.anchors.map((a) => ({ ...a }));
  }
}
