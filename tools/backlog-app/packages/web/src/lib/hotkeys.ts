// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Keyboard shortcuts (analysis A4 §4.9; FR-041): `g` followed by a letter navigates, single
 * keys act on the current view. Single-letter keys are ignored while the focus is in a text field,
 * so typing never triggers an action. Every action also exists as a visible control and in the
 * command palette - no function is reachable by keyboard only.
 */

import { useEffect } from "react";

/** One shortcut: a key (or `g x` sequence) and its action. */
export interface Shortcut {
  /** `x`, `shift+x`, `alt+ArrowUp`, `ctrl+k`, or a sequence `g x`. */
  keys: string;
  /** What it does (for the shortcut sheet). */
  label: string;
  /** The action. */
  run: (event: KeyboardEvent) => void;
  /** Also active inside text fields (for Ctrl/Alt combinations). */
  inFields?: boolean;
}

/**
 * Whether an element is a text field (where single keys must type, not act).
 *
 * @param target - The event target.
 * @returns True inside inputs, text areas, selects and editable content.
 */
function isTextField(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  const tag = target.tagName;
  // A checkbox or radio (the row marks) takes no typing: the page's keys keep working after one
  // was clicked.
  if (target instanceof HTMLInputElement && ["checkbox", "radio", "button", "submit"].includes(target.type)) {
    return false;
  }
  return (
    tag === "INPUT" ||
    tag === "TEXTAREA" ||
    tag === "SELECT" ||
    target.isContentEditable ||
    target.closest(".cm-editor") !== null
  );
}

/**
 * Whether the focus is inside a menu, a dialog, a list box or the command palette: their keys
 * (arrows, Escape, Enter, letters for type-ahead) belong to them, never to the page behind -
 * otherwise an arrow in an open "More actions" menu also moved the backlog selection, and the
 * menu then acted on another item.
 *
 * @param target - The event target.
 * @returns True inside such a widget.
 */
function inWidget(target: EventTarget | null): boolean {
  return (
    target instanceof Element &&
    target.closest('[role="dialog"],[role="alertdialog"],[role="menu"],[role="listbox"],[cmdk-root]') !== null
  );
}

/**
 * Whether Enter or Space on this target is the target's own action (a focused button, link,
 * tab, checkbox): then the page must not take the key.
 *
 * @param target - The event target.
 * @returns True for such elements.
 */
function isActivatable(target: EventTarget | null): boolean {
  return (
    target instanceof Element &&
    target.closest(
      'button,a[href],[role="button"],[role="tab"],[role="checkbox"],[role="menuitem"],summary',
    ) !== null
  );
}

/**
 * The key text of an event in the form shortcuts use.
 *
 * @param event - The keydown event.
 * @returns E.g. `ctrl+k`, `alt+ArrowUp`, `shift+j`, `x`.
 */
function keyText(event: KeyboardEvent): string {
  const parts: string[] = [];
  if (event.ctrlKey || event.metaKey) parts.push("ctrl");
  if (event.altKey) parts.push("alt");
  // Shift is part of printable keys already (`?`), but explicit for letters and arrows.
  if (event.shiftKey && (event.key.length > 1 || /[a-z]/i.test(event.key))) parts.push("shift");
  parts.push(event.key.length === 1 ? event.key.toLowerCase() : event.key);
  return parts.join("+");
}

/**
 * Registers shortcuts while the calling component is mounted.
 *
 * @param shortcuts - The shortcuts; the list may change between renders.
 * @param enabled - Turns them all off (e.g. while a dialog is open).
 */
export function useShortcuts(shortcuts: Shortcut[], enabled = true): void {
  useEffect(() => {
    if (!enabled) return;
    let pendingG = false;
    let timer: number | undefined;
    /**
     * Matches a key press against the shortcuts.
     *
     * @param event - The keydown event.
     */
    const onKey = (event: KeyboardEvent): void => {
      if (event.repeat && !event.altKey) return;
      // A widget (Radix menu, dialog, select) already handled the key.
      if (event.defaultPrevented) return;
      const field = isTextField(event.target) || inWidget(event.target);
      const key = keyText(event);
      if (pendingG) {
        pendingG = false;
        window.clearTimeout(timer);
        const match = shortcuts.find((s) => s.keys === `g ${key}`);
        if (match && !field) {
          event.preventDefault();
          match.run(event);
        }
        return;
      }
      if (key === "g" && !field && shortcuts.some((s) => s.keys.startsWith("g "))) {
        pendingG = true;
        timer = window.setTimeout(() => (pendingG = false), 1200);
        return;
      }
      const match = shortcuts.find((s) => s.keys === key);
      if (!match) return;
      if (field && !match.inFields) return;
      if ((key === "Enter" || key === " ") && isActivatable(event.target)) return;
      event.preventDefault();
      match.run(event);
    };
    window.addEventListener("keydown", onKey);
    return () => {
      window.removeEventListener("keydown", onKey);
      window.clearTimeout(timer);
    };
  }, [shortcuts, enabled]);
}
