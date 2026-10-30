// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The keyboard shortcut sheet (`?`): the global shortcuts and the ones of the lists, so no
 * shortcut has to be remembered.
 */

import { Dialog, DialogContent } from "@/components/ui/overlays.tsx";
import { Kbd } from "@/components/ui/primitives.tsx";
import type { Shortcut } from "@/lib/hotkeys.ts";

/** Shortcuts of the lists and dialogs (registered by the pages themselves). */
const LIST_SHORTCUTS: { keys: string; label: string }[] = [
  { keys: "j / k", label: "Next / previous row" },
  { keys: "Enter", label: "Open the selected item" },
  { keys: "Esc", label: "Close the pane or dialog" },
  { keys: "Alt+↑ / Alt+↓", label: "Move the selected item one row (ordered sections)" },
  { keys: "Alt+Shift+↑ / ↓", label: "Move the selected item to the top / bottom" },
  { keys: "x", label: "Select the row (bulk changes)" },
  { keys: "Ctrl+Z", label: "Undo the last uncommitted change" },
  { keys: "Ctrl+Enter", label: "Submit the dialog" },
];

/**
 * The sheet.
 *
 * @param props - Open state, setter and the global shortcuts.
 * @returns The element.
 */
export function ShortcutSheet({
  open,
  onOpenChange,
  shortcuts,
}: {
  /** Whether the sheet is open. */
  open: boolean;
  /** Called to open or close it. */
  onOpenChange: (open: boolean) => void;
  /** The global shortcuts of the layout. */
  shortcuts: Shortcut[];
}) {
  const rows = [
    ...shortcuts.map((s) => ({
      keys: s.keys.replace("ctrl+", "Ctrl+").replace(/^g /, "g then "),
      label: s.label,
    })),
    ...LIST_SHORTCUTS,
  ];
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        title="Keyboard shortcuts"
        description="Single keys work when the focus is not in a text field."
        wide
      >
        <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5 text-sm">
          {rows.map((row) => (
            <div key={row.keys + row.label} className="contents">
              <dt>
                <Kbd>{row.keys}</Kbd>
              </dt>
              <dd className="text-muted-foreground">{row.label}</dd>
            </div>
          ))}
        </dl>
      </DialogContent>
    </Dialog>
  );
}
