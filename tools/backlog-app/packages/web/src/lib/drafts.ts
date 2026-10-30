// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Local drafts (FR-031; analysis A4 §4.10): unsaved text of any editor is kept in the
 * browser's storage per item and field, so a reload, a closed dialog or an item that changed
 * underneath never loses typed text. A draft is never sent to the server until it is saved, and it
 * is dropped once the change was written.
 */

import { useCallback, useEffect, useState } from "react";

/** Prefix of the storage keys. */
const PREFIX = "backlog-app.draft.";

/**
 * Reads a draft; storage can be unavailable.
 *
 * @param key - The draft's key.
 * @returns The text, or null.
 */
function readDraft(key: string): string | null {
  try {
    return window.localStorage.getItem(PREFIX + key);
  } catch {
    return null;
  }
}

/**
 * Stores or removes a draft.
 *
 * @param key - The draft's key.
 * @param value - The text; empty or equal to the initial value removes the draft.
 */
function writeDraft(key: string, value: string | null): void {
  try {
    if (value === null) window.localStorage.removeItem(PREFIX + key);
    else window.localStorage.setItem(PREFIX + key, value);
  } catch {
    // Without storage the text lives only in the page.
  }
}

/**
 * A text state backed by a draft.
 *
 * @param key - The draft's key (item and field).
 * @param initial - The value when there is no draft.
 * @returns The value, its setter, and a function that drops the draft (after a save).
 */
export function useDraft(key: string, initial: string): [string, (value: string) => void, () => void] {
  const [value, setValue] = useState(() => readDraft(key) ?? initial);
  // Another key (the section editor's section select, another item) is another draft: load it in
  // the same render. Without this the previous field's text stayed in the editor and was saved
  // into the newly chosen field (review).
  const [keyOf, setKeyOf] = useState(key);
  if (keyOf !== key) {
    setKeyOf(key);
    setValue(readDraft(key) ?? initial);
  }
  useEffect(() => {
    writeDraft(key, value === initial || value === "" ? null : value);
  }, [key, value, initial]);
  const drop = useCallback(() => writeDraft(key, null), [key]);
  return [value, setValue, drop];
}

/**
 * Whether a draft exists (to show "restored your unsaved draft").
 *
 * @param key - The draft's key.
 * @returns True when one is stored.
 */
export function hasDraft(key: string): boolean {
  return readDraft(key) !== null;
}
