---
title: Renamer: a new name is capped at 259 bytes; a subfolder item refused at 260
type: bug
status: in-progress
severity: 3
area: long-paths
source: review:207
who: agent
created: 2026-10-15
updated: 2026-10-21
verified: 2026-10-21 c02b0f78
effort: M
feature: 282
related: []
depends-on: []
reason: -
---

# Renamer: a new name is capped at 259 bytes; a subfolder item refused at 260

## Problem

Recorded by 207's review (refusals, not cuts): a new name is capped at 259 bytes of UTF-8 (`newName[MAX_PATH]` and the related buffers), so a long item cannot be renamed to another long name - only Undo restores it; an item found through "Include subdirectories" is refused at 260 bytes while a selected one is accepted.

## Evidence

Migrated from specs/NEXT-WORK.md §A item 11 (L319) (at 7993914c). specs/207-renamer-long-source-path/fix-log.md, *Review* (~lines 55-58). At 7993914c: `src/plugins/renamer/rendlg2.cpp` ~196 `char newName[MAX_PATH]`.

## Expected

A new name of any length the file system accepts is built on the heap (never cut); selected items and items from subdirectories follow the same limit.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
- 2026-10-20 — related item renamer-regex-single-byte-classes done in feature 254
- 2026-10-21 — verified at c02b0f78: reproduced at c02b0f78: probe ren_longnew_probe 11/7 - long new names Expanded string is too large, subdir items too long path
- 2026-10-21 — run started, feature 282
