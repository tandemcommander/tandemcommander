---
title: Refreshing a changed archive with edited files lists it twice
type: improvement
status: open
severity: 2
area: archives
source: manual
who: agent
created: 2026-10-21
updated: 2026-10-23
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Refreshing a changed archive with edited files lists it twice

## Problem

When another program changed an archive whose files the user is editing (F4) and the panel refreshes (Ctrl+R or the automatic refresh), the archive is listed twice: once by feature 153's check before the Archive Update dialog, once by the panel's reopen. On a large archive (or a slow share) the user waits for the listing twice.

## Evidence

By reading at ded1c8a7: `ChangePathToArchive` (`src/fileswn2.cpp` ~2609-2619: the archive file changed, `IDS_ARCHIVEREFRESHEDIT`, `goto _REOPEN_ARCHIVE`) closes the path through `PrepareCloseCurrentPath` (`src/fileswn2.cpp` ~1354) -> `CFileTimeStamps::CheckAndPackAndClear` -> `MarkChangedInArchive` (`src/salamdr3.cpp` ~3763: `PackList` into a temporary `CSalamanderDirectory`, released at its end), then the reopen lists the archive again. Recorded as limit (3) of feature 153 (`specs/153-archive-member-changed-warning/fix-log.md`, *Review*, "LOW - recorded"). The cost was not measured.

## Expected

Measured first: the time of the two listings on a large archive (e.g. 100,000 members, ZIP and 7z). If it matters: when the dialog packed nothing (Ignore, or the update failed) the reopen uses the check's listing instead of listing again; after an update the archive changed again and is listed once more, as now. If the measurement shows a negligible cost, the item is rejected with the numbers.

## Approach

The check's listing would have to outlive `CheckAndPackAndClear` and be handed to the reopen together with the archive's stamp at the time of listing (the reopen must not take a listing of an archive changed since). Plug-in data ownership follows `MarkChangedInArchive` (released only after a successful listing - 153's review CRITICAL).

## Notes

Severity 2: speed only, and only on the rare path "edited files + archive changed by another program". Split from `archive-update-change-detection-limits` (limit 3).

## Log

- 2026-10-21 — created (source manual)
- 2026-10-21 — moved to Next position 77
- 2026-10-23 — related item archive-update-change-detection-limits closed: split into: archive-update-same-stamp-member-decision, archive-update-archive-same-stamp, archive-update-time-zone-change-mark, archive-refresh-lists-changed-archive-twice - the parts replace it; maintainer 2026-10-23
