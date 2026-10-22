---
title: Hex mode in Find turns quoted letters outside the code page into question marks
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

# Hex mode in Find turns quoted letters outside the code page into question marks

## Problem

In hex mode the Find dialog's Containing field and the viewer's Find field accept quoted text
(`"abc" 0D 0A`). Every edit runs `DoHexValidation`, which reads the field with ANSI `WM_GETTEXT`
and writes it back with ANSI `WM_SETTEXT`: quoted letters outside the system code page become `?`
as soon as the user types anything, and the search then looks for `?` bytes.

## Evidence

At 706df73a (branch `311-find-containing-cut`), measured by review 1 of feature 311:
- `src/viewer.cpp` `DoHexValidation` (about line 174): `SendMessage(edit, WM_GETTEXT, textLen,
  (LPARAM)text)` (about line 185) and `SendMessage(edit, WM_SETTEXT, 0, (LPARAM)text)` (about line
  275). Called from `CFindDialog` on `CBN_EDITUPDATE` of `IDC_FIND_CONTAINING`
  (`src/finddlg1.cpp`, about line 3663) and from `CFindSetDialog` for `IDC_FINDTEXT`
  (`src/viewer.cpp`, about line 476).
- Review 1 of 311 (temporary row `hex-type`): Find, hex mode on, the field set to `"` + 5 CJK
  letters + `"`, one `WM_CHAR` space sent: the field became `"?????" `.
- `specs/311-find-containing-cut/fix-log.md`, section *Review*.

## Expected

`DoHexValidation` reads and writes the field as wide text (`SalGetWindowTextU8` /
`SalSetWindowTextU8` or the W messages), keeping the caret; quoted letters stay as typed and are
searched as their UTF-8 bytes (as `ConvertHexToString` already copies quoted bytes).

## Notes

Older than feature 311 (not introduced by it). 311's probe row `grep-hex` reaches a hex-mode text
by `WM_SETTEXT` only, which does not run the validation. Check that the validation's own length
handling (`textLen` bytes) refuses rather than cuts once it reads UTF-8.

## Log

- 2026-10-22 — created (source review:311)
- 2026-10-22 — moved to Next position 27
