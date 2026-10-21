---
title: Typed masks still cut to their buffer: Recycle Bin, Find, viewer, compare
type: bug
status: in-progress
severity: 7
area: long-paths
source: review:270
who: agent
created: 2026-10-20
updated: 2026-10-21
verified: 2026-10-21 c01e1801
effort: M
feature: 291
related: []
depends-on: []
reason: -
---

# Typed masks still cut to their buffer: Recycle Bin, Find, viewer, compare

## Problem

Features 251 and 270 made typed fields refuse text whose UTF-8 form does not fit the program's
buffer instead of cutting it at a whole character. Mask fields outside both items still read the
field with `ti.EditLine(..., MAX_PATH)` (cut at a whole character, feature 093) and store the
shorter mask list. Worst case: the Recycle Bin masks of Configuration > System ("Use Recycle Bin
for files matching") - masks dropped by the cut no longer match, and files they named are deleted
**permanently** instead of going to the Recycle Bin. The Find dialog's "Named" mask finds other
files (which the user may then delete from the results). The viewer's text / hex masks and the
compare ignore masks give a wrong result with a workaround; the viewer list's in-place name edit
reads into 30 bytes.

## Evidence

At 7ae8d2a4 (branch `270-mask-filter-label-fits`), by reading (review 1 of feature 270):
- `src/dialogs4.cpp:3425` / `:3445` - `CCfgPageSystem::Validate` / `Transfer`:
  `ti.EditLine(IDE_RECYCLEMASKS, Configuration.RecycleMasks.GetWritableMasksString(), MAX_PATH)`.
- `src/finddlg1.cpp:1778` - `SalGetWindowTextU8(hNamesWnd, Data.NamedText, NAMED_TEXT_LEN)` (the
  field limit vs. `NAMED_TEXT_LEN` not verified).
- `src/dialogs4.cpp:1692`, `:1710`, `:1742`, `:1744` - the viewer page's `IDC_VIEW_INTEXT` /
  `IDC_VIEW_INHEX` masks, `EditLine(..., MAX_PATH)`.
- `src/dialogs6.cpp:1534` / `:1536` - `IDE_COMPARE_IGNORE_FILES` / `IDE_COMPARE_IGNORE_DIRS`,
  `EditLine(..., MAX_PATH)`.
- `src/dialogs4.cpp:1548` - the viewer list's `LVN_ENDLABELEDIT`: `SalGetWindowTextU8(hEdit, name, VIEW_NAME_MAX)`.
- The helpers and the probe pattern: `DlgItemTextFitsU8` (`src/dialogs.h`), 270's
  `specs/270-mask-filter-label-fits/probe/mask270_probe.ps1` (`Mask-Row`).

## Expected

Each field measures the whole text (`DlgItemTextFitsU8` in the page's / dialog's `Validate`, before
the syntax check) and refuses with "The path specified is too long."; no cut mask list is used or
stored. The Recycle Bin masks first (the data-loss case).

## Notes

Severity 7: the Recycle Bin case loses files in a narrow scenario (a mask list longer than 259
UTF-8 bytes, e.g. CJK masks); the others have a workaround. Not measured - check each limit first
(the Find "Named" field's limit and `NAMED_TEXT_LEN`, the viewer name's limit vs. 30 bytes). Could
be split into the Recycle Bin item and the rest if one feature is too large.

## Log

- 2026-10-20 — created (source review:270)
- 2026-10-20 — related item more-typed-fields-cut-to-their-buffer-masks-filter-volume done in feature 270
- 2026-10-21 — moved to Next position 2
- 2026-10-21 — verified at c01e1801: reproduced at c01e1801: probe mask291 12 FAIL / 5 controls PASS - Recycle Bin, Find Named (also Add current / Ignore / option), viewer, compare masks stored or used cut; view name cut to 29 bytes
- 2026-10-21 — run started, feature 291
