---
title: User Menu compare names and the Change Icon file are cut to 259 bytes
type: bug
status: open
severity: 4
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

# User Menu compare names and the Change Icon file are cut to 259 bytes

## Problem

Two more dialogs read a typed path with `ti.EditLine(..., MAX_PATH)` and use the text cut at a
whole character when its UTF-8 form is longer than 259 bytes (87 or more CJK letters):
- the User Menu's "names to compare" dialog (`CCompareArgsDlg`, a User Menu item using the
  compare-names arguments): the two full names are cut, the compare tool is started with other
  names;
- the Change Icon dialog (`CChangeIconDialog`): the icon file name is cut, another file is read for
  icons (or none).
Nothing is deleted or overwritten; the result is wrong, a shorter path is the workaround.

## Evidence

By reading (review 1 of feature 291), at c767771e on branch `291-masks-cut-rest`:
- `src/dialogs2.cpp` `CCompareArgsDlg::Validate` (about lines 1227-1245) reads both fields into
  `char buf[MAX_PATH]` with `ti.EditLine` (only an empty check); `CCompareArgsDlg::Transfer` (about
  line 1250) - `ti.EditLine(IDE_UMC_NAME1, CompareName1, MAX_PATH)`, the same for `IDE_UMC_NAME2`;
  the buffers are `CUserMenuAdvancedData::CompareName1/2[MAX_PATH]` (`src/execute.h:118`).
- `src/dialogs3.cpp` `CChangeIconDialog::Transfer` (about line 2382) -
  `ti.EditLine(IDE_CHI_FILENAME, IconFile, MAX_PATH)`.
- 251's entry already notes `CCompareArgsDlg`'s browse as "checked by reading".
- The pattern: `DlgItemTextFitsU8` in `Validate` (features 214, 251, 270, 291).

## Expected

Each dialog's `Validate` measures its fields whole (`DlgItemTextFitsU8`, `MAX_PATH`) and refuses
with "The path specified is too long." before anything else; nothing cut is used. Probe rows
(before FAIL, after PASS) and a control that fits, as 291's `Mask-Row`.

## Notes

Not measured. Reaching `CCompareArgsDlg` needs a User Menu item with the compare arguments and
the "show names" confirmation on; `CChangeIconDialog` is reached from the User Menu or hot path
configuration - check which callers exist before writing the probe.

## Log

- 2026-10-21 — created (source review:291)
- 2026-10-21 — moved to Next position 25
