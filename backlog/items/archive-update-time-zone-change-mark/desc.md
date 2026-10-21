---
title: Archive Update: a time-zone or daylight-saving change marks an unchanged member
type: bug
status: new
severity: 2
area: archives
source: manual
who: both
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: [archive-update-change-detection-limits]
depends-on: []
reason: -
---

# Archive Update: a time-zone or daylight-saving change marks an unchanged member

## Problem

Feature 153's Archive Update warning compares an edited member's listed time with the time the panel listed at the F4. The ZIP plug-in turns a member's DOS time (local time) into UTC with the offset in force at the moment of listing, not the one of the member's date. When the time zone or daylight saving changes between the panel's listing and the update, and the archive file changed meanwhile (another member edited by another program), every member's time shifts by the change and the edited file is marked "changed in the archive" although nobody touched that member - a needless warning (nothing is withheld, the update still works).

## Evidence

By reading at ded1c8a7 (not reproduced - it needs a change of the machine's time zone): ZIP `src/plugins/zip/common.cpp` ~1542-1546 (`DosDateTimeToFileTime` then `LocalFileTimeToFileTime`); the F4 keeps `f->LastWrite` of the panel's listing (`src/fileswn6.cpp` ~3489-3493, `ExecuteFromArchive`); `SalEditedMemberChangedInArchive` (`src/common/salarcedit.h`) compares the times exactly. Without a change of the archive file nothing is listed (`SalArchiveChangedSinceEdit`), so the case needs both. Recorded as limit (2) of feature 153 (`specs/153-archive-member-changed-warning/fix-log.md`, *Review*, "LOW - recorded").

## Expected

A time-zone or daylight-saving change alone marks nothing: a member whose new listed time differs from the F4's by exactly the change of the offset between the two listings (and has the same size) is not marked; a member with any other difference still is. Formats that store UTC (7z, ZIP's NTFS extra field) keep comparing exactly. A pure rule in `src/common/salarcedit.h` with saltests checks.

## Approach

Record the current time-zone bias with the panel's listing of the archive (or at the F4, with the risk named in the spec) and again at the update's listing; accept `now == edit + (biasEdit - biasNow)` as unchanged. Measure first how the 7-Zip plug-in and external archivers convert times (some may already be UTC). A GUI probe cannot change the machine's time zone on the maintainer's machine: test the rule in saltests and, if a seam is added (a debug-only bias override), on the hidden desktop.

## Notes

`who: both`: a person checks it once on a machine whose time zone is switched (or across a daylight-saving date). Split from `archive-update-change-detection-limits` (limit 2).

## Log

- 2026-10-21 — created (source manual)
