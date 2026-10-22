---
title: Whole-archive Unpack of a PAX tar skips deep members and may delete the archive
type: bug
status: open
severity: 8
area: data-safety
source: review:307
who: agent
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: M
feature: -
related: [opening-a-tar-whose-member-name-has-a-300-letter-component]
depends-on: []
reason: -
---

# Whole-archive Unpack of a PAX tar skips deep members and may delete the archive

## Problem

Unpacking a whole TAR archive (Unpack, Alt+F9) whose members carry PAX paths (Python `tarfile`, GNU tar `--format=posix`, Windows `tar.exe`) silently leaves out every member whose folder part is longer than 255 bytes, although NTFS takes such paths - a deep source tree, `node_modules`. Only one "(206) The filename or extension is too long." box appears, and the unpack still reports success, so with "Delete archive after unpacking" ticked the archive is deleted and the left-out members are lost. The same happens to a member whose name has a component over 255 characters (no file system takes it, but its data is lost with the archive).

## Evidence

At d92d8278 (`main`, feature 306): `src/plugins/tar/untar.cpp` `CArchive::ReadArchiveHeader` - the check `header.NameFromPax && !SalPaxNameFitsListingU8(header.Name, ...)` sets `header.Ignored` in every pass, also in `CArchive::UnpackWholeArchive` (`ReportRefusedNames = TRUE` there, one message only); `SalPaxNameFitsListingU8` (`src/common/salpaxheader.h`) is the panel LISTING's bound (folder part and folder name at most `MAX_PATH - 5` bytes), not a file-system bound. `CPluginInterfaceForArchiver::UnpackWholeArchive` (`src/plugins/tar/tardll.cpp`) adds the archive to `archiveVolumes` for deletion when `delArchiveWhenDone` and returns the unpack's TRUE.

Measured by review 2 of feature 307 for the same check applied to GNU long names on branch `307-tar-long-component` (fixtures in the reviewer's `%TEMP%\rev307b`, recorded in `specs/307-tar-long-component/fix-log.md`, *Review 2*): a tar with 30 files under 10 folders of 29 letters (folder part 299 bytes) + ok.txt - 0.1.10 extracts all 31 files, the branch only ok.txt; with Delete-after-unpack the branch deletes t.tar (30 files lost). For PAX paths on `main`: not measured, by reading the same code path.

## Expected

Whole-archive Unpack (and every extraction pass) extracts every member a file system takes, whatever the panel listing could hold; the listing bound applies only while building the listing (`ListArchive`). A member that cannot be extracted (a component over 255 UTF-16 units) is reported and makes the whole unpack fail, so "Delete archive after unpacking" never deletes an archive whose members were not all extracted. Measured with an Unpack row and an Unpack + Delete-archive row (deep PAX tree), and the 306 probe unchanged.

## Notes

Severity from the band "data loss in a narrow scenario" (deep PAX paths + the delete option; silent omission without it). The same correction is needed for GNU long names in feature 307 (blocked item `opening-a-tar-whose-member-name-has-a-300-letter-component`, branch `307-tar-long-component`), whose refusal reuses this check - one feature can fix both.

## Log

- 2026-10-22 — created (source review:307)
- 2026-10-22 — moved to Next position 1
