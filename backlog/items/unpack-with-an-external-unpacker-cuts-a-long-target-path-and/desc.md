---
title: Unpack with an external unpacker cuts a long target path and mask
type: bug
status: new
severity: 6
area: long-paths
source: review:291
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Unpack with an external unpacker cuts a long target path and mask

## Problem

Unpack (Alt+F9) of an archive through an external unpacker (`CUnpackDialog`) reads the target
path and the mask with `ti.EditLine(..., MAX_PATH)`: text whose UTF-8 form is longer than 259
bytes is cut at a whole character and used. The target path field is a combo box filled with
`SalComboAddStringU8` - no `EditLine` sets a limit on it, so even a long ASCII path is cut. The
program then creates and extracts into the cut folder (another folder than the one typed); a cut
mask extracts other files. The dialog has no `Validate`, so nothing refuses the text.

## Evidence

By reading (review 1 of feature 291), at c767771e on branch `291-masks-cut-rest`:
- `src/dialogs3.cpp` `CUnpackDialog::Transfer` (about line 2255): `ti.EditLine(IDE_PATH, Path, MAX_PATH)`
  in the `ttDataFromWindow` branch; `ttDataToWindow` only adds strings to the combo box.
- the same function (about line 2262): `ti.EditLine(IDE_MASK, Mask, MAX_PATH)`.
- `src/dialogs.h` `class CUnpackDialog`: no `Validate`.
- caller `src/fileswn7.cpp` (about line 2225, the unpack command with an external unpacker).
- the pattern of the fix: 214's `CCopyMoveDialog::Validate` and 291's `Validate` checks
  (`DlgItemTextFitsU8`, `src/dialogs3.cpp`).

## Expected

`CUnpackDialog` gets a `Validate` that measures both fields whole (`DlgItemTextFitsU8`, the buffer
sizes the caller passes) and refuses with "The path specified is too long."; nothing is extracted
into a cut path or with a cut mask. A hidden-desktop probe row for each field (before: FAIL,
after: PASS) and a control that fits.

## Notes

Not measured - check first that an external unpacker can be reached on the build (feature 084
offers only installed archivers; the probe may need a test unpacker configured). Severity 6: the
files land in another folder (overwrite questions still asked), no loss found by reading.

## Log

- 2026-10-21 — created (source review:291)
