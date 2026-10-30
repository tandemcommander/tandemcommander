// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Small helpers shared by the components: class-name merging and display formats.
 */

import { clsx, type ClassValue } from "clsx";
import { formatDistanceToNowStrict, parseISO } from "date-fns";
import { twMerge } from "tailwind-merge";

/**
 * Joins class names and resolves conflicting Tailwind utilities (the shadcn `cn` helper).
 *
 * @param inputs - Class names, conditionals, arrays.
 * @returns One class string.
 */
export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}

/**
 * The severity band of a severity value (legend anchors 9-10, 7-8, 4-6, 1-3, 0).
 *
 * @param severity - Severity 0-10.
 * @returns The band's token name.
 */
export function severityBand(severity: number): "critical" | "high" | "medium" | "low" | "trivial" {
  if (severity >= 9) return "critical";
  if (severity >= 7) return "high";
  if (severity >= 4) return "medium";
  if (severity >= 1) return "low";
  return "trivial";
}

/**
 * A relative time ("5 minutes ago") of an ISO or `YYYY-MM-DD HH:MM:SS` time.
 *
 * @param value - The time, or null.
 * @returns The relative text, or an em dash.
 */
export function relativeTime(value: string | null | undefined): string {
  if (!value) return "—";
  const date = parseISO(value.includes("T") ? value : value.replace(" ", "T"));
  if (Number.isNaN(date.getTime())) return value;
  return formatDistanceToNowStrict(date, { addSuffix: true });
}

/**
 * A duration in seconds as `1 h 05 min`, `12 min 03 s` or `45 s`.
 *
 * @param seconds - The duration, or null.
 * @returns The text, or an em dash.
 */
export function formatDuration(seconds: number | null | undefined): string {
  if (seconds === null || seconds === undefined || !Number.isFinite(seconds)) return "—";
  const s = Math.max(0, Math.round(seconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const rest = s % 60;
  if (h > 0) return `${h} h ${String(m).padStart(2, "0")} min`;
  if (m > 0) return `${m} min ${String(rest).padStart(2, "0")} s`;
  return `${rest} s`;
}

/**
 * A byte count as KB / MB / GB.
 *
 * @param bytes - The size.
 * @returns The text.
 */
export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  const units = ["KB", "MB", "GB", "TB"];
  let value = bytes / 1024;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return `${value.toFixed(value >= 10 ? 0 : 1)} ${units[unit]}`;
}
