---
title: Renamer: the preview shows a name with an unpaired surrogate as mojibake
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

# Renamer: the preview shows a name with an unpaired surrogate as mojibake

## Problem

The Batch Renamer's (Ctrl+Shift+R) preview list decides "UTF-8 or code page" for each text with a
raw strict `MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, ...)`. A name with an unpaired
UTF-16 surrogate (legal on NTFS) is WTF-8 in the program since feature 066, which that call
rejects, so the text takes the code-page branch: the preview shows such a file's old and new name
as mojibake - the whole name, not only the surrogate. Only names holding an unpaired surrogate are
affected; everything else is valid UTF-8 and takes the wide path. Display only - the rename
itself uses the names, not the preview text.

## Evidence

By reading, at e849e68c: `src/plugins/renamer/preview.cpp` (the `LVN_GETDISPINFOW` text branch:
strict probe, then `CP_ACP`). Reported by `python tools/check_encoding.py --plugins`
(`strict-probe-rejects-wtf8`); verdict in `specs/255-plugin-encoding-findings/verdicts.md` (branch `255-plugin-encoding-findings`). The
rule's definition: `tools/check_encoding.py` (feature 066 invariant).

## Expected

A file named `Lone<U+D800>.txt` shows in the preview as the core shows it in the panel;
`check_encoding.py --plugins` no longer reports `preview.cpp`.

## Approach

Decode with the WTF-8 helper `SplU8ToW` (`splunicode.h`, feature 089), keep the code-page fallback
for what it still rejects (resource strings). Probe on the hidden desktop with a lone-surrogate
fixture as feature 066/089 did.

## Notes

The history combo boxes are not affected: the Renamer links its own `HistoryComboBox`
(`renamer/dialogs.cpp`, `SplU8ToWAlloc`); the same-named function in
`shared/lukas/utildlg.cpp` is built by no project (review of feature 255).

## Log

- 2026-10-20 — created (source measure:255)
- 2026-10-20 — set area=other-plugins
- 2026-10-20 — set title=Renamer: the preview shows a name with an unpaired surrogate as mojibake
