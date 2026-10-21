---
title: Registry Editor Find: regexp misses text past the code-page length of a value
type: bug
status: in-progress
severity: 4
area: other-plugins
source: review:257
who: both
created: 2026-10-20
updated: 2026-10-21
verified: 2026-10-21 cffe5eca
effort: S
feature: 278
related: []
depends-on: []
reason: -
---

# Registry Editor Find: regexp misses text past the code-page length of a value

## Problem

Registry Editor Find with **Regular expression**, on a machine whose ANSI code page is multi-byte
(UTF-8 65001, or 932 / 936 / 949 / 950): a text value or name is converted to the code page into
a buffer sized by its UTF-16 unit count, and only that many bytes are scanned. A text whose
code-page form is longer (any non-ASCII letter under UTF-8) either does not fit - the conversion
fails and stale buffer bytes are searched - or its end is never searched. Example (by reading):
code page 65001, REG_SZ `čččč bar` is 8 units but 12 bytes; the regexp `bar` (with or without
Whole words) finds nothing. Single-byte code pages (1250, 1252) are not affected.

## Evidence

Found by the independent review of feature 257 (`specs/257-regedt-find-words-hex/fix-log.md`,
section *Review*), by reading - not reachable on the measuring machine (code page 1250).
`src/plugins/regedt/finddlg.cpp` at 3d2ffb53, `CFindThread::Test`, regexp branch (~1103-1114):
`len /= 2; AsciiBuffer.Reserve(len); WStrToStr(AsciiBuffer.Get(), AsciiBuffer.GetSize(), (LPWSTR)text, len);`
then the line loop runs to `text + len`. `WStrToStr` (`src/plugins/regedt/utils.h`) is
`WideCharToMultiByte(CP_ACP, 0, ...)`, which fails with a too small buffer (and writes a NUL
into its last byte).

## Expected

The regexp searches the whole code-page form of every text and name: the buffer is sized by
`WideCharToMultiByte(CP_ACP, 0, text, units, NULL, 0, NULL, NULL)` and the scanned length is the
converted byte count; a failed conversion is not searched as stale bytes. A `saltests` check or a
probe with a code-page parameter shows `čččč bar` found under 65001.

## Notes

The GUI case needs a machine with a UTF-8 (or DBCS) ANSI code page - a person's check (`who:
both`); the conversion rule can be proven in `saltests` with the code page as a parameter, as
feature 257 did for the hex pattern (`src/common/salregfind.h`).

## Log

- 2026-10-20 — created (source review:257)
- 2026-10-20 — related item regedit-find-whole-words-and-quoted-hex-letters done in feature 257
- 2026-10-20 — moved to Next position 18
- 2026-10-21 — verified at cffe5eca: present at cffe5eca: Test regexp branch sizes the CP_ACP buffer by units; WideCharToMultiByte(65001) of cccc bar into 8 bytes returns 0, needs 12; bar never scanned
- 2026-10-21 — run started, feature 278
