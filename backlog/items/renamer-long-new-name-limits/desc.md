---
title: Renamer: a new name is capped at 259 bytes; a subfolder item refused at 260
type: bug
status: open
severity: 3
area: long-paths
source: review:207
who: agent
created: 2026-10-15
updated: 2026-10-23
verified: -
effort: M
feature: -
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
- 2026-10-21 — blocked: the second independent review found MUST findings: a regex over a long built name overflows the stack and kills the program; manual mode reads the wrapped display lines and renames to a cut name - see the fix-log Review 2 and Stopped (feature 282, branch 282-renamer-long-new-name)
- 2026-10-23 — unblocked: rules of 2026-10-23: a run carries over origin/282-renamer-long-new-name (SKILL.md 4.6) and fixes review 2 MUST 1 (regex stack on long names) and MUST 2 (manual mode wrapped lines), corrects the CHANGELOG entry, up to three reviews
