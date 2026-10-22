---
title: Filter dialog cuts a long panel filter to 259 bytes after a refused edit
type: bug
status: open
severity: 4
area: long-paths
source: review:298
who: agent
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Filter dialog cuts a long panel filter to 259 bytes after a refused edit

## Problem

The panel's filter can be longer than 259 bytes: a tab's filter is read from the registry with
`SAL_TAB_FILTER_MAX` (1001) bytes and becomes the panel's `Filter` when the tab is activated. The Filter
dialog edits the panel's own `CMaskGroup`. When the user changes the field to a text with a syntax error,
`CFilterDialog::Validate` restores the filter from a backup that was cut to `MAX_PATH` - so after the error
box (and Cancel) the panel keeps the first 259 bytes of its original filter, unprepared. A cut mask matches
other files than the user's filter did (and the failed preparation leaves the group with no prepared masks).

## Evidence

Review of feature 298 (NOTE 4, `specs/298-mask-group-long-mask/fix-log.md` *Review*), by reading at the
branch `298-mask-group-long-mask` (based on 1bc8f164): `src/dialogs3.cpp` `CFilterDialog::Validate` -
`char buf[MAX_PATH]; lstrcpyn(buf, Filter->GetMasksString(), MAX_PATH); // backup`, then
`ti.EditLine(IDE_FILTER, Filter->GetWritableMasksString(), MAX_PATH)`, `Filter->PrepareMasks(errorPos)` fails,
`Filter->SetMasksString(buf); // restoration`. The dialog gets `&Filter` of the panel
(`src/fileswn9.cpp`, `CFilterDialog(HWindow, &Filter, ...)`). Tab filters: `src/mainwnd2.cpp` reads
`PANEL_FILTER` of a tab with `SAL_TAB_FILTER_MAX`; `src/paneltabs.cpp` sets it into `Filter` on activation.
Not reproduced.

## Expected

A refused edit in the Filter dialog leaves the panel's filter exactly as it was (whole, prepared) - the
backup holds the whole group text (or the dialog validates a copy, not the panel's own group).

## Notes

Not verified: whether the dialog shows a filter longer than 259 bytes at all (`CB_LIMITTEXT` is
`MAX_PATH - 1`, but `SalSetWindowTextU8` sets the whole text) and whether a field over 259 bytes is refused
earlier by `DlgItemTextFitsU8` (feature 270) - the cut needs the user to shorten the field to an invalid
text. Measure first: a tab filter of 300 bytes in the registry, activate the tab, open the dialog.

## Log

- 2026-10-22 — created (source review:298)
- 2026-10-22 — related item mask-group-prepare-unbounded-mask-copy done in feature 298
- 2026-10-22 — moved to Next position 25
