// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file A ticking clock for components that show elapsed times. Reading `Date.now()` during render
 * would make the render impure (a different result on every call); the clock is state that an
 * interval updates, so a component re-renders once per tick and only while it needs to.
 */

import { useEffect, useState } from "react";

/**
 * The current time, updated every interval while active.
 *
 * @param intervalMs - Milliseconds between updates.
 * @param active - Tick only while true (a finished job needs no clock).
 * @returns Milliseconds since the epoch.
 */
export function useNow(intervalMs: number, active: boolean): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    if (!active) return;
    const timer = window.setInterval(() => setNow(Date.now()), intervalMs);
    return () => window.clearInterval(timer);
  }, [intervalMs, active]);
  return now;
}
