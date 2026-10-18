---
title: Drive list and folder type names use code-page shell texts
type: bug
status: open
severity: 3
area: encoding
source: next-work
who: both
created: 2026-10-13
updated: 2026-10-18
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Drive list and folder type names use code-page shell texts

## Problem

`SHGetFileInfoA` texts are read as UTF-8 later: `icncache.cpp:709` (type name of folders), `drivelst.cpp:1115` (display name of removable drives); the same holds for `UpDirTypeName` (`salamdr1.cpp` 917, `LoadStr` - code page). The drive menu's texts mix `LoadStr`, `GetVolumeInformation` A (the CD thread, `drivelst.cpp` ~1150) and UTF-8 ones. Wrong only with a Windows display language outside the program's code page (e.g. an English non-Unicode locale with a Czech display language), where `SHGetFileInfoA` already gives '?', or with a removable / CD drive named in another script.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L825-835 (second verification of 124-128, item 7). Read 2026-10-15: the panel measures and draws these texts as UTF-8 with a code-page fallback (`fileswn2.cpp` ~4191, `fileswn4.cpp` ~908 / 973).

## Expected

Folder type names, removable / CD drive names and the drive menu's texts come from wide APIs and are UTF-8 throughout; one change for the drive list.

## Notes

Not reproducible on this machine (Czech display language in code page 1250); needs a machine whose display language is outside its code page, or a removable / CD drive named in another script, to measure.

## Log

- 2026-10-15 — read: the panel draws these texts as UTF-8 with a code-page fallback, so a code-page text is right where the display language is in the program's code page - not reproducible on this machine (Czech, 1250)
- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-18 — 246 made the network drive texts of the Change Drive menu and the drive bar tooltip Unicode-exact (WNetGetConnectionW); the remembered-path enumeration and the reconnection chain remain code page (item remembered-network-drive-with-a-non-code-page-or-long-path)
