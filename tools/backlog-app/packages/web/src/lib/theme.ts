// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The colour theme: *System* (default, follows the operating system live), *Light* and
 * *Dark* (research R3, FR-040).
 *
 * The choice is kept in the browser's storage under the key `public/theme-init.js` reads before
 * the first paint, so a reload never flashes in the wrong theme. The server keeps a copy in its
 * settings (so a cleared browser storage gets it back); this module only applies and stores it.
 */

import { useSyncExternalStore } from "react";

/** A theme choice. */
export type ThemeChoice = "system" | "light" | "dark";

/** Storage key shared with `public/theme-init.js`. */
export const THEME_KEY = "backlog-app.theme";

/** Listeners of theme changes (components that show the current choice). */
const listeners = new Set<() => void>();

/** The system's dark-mode query. */
const darkQuery = window.matchMedia("(prefers-color-scheme: dark)");

/**
 * Reads the stored choice; storage can be unavailable (private window), then `system`.
 *
 * @returns The choice.
 */
export function storedTheme(): ThemeChoice {
  try {
    const value = window.localStorage.getItem(THEME_KEY);
    return value === "light" || value === "dark" ? value : "system";
  } catch {
    return "system";
  }
}

/**
 * Applies a choice to the page: the `dark` class and the native `color-scheme`.
 *
 * @param choice - The choice.
 */
function applyTheme(choice: ThemeChoice): void {
  const dark = choice === "dark" || (choice === "system" && darkQuery.matches);
  document.documentElement.classList.toggle("dark", dark);
  document.documentElement.style.colorScheme = dark ? "dark" : "light";
}

/**
 * Stores and applies a choice and tells the listeners.
 *
 * @param choice - The new choice.
 */
export function setTheme(choice: ThemeChoice): void {
  try {
    window.localStorage.setItem(THEME_KEY, choice);
  } catch {
    // Storage unavailable: the choice holds for this page only.
  }
  applyTheme(choice);
  for (const listener of listeners) listener();
}

/**
 * Whether the page is dark now (resolves *System*).
 *
 * @returns True in the dark theme.
 */
export function isDark(): boolean {
  return document.documentElement.classList.contains("dark");
}

/**
 * Subscribes to theme changes (for `useSyncExternalStore`).
 *
 * @param listener - Called after every change.
 * @returns The unsubscribe function.
 */
function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  darkQuery.addEventListener("change", listener);
  return () => {
    listeners.delete(listener);
    darkQuery.removeEventListener("change", listener);
  };
}

/**
 * React hook: the current choice, re-rendering on changes.
 *
 * @returns The choice.
 */
export function useTheme(): ThemeChoice {
  return useSyncExternalStore(subscribe, storedTheme);
}
