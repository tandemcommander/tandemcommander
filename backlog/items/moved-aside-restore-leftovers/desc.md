---
title: A file moved aside to salNNN can stay there silently on the create paths
type: bug
status: open
severity: 3
area: data-safety
source: leftover:221
who: agent
created: 2026-10-15
updated: 2026-10-17
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# A file moved aside to salNNN can stay there silently on the create paths

## Problem

When a rename, a move or a create hits another entry's 8.3 short name, that entry is moved aside to `salNNN`, the operation done, and the entry moved back. Feature 221 retries a failed move-back and reports it for Quick Rename and the worker's move. Left: (1) the create paths `SalCreateFileEx`, `SalCreateDirectoryEx` and `SafeFileCreate` have no window - a failed move-back is still only a trace, so the user's file stays renamed to `salNNN` and nothing says so (an out parameter would be needed); (2) PictView's and the Renamer's move-back report the failure but have no retry (`SalMoveFile` through the plug-in interface - a local loop each).

## Evidence

Migrated from specs/NEXT-WORK.md §A item 11 (L297) (at 7993914c). specs/221-moved-aside-restore/fix-log.md (lines ~36-40, "Recorded in specs/NEXT-WORK.md"); the earlier chain: features 199, 201, 202, 203.

## Expected

On every route a failed move-back is retried and, if it still fails, the user is told which entry was left under which `salNNN` name.

## Approach

Not drivable as it stands: the failure is a race (another process holds the entry between the two moves); 221's approach - a seam or a held handle in the probe - applies.

## Notes

Severity: the content is never lost, it is left under another name; narrow (a scanner or an indexer holding the entry at that moment).

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
