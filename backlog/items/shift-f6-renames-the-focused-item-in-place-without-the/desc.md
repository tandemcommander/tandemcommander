---
title: Shift+F6 renames the focused item in place, without the Rename dialog
type: improvement
status: in-progress
severity: 3
area: panels-ui
source: manual
who: both
created: 2026-10-31
updated: 2026-10-31
verified: 2026-10-31 e0c3690d
effort: M
feature: 346
related: []
depends-on: []
reason: -
---

# Shift+F6 renames the focused item in place, without the Rename dialog

## Problem

Users coming from Total Commander rename the focused file or folder with Shift+F6, which opens an edit field right on the name in the panel. In Tandem Commander, Shift+F6 does nothing in a panel. F2 opens the modal Rename dialog. The in-place editor (Quick Rename) already exists, but it opens only when the user clicks the name of an item that is already focused. No key opens it, so keyboard users always get the dialog.

## Evidence

By reading, at 1d31c6c1:
- `src/salamand.rc:61-117` (`IDA_MAINACCELS1`): `VK_F2` → `CM_RENAMEFILE` (line 66). The F6 rows are F6 → `CM_MOVEFILES` (81), Ctrl+F6 → `CM_ACTIVESIZE` (82), Alt+F6 → `CM_UNPACK` (83) and Shift+Ctrl+F6 → `CM_RESTORESEL` (117). Shift+F6 alone has no row. `IDA_MAINACCELS2` was not checked.
- `src/mainwnd3.cpp:3868-3871`: `CM_RENAMEFILE` calls `CFilesWindow::RenameFile()`, and `src/fileswn5.cpp:2540-2593` (`RenameFile`) builds the modal `CCopyMoveDialog` with `IDD_RENAMEDIALOG`.
- `src/fileswn5.cpp:2869-2976` (`QuickRenameBegin(int index, const RECT* labelRect)`): the in-place editor, a child `edit` window over the name. It supports disk panels and plug-in file systems with `FS_SERVICE_QUICKRENAME` (the FS gets `QuickRename` mode 1 first), handles WTF-8 names and selects the name without its extension unless `Configuration.QuickRenameSelectAll` is set.
- Its only live caller is the mouse timer `IDT_QUICKRENAMEBEGIN` (`src/fileswn9.cpp:1581-1588`). A keyboard entry point, `QuickRenameOnIndex(int index)`, exists only inside a comment block (`src/fileswn5.cpp` ~2850-2867, declaration commented out at `src/fileswn.h:1670`). It computed the label rect from `ListBox->GetItemRect` and called `QuickRenameBegin`.
- No existing backlog item covers in-place rename or Shift+F6. A grep of `backlog/items/` for inline / in-place rename and Shift+F6 finds nothing.

## Expected

In a disk panel, and in a plug-in FS panel that supports Quick Rename, Shift+F6 on a focused item other than `..` opens the in-place edit field over its name. It selects the same text as a click-started Quick Rename does. Enter renames the item, Esc cancels it, and focus stays on the renamed item. F2 still opens the Rename dialog. On `..` or in a panel without Quick Rename (archive, unsupported FS), Shift+F6 does nothing. The menu and the keyboard help list the new shortcut. Shift+Ctrl+F6 (Restore Selection) works as before.

## Log

- 2026-10-31 — created (source manual)
- 2026-10-31 — moved to Next position 82
- 2026-10-31 — verified at e0c3690d: present at e0c3690d: no Shift+F6 row in IDA_MAINACCELS1/2 or panel key handler; hidden-desktop probe: Shift+F6 sent to the panel opens no in-place edit (file, folder, accented name)
- 2026-10-31 — run started, feature 346
