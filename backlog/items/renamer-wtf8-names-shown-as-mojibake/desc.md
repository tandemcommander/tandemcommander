---
title: Renamer: a name or history text with an unpaired surrogate is shown as mojibake
type: bug
status: new
severity: 2
area: other-plugins
source: measure:255
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Renamer: a name or history text with an unpaired surrogate is shown as mojibake

## Problem

Two places of the Batch Renamer (Ctrl+Shift+R) decide "UTF-8 or code page" with a raw strict
`MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, ...)`. A name with an unpaired UTF-16
surrogate (legal on NTFS) is WTF-8 in the program since feature 066, which that call rejects, so
the text takes the code-page branch:

1. the **preview list** shows such a file's old and new name as mojibake (the whole name, not
   only the surrogate);
2. the **history combo boxes** (Mask, New name, Search, Replace, Command - `HistoryComboBox` of
   `shared/lukas`) add such an entry with the A message; the initial text is set the same way,
   and when the dialog is confirmed without editing, the mojibake is read back as the value.

Only names or typed texts holding an unpaired surrogate are affected; everything else is valid
UTF-8 and takes the wide path.

## Evidence

By reading, at e849e68c: `src/plugins/renamer/preview.cpp` (the `LVN_GETDISPINFOW` text branch:
strict probe, then `CP_ACP`); `src/plugins/shared/lukas/utildlg.cpp` `HistU8ToWAlloc` and its
callers in `HistoryComboBox` (used by `renamer/rendlg.cpp` and `renamer/dialogs.cpp` only).
Reported by `python tools/check_encoding.py --plugins` (`strict-probe-rejects-wtf8`, 3 lines);
verdicts in `specs/255-plugin-encoding-findings/verdicts.md`. The rule's definition:
`tools/check_encoding.py` (feature 066 invariant).

## Expected

A file named `Lone<U+D800>.txt` shows in the preview as the core shows it in the panel; a history
entry holding such a text shows and round-trips unchanged; `check_encoding.py --plugins` no
longer reports either file.

## Approach

Decode with the WTF-8 helpers `SplU8ToW` / `SplU8ToWAlloc` (`splunicode.h`, feature 089), keep the
code-page fallback for what they still reject. Probe on the hidden desktop with a lone-surrogate
fixture as feature 066/089 did.

## Notes

`shared/lukas/utildlg.cpp` is compiled into other projects too (filecomp, pictview, zip); only the
Renamer calls `HistoryComboBox`.

## Log

- 2026-10-20 — created (source measure:255)
- 2026-10-20 — set area=other-plugins
