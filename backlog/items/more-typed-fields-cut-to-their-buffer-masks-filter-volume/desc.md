---
title: More typed fields cut to their buffer: masks, filter, volume label, hot path label edit
type: bug
status: in-progress
severity: 6
area: long-paths
source: leftover:251
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: 2026-10-20 11e20a84
effort: M
feature: 270
related: []
depends-on: []
reason: -
---

# More typed fields cut to their buffer: masks, filter, volume label, hot path label edit

## Problem

Feature 251 made the fields of Make File List, the user menu, viewers / editors, hot paths, the
drives page and Edit New's default refuse text whose UTF-8 form does not fit the buffer, instead of
cutting it at a whole character. The same cut remains in fields outside that item's list (found by
251's reviews): a field limits its text in UTF-16 units (259), the program reads it into a 260-byte
UTF-8 buffer - CJK text of 87-259 letters is cut and the shorter text is acted upon. A cut Select /
Unselect mask selects other files (which a following Delete or Move then acts on); a cut Convert
mask converts other files; a cut filter shows other files; a cut volume label is written to the
drive; the hot path list's in-place label edit (F2 on a row) **stores** the cut text as the slot's
name.

## Evidence

At 12273ba1 (branch `251-dialog-text-fits`), by reading; the label edit measured by 251's review 2:
- `src/dialogs2.cpp:576` / `:607` - `CSelectDialog::Validate` / `Transfer`:
  `SalGetWindowTextU8(hWnd, Mask, MAX_PATH)` (combo limited to `MAX_PATH - 1` units).
- `src/dialogs3.cpp:118` - `CConvertFilesDlg::Transfer`: the mask, the same read.
- `src/dialogs3.cpp:281` / `:321` - `CFilterDialog`: `ti.EditLine(IDE_FILTER, Filter->GetWritableMasksString(), MAX_PATH)`
  and `SalGetWindowTextU8(hWnd, Filter->GetWritableMasksString(), MAX_PATH)`.
- `src/dialogs3.cpp:1314` - `CDriveInfo::Validate`: the volume label
  `SalGetWindowTextU8(edit, newName, MAX_PATH)` (a volume label itself is short - check what the
  file system accepts before choosing refuse vs. its own limit).
- `src/dialogs4.cpp:3279` - `CCfgPageHotPath` `LVN_ENDLABELEDIT`: `SalGetWindowTextU8(hEdit, name, MAX_PATH)`,
  then `Config->SetName(index, name)`. Review 2 of 251: F2 on a hot path row, 100 CJK letters
  (300 bytes), Enter - stored as 86 letters without a word.
- The shared helpers of 251: `DlgItemTextFitsU8` (`src/dialogs.h`), `SalWindowTextFitsU8` /
  `SalGetWindowTextU8Alloc` (`src/common/winlib.h`), `SalWTextFitsU8` / `SalU8TextFits`
  (`src/common/salunicode.h`); 251's probe `specs/251-dialog-text-fits/probe/dlg251_probe.ps1`.

## Expected

Each of these fields measures the whole text (`DlgItemTextFitsU8` / `SalWindowTextFitsU8`) and
refuses with "The path specified is too long." (or keeps the whole text, as 251 did for the hot
path page, and refuses at the page's `Validate` - the label edit: store the whole name, the page's
existing name check refuses it at OK); no cut mask, filter, label or name is used or stored.

## Notes

Severity 6 as 251's item: a cut Select mask can make a following file operation act on other
files; the other sites give a wrong result with a workaround. Not measured per site except the
label edit. The volume label line may not be reachable with a cut (the label limit of the file
system is far below 260 bytes) - check first.

## Log

- 2026-10-20 — created (source leftover:251)
- 2026-10-20 — related item dialog-typed-text-cut-to-caller-buffer done in feature 251
- 2026-10-20 — moved to Next position 3
- 2026-10-20 — verified at 11e20a84: reproduced at 11e20a84 by a hidden-desktop probe: Select/Unselect/Filter cut to 259 bytes, Convert converted a file the typed mask missed, the volume label written cut, F2 label stored as 86 of 100 letters
- 2026-10-20 — run started, feature 270
