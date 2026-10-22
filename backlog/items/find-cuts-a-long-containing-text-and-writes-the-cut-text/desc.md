---
title: Find cuts a long Containing text and writes the cut text back
type: bug
status: in-progress
severity: 5
area: long-paths
source: review:291
who: agent
created: 2026-10-21
updated: 2026-10-22
verified: 2026-10-22 95145b44
effort: S
feature: 311
related: []
depends-on: []
reason: -
---

# Find cuts a long Containing text and writes the cut text back

## Problem

The Find dialog's "Containing" text is limited to 200 UTF-16 units but read into 201 bytes of
UTF-8 (`GREP_TEXT_LEN`): 67 or more CJK letters (101 or more accented letters) are cut at a whole
character, and Find searches for the shorter text - it finds files that do not contain the typed
text, which the user may then delete from the results. As feature 291 measured for "Named",
`HistoryComboBox` writes the cut text back into the field and its history, also on Options > Add
Current / Manage / Ignore, so the cut stays.

## Evidence

By reading (review 1 of feature 291), at c767771e on branch `291-masks-cut-rest`:
- `src/find.h:31` - `#define GREP_TEXT_LEN 201`.
- `src/finddlg1.cpp` `CFindDialog::Transfer` (about line 1833) -
  `HistoryComboBox(HWindow, ti, IDC_FIND_CONTAINING, Data.GrepText, GREP_TEXT_LEN, ...)`.
- `src/viewer.cpp` `HistoryComboBox` (about line 69) - `SalGetWindowTextU8(hwnd, Text, textLen)`
  (cut), then `SalSetWindowTextU8(hwnd, Text)` (written back) and the history update.
- `src/finddlg1.cpp` `CFindDialog::LoadControls` - an option without a Containing text reads the
  field cut (`SalGetDlgItemTextU8(..., GREP_TEXT_LEN)`).
- The pattern: feature 291's Named checks in the same file (`Validate`, the three commands,
  `LoadControls`) and its probe `specs/291-masks-cut-rest/probe/mask291_probe.ps1` (`Find-Row`).

## Expected

A Containing text whose UTF-8 form does not fit `GREP_TEXT_LEN` is refused with "The path
specified is too long." (no new string) before any search and before Add Current / Manage /
Ignore read it; an option without Containing keeps the field's whole text; nothing cut is searched
for or stored. Probe rows as 291's `find-named` / `find-add` / `find-option` for Containing.

## Notes

Not measured. Hex mode and regular expressions read the same field - check both. The viewer's
own Find text (`FIND_TEXT_LEN`, "should match") may have the same cut; check it while there.

## Log

- 2026-10-21 — created (source review:291)
- 2026-10-21 — moved to Next position 12
- 2026-10-22 — verified at 95145b44: reproduced at 95145b44: hidden-desktop probe, Containing of 67 CJK letters searched cut (found 2, field cut) in text/regex/hex, Add Current, Ignore, option; viewer Find searched cut too
- 2026-10-22 — run started, feature 311
