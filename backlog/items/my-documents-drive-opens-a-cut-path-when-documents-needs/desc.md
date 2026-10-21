---
title: My Documents drive opens a cut path when Documents needs more than 259 bytes
type: bug
status: open
severity: 4
area: long-paths
source: review:286
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

# My Documents drive opens a cut path when Documents needs more than 259 bytes

## Problem

`GetMyDocumentsOrDesktopPath` (`src/shellib.cpp`) reads the Documents (or Desktop) folder into
`char buff[2 * MAX_PATH]` and then copies it into the caller's buffer with
`lstrcpyn(path, buff, pathLen)` + `SalU8TrimIncompleteTail(path)`. Several callers pass
`pathLen = MAX_PATH`, so a Documents folder whose UTF-8 path needs more than 259 bytes (but fewer
than 260 UTF-16 units - e.g. `D:\` + 90 CJK letters, about 274 bytes) is cut at a whole character
and the "My Documents" drive (and the other callers) open **another folder** - the cut prefix.
A path is never cut (CLAUDE.md).

## Evidence

Found by the independent review of feature 286 (`specs/286-folder-shortcut-browse/fix-log.md`,
*Review*, SHOULD 2), by code reading at 547839c5 (branch `286-folder-shortcut-browse`):
`src/shellib.cpp` `GetMyDocumentsOrDesktopPath` - `buff[2 * MAX_PATH]`, `lstrcpyn(path, buff, pathLen)`,
`SalU8TrimIncompleteTail(path)`. Callers with `MAX_PATH`: `src/fileswn0.cpp` (Alt+F1/F2 My
Documents drive), `src/fileswn3.cpp` (`drvtMyDocuments`), `src/salamdr6.cpp` (three uses with
`MAX_PATH`; two others pass `SAL_MAX_PATH_UTF8`). Feature 286 removed the code-page fallback of
the helper it uses (a Documents path whose UTF-8 form does not fit `buff` now falls to the Desktop
instead of a code-page path) but left this cut. Not reproduced in the GUI.

## Expected

A Documents / Desktop path that does not fit the caller's buffer is refused (`FALSE`, the caller's
existing "not available" route or `IDS_TOOLONGPATH`), never cut; a long-path capable caller gets
it whole (a buffer of `SAL_MAX_PATH_UTF8`).

## Notes

Measure first: redirect Documents (or use a test seam) to a folder of 90 CJK letters and press the
My Documents drive. `buff` itself (`2 * MAX_PATH` bytes) also limits the long-path callers.

## Log

- 2026-10-21 — created (source review:286)
- 2026-10-21 — moved to Next position 18
