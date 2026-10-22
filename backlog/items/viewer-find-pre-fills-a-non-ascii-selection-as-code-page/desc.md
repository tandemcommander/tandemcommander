---
title: Viewer Find pre-fills a non-ASCII selection as code-page text
type: bug
status: open
severity: 4
area: encoding
source: review:311
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

# Viewer Find pre-fills a non-ASCII selection as code-page text

## Problem

When text is selected in the internal viewer and Find is opened, the Find field is pre-filled with
the selection's raw bytes through an ANSI `WM_SETTEXT`: a UTF-8 selection with non-ASCII letters
shows as code-page mojibake (`é` becomes `Ă©` under code page 1250), and the search looks for that
text, which the file does not contain. Since feature 311 the viewer's Find refuses a text whose
UTF-8 form does not fit 200 bytes, so a long selection with such letters (e.g. 199 `a` + `é…`) is
now refused with "The path specified is too long." although the user typed nothing; before 311 it
was cut and searched (and still not found when it held non-ASCII bytes).

## Evidence

At 706df73a (branch `311-find-containing-cut`), by reading and measured by review 1 of feature 311:
- `src/viewer.cpp` `CFindSetDialog::Transfer` (about line 376) -
  `SendMessage(GetDlgItem(HWindow, IDC_FINDTEXT), WM_SETTEXT, 0, (LPARAM)buf)` with `buf` from
  `CViewerWindow::GetFindText` (`src/viewer2.cpp`, about line 1913; at most `FIND_TEXT_LEN - 1`
  bytes of the selection, hex mode three characters per byte).
- Review 1 of 311 (temporary probe row `view-sel`): `0sel.txt` (UTF-8, 199 x `a` + `é…`), Alt+F3,
  Select All, Find: the field held 200 units / 201 bytes ending in `Ă`, OK answered "too long".
- `specs/311-find-containing-cut/fix-log.md`, section *Review*.

## Expected

The pre-fill decodes the selection by the viewer's current encoding (UTF-8 / UTF-16 / code page,
as the viewer shows it) and sets the field as wide text; a selection longer than the field is
shortened at a whole character before it is shown (a seed, not the user's text); a selected
non-ASCII word is found by the search it pre-fills.

## Notes

Not a cut of typed text: the field's text is a suggestion the user sees before OK. Hex mode builds
the field from bytes (ASCII digits) and is not affected. Probe driver: 311's
`specs/311-find-containing-cut/probe/grep311_probe.ps1` (`View-Row`).

## Log

- 2026-10-22 — created (source review:311)
- 2026-10-22 — moved to Next position 29
