---
title: File Comparator hex recompare: error box from the released sibling view
type: bug
status: new
severity: 2
area: other-plugins
source: review:266
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

# File Comparator hex recompare: error box from the released sibling view

## Problem

A recompare of two binary files in the File Comparator's hex view (window open) can show a spurious "cannot access the file" error box. `WN_BINARY_FILES_DIFFER` destroys both views' data first, then `SetData(left)` -> `UpdateScrollBars(TRUE)` -> `UpdateWindow` repaints the left view while the right view's mapping is already released. The left `Paint` maps the sibling's data by its own stored `SiblinkSize`, not by the sibling's current size, so it asks the released sibling mapping for a view, gets NULL and posts `WM_USER_HANDLEFILEERROR`. Before 266 the box gave the reason "The handle is invalid"; since 266 (`CFileMapping::Destroy` resets `FileSize`) `MapViewOfFile` returns NULL without setting a last error, so the box shows whatever `GetLastError()` holds (possibly no reason). The repaint happens when `BytesPerLine` changes in the recompare, e.g. when the address needs one more digit. Existed before 266 (found by its review, not measured).

## Evidence

At 266 (branch `266-close-stray-box`): `src/plugins/filecomp/mainwnd.cpp` `WN_BINARY_FILES_DIFFER` (both `DestroyData` calls, then `SetData` of each view in turn); `src/plugins/filecomp/viewwnd3.cpp` `CHexFileViewWindow::Paint` (the sibling branch: `ViewOffset + clipFirstRow * BytesPerLine < SiblinkSize` -> `Siblink->Mapping.MapViewOfFile` -> `HandleFileError`); `src/plugins/filecomp/filemap.cpp` `CFileMapping::MapViewOfFile` (`FileSize == 0` -> NULL). Review of 266: `specs/266-close-stray-box/fix-log.md`, *Review*, SHOULD-2. Suggested reproduction (not run): compare two different binary files of 0xFFFF bytes in the hex view, replace them with 0x10000-byte versions and recompare at a window width where the extra address digit changes the bytes per line.

## Expected

A recompare shows no error box for data it released itself: the views do not paint against a released sibling (e.g. paint disabled on both views until both have new data, or the sibling's current size checked in `Paint`); a real read error still shows its box with its reason.

## Log

- 2026-10-20 — created (source review:266)
