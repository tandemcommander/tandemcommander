---
title: ZIP does not say the temporary file is the only copy when the archive vanished
type: bug
status: open
severity: 3
area: archives
source: review:320
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ZIP does not say the temporary file is the only copy when the archive vanished

## Problem

When the ZIP plug-in has finished a change through its temporary working file and the archive has
meanwhile disappeared (another program deleted it) and the new content cannot take its name, the
temporary file `Sal*.tmp` is kept - it is the only copy of the archive. The user is told only
"Cannot open or create file." with the system error and the temporary file's full name, under the
archive's name: nothing says that this file holds the archive. Since the plug-in left stray
`Sal*.tmp` files for years (fixed in 320), a user is likely to delete it.

## Evidence

Review of feature 320 (`specs/320-zip-failed-replace/fix-log.md`, *Review*, review 2, SHOULD 2):
`CZipPack::ReplaceArchiveWithTemp` (`src/plugins/zip/add.cpp`, branch `320-zip-failed-replace`),
case `srrLeftAtTemp`: `ProcessError(IDS_ERRCREATE, err, ZipName, PE_NORETRY | PE_NOSKIP, NULL,
TempName)`. 320 used an existing string on purpose (FR-005: no new string in an autonomous run). The
core says it explicitly for the same case (`IDS_VIEWERCOPYKEPTTEMP`, `src/viewer3.cpp`,
`src/salamdr2.cpp`); PictView too (`src/plugins/pictview/saveas.cpp`). Not driven by any test (needs a
third party deleting the archive during the operation; 320 analyze C1).

## Expected

The message says that the archive could not be put back under its name and that its complete new
content was kept in the named file (e.g. "The archive ... was not found any more; its new content was
kept as ..."), in all enabled languages.

## Notes

- Needs a new UI string in `src/plugins/zip/lang/lang.rc2` - the two-stage `.slt` refresh
  (`translate.merge --templates`), CLAUDE.md (084).
- Severity 3: wording in a rare case; the file is kept, nothing is deleted by the program.

## Log

- 2026-10-23 — created (source review:320)
- 2026-10-23 — related item zip-says-the-archive-was-not-changed-after-a-failed-replace done in feature 320
- 2026-10-23 — moved to Next position 64
