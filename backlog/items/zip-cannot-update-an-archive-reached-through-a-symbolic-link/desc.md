---
title: ZIP cannot update an archive reached through a symbolic link
type: bug
status: new
severity: 4
area: archives
source: review:320
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# ZIP cannot update an archive reached through a symbolic link

## Problem

Since feature 320 the ZIP plug-in puts a changed archive in place with one `ReplaceFileW` step. When
the archive's name is a file symbolic link (`a.zip` -> `D:\real\a.zip`), adding files to it or
deleting members from it (default "create temporary backup of zip") fails: the user sees "Cannot
replace original archive with temporary working file. Archive was not changed." and nothing changes
(true now, but the update cannot be done through the link). Before 320 the operation "succeeded" by
deleting the link and renaming the temporary file to its name: the link became a plain file and the
real archive was left stale.

## Evidence

Review of feature 320 (`specs/320-zip-failed-replace/fix-log.md`, *Review*, review 2, SHOULD 1):
standalone P/Invoke comparison under `%TEMP%` - old algorithm on a file symbolic link: the link
replaced by a plain file, the real archive OLD; new (`SalReplaceWithTempW`): `ReplaceFileW` fails with
1464 (ERROR_SYMLINK_NOT_SUPPORTED), not in the fallback list of `SalReplaceFailureNext`
(`src/common/salsafereplace.h`), result "kept". The earlier reviewer's extended probe rows
add-symlink / del-symlink (`%TEMP%\rev320\after_review.txt`, not in the repository) showed the
message, the link kept, no stray file. Site: `CZipPack::ReplaceArchiveWithTemp`
(`src/plugins/zip/add.cpp`, branch `320-zip-failed-replace`).

## Expected

Adding to or deleting from an archive reached through a symbolic link updates the real archive (the
link stays a link), or the plug-in says clearly that it cannot - never replaces the link by a plain
file.

## Approach

Resolve the final path (`GetFinalPathNameByHandleW` on the opened archive) and make the temporary
file next to the real archive (same volume), then replace there; or refuse up front with a clear
text (a new string - the two-stage `.slt` refresh). Measure first how the panel, Pack and the
archive-edit route name such an archive.

## Notes

- Not verified: directory links / junctions in the archive's path (only the last component being a
  link was measured); hard links behave as before (only the name is replaced).
- Severity 4: the update does not work but nothing is lost and the message is true; a workaround
  exists (work on the real path).

## Log

- 2026-10-23 — created (source review:320)
- 2026-10-23 — related item zip-says-the-archive-was-not-changed-after-a-failed-replace done in feature 320
