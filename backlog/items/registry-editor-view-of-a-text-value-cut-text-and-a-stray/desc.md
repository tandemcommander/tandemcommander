---
title: Registry Editor View of a text value: cut text and a stray byte on a UTF-8 code page
type: bug
status: open
severity: 4
area: other-plugins
source: review:278
who: both
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Registry Editor View of a text value: cut text and a stray byte on a UTF-8 code page

## Problem

Registry Editor, View (F3) of a text value (REG_SZ / REG_EXPAND_SZ / REG_MULTI_SZ) with the
default `ExportStringsForViewerInASCII = TRUE`, on a machine whose ANSI code page is multi-byte
(UTF-8 65001, or 932 / 936 / 949 / 950): the value is converted to the code page into a space of
one byte per UTF-16 unit and that many bytes are written to the viewer's temporary file. A text
whose code-page form is longer (any non-ASCII letter under UTF-8) does not fit: the conversion
fails, and the file gets the partial bytes, uninitialised heap bytes and a NUL - the viewer shows
a cut or garbled text. The same unit-sized buffer as the Find regexp fixed by feature 278.

## Evidence

Found by the independent review of feature 278 (`specs/278-regedt-find-regexp-cp/fix-log.md`,
section *Review*), by reading and by the real conversion call; not reachable on the measuring
machine (code page 1250).
`src/plugins/regedt/fs3.cpp` at 5a1b1a3b, `ExportValueData` (~344-368): `extra = size / 2`,
`malloc(size + extra)`, then
`WStrToStr((char*)data + size, size / 2, (LPWSTR)data, size / 2); translated = data + size; size /= 2;`
and `WriteFile(file, translated, size, ...)`. `WStrToStr` (`src/plugins/regedt/utils.h`) is
`WideCharToMultiByte(CP_ACP, 0, ...)` and on failure writes a NUL into the last byte of the space.
Reproduction (python ctypes `WideCharToMultiByte`, code page 65001): REG_SZ `a€` with its NUL is
6 bytes = 3 units; converted into 3 bytes the call returns 0 and leaves `a` and two untouched bytes.

## Expected

The viewer's temporary file holds the whole code-page form of the text: the space is sized by
`WideCharToMultiByte(CP_ACP, 0, text, units, NULL, 0, NULL, NULL)` (e.g. with
`SalRegFindTextToCodePage` of `src/common/salregfind.h`, feature 278), the written length is the
converted byte count, and a failed conversion is reported or falls back to the UTF-16 data -
never written as stale bytes. A `saltests` check or a probe with a code-page parameter shows it.

## Notes

The GUI case needs a machine with a UTF-8 (or DBCS) ANSI code page - a person's check
(`who: both`). Related: `regedit-key-name-buffer-size-and-move-rows` names another buffer of
`fs3.cpp` (line 218), a different defect.

## Log

- 2026-10-21 — created (source review:278)
- 2026-10-21 — related item regedit-key-name-buffer-size-and-move-rows done in feature 287
- 2026-10-21 — moved to Next position 21
