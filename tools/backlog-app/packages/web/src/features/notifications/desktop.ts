// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Desktop notifications through the browser's Notification API (FR-020, research R21).
 *
 * The page asks for permission only when the maintainer switches desktop notifications on in the
 * settings (never on load). Localhost is a secure context, so the API works; on Windows the
 * browser shows the notification as a system toast. Quiet hours suppress desktop notifications
 * only - the in-page toasts and the *Needs you* list always show events.
 */

import type { NotificationEvent, Settings } from "@backlog-app/shared";

/** The settings the decision needs, kept current by the settings page and the app start. */
let current: Pick<Settings, "notifications"> | null = null;

/**
 * Updates the notification settings the next decisions use.
 *
 * @param settings - The maintainer's settings.
 */
export function applyNotificationSettings(settings: Pick<Settings, "notifications">): void {
  current = settings;
}

/**
 * Whether a time of day lies inside the quiet hours (which may wrap midnight).
 *
 * @param now - The time.
 * @param quiet - `HH:MM` from and to, or null.
 * @returns True inside the quiet hours.
 */
export function inQuietHours(now: Date, quiet: { from: string; to: string } | null): boolean {
  if (!quiet) return false;
  /**
   * Minutes since midnight of an `HH:MM` text.
   *
   * @param text - The time text.
   * @returns The minutes.
   */
  const minutes = (text: string): number => {
    const [h = "0", m = "0"] = text.split(":");
    return Number(h) * 60 + Number(m);
  };
  const at = now.getHours() * 60 + now.getMinutes();
  const from = minutes(quiet.from);
  const to = minutes(quiet.to);
  return from <= to ? at >= from && at < to : at >= from || at < to;
}

/**
 * Shows an event as a desktop notification when allowed, wanted and not in quiet hours.
 *
 * @param event - The notification event.
 */
export function showDesktopNotification(event: NotificationEvent): void {
  if (!current?.notifications.desktop) return;
  if (typeof Notification === "undefined" || Notification.permission !== "granted") return;
  if (current.notifications.events[event.kind] === false) return;
  if (inQuietHours(new Date(), current.notifications.quietHours)) return;
  const notification = new Notification(event.title, {
    body: event.text,
    tag: `backlog-app-${event.id}`,
    requireInteraction: event.severity === "urgent",
  });
  notification.onclick = () => {
    window.focus();
    if (event.link) window.location.assign(event.link);
    notification.close();
  };
}

/**
 * Asks the browser for permission to show desktop notifications.
 *
 * @returns True when granted.
 */
export async function requestDesktopPermission(): Promise<boolean> {
  if (typeof Notification === "undefined") return false;
  if (Notification.permission === "granted") return true;
  return (await Notification.requestPermission()) === "granted";
}
