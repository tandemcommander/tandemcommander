---
title: Archive Update: an archive rewritten with its old size and time is not checked again
type: bug
status: new
severity: 3
area: archives
source: manual
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: [archive-update-change-detection-limits]
depends-on: []
reason: -
---

# Archive Update: an archive rewritten with its old size and time is not checked again

## Problem

Feature 153's Archive Update warning lists the archive again only when the archive file's time or size differs from the F4. Another program that rewrites the archive and keeps its size and last-write time (`7z -stl` sets the archive's time from its newest member; FAT keeps 2-s times; tools that restore times) is taken for "the archive it was": nothing is listed, and a member it changed is not marked - "Update" overwrites that change without the warning.

## Evidence

By reading at ded1c8a7 (not reproduced - 153's probe rewrites the archive with a new time): `GetArchiveFileStamp153` (`src/salamdr3.cpp` ~3746) keeps only `GetFileTime` last-write and the size; `SalArchiveChangedSinceEdit` (`src/common/salarcedit.h` ~70) returns FALSE when both are equal and `CFileTimeStamps::MarkChangedInArchive` (`src/salamdr3.cpp` ~3791) then skips the listing. Recorded as limit (1) of feature 153 (`specs/153-archive-member-changed-warning/fix-log.md`, *Review*, "LOW - recorded").

## Expected

An archive file rewritten in place or replaced keeps its last-write time and size and the member changed in it is marked: a new probe row (in the style of 153's `member_changed_probe.ps1`, the archive's time and size restored after the rewrite) passes; 153's eleven rows still pass. Where the volume gives no change time or file identity (FAT, some network shares) the behaviour stays as it is.

## Approach

Add to `CFileTimeStampsArcStamp` the archive's NTFS change time (`GetFileInformationByHandleEx(FileBasicInfo)`.`ChangeTime`, which ordinary tools do not set back) and its file identity (`FileIdInfo`: volume serial + 128-bit id - a replaced file gets a new one); a pure rule in `salarcedit.h` with saltests: a known value that differs = changed, unknown on either side = compare as today. Measure first with a probe row that rewrites the archive and restores its time (`os.utime`) and size.

## Notes

The panel's own "the archive file has changed" check on refresh (`ChangePathToArchive`, `src/fileswn2.cpp` ~2609, `IDS_ARCHIVEREFRESHEDIT`) has the same blind spot for its reopen; not verified - say in the feature whether it shares the rule. Split from `archive-update-change-detection-limits` (limit 1, the archive part); the member part is `archive-update-same-stamp-member-decision`.

## Log

- 2026-10-21 — created (source manual)
