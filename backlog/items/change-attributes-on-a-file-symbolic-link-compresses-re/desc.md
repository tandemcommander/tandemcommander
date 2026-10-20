---
title: Change Attributes on a file symbolic link compresses / re-times the target file
type: bug
status: open
severity: 5
area: data-safety
source: leftover:253
who: agent
created: 2026-10-20
updated: 2026-10-21
verified: 2026-10-21 8b08f1da
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Change Attributes on a file symbolic link compresses / re-times the target file

## Problem

Feature 253 made Change Attributes on a junction / directory symbolic link change the link's own
compression and times (and refuse its encryption). A **file** symbolic link still reaches its
target file: `CompressFile` / `UncompressFile` open it without `FILE_FLAG_OPEN_REPARSE_POINT` (the
target file is compressed / uncompressed), the times handle in `DoChangeAttrs` opens it with flags 0
(the target file is re-timed), and `MyEncryptFile` / `MyDecryptFile` would encrypt / decrypt the
target. Reachable from a selected file symbolic link, and with "Include subdirectories" whenever a
selected folder holds a file symbolic link pointing outside the selection.

## Evidence

Review of feature 253 (`specs/253-attrs-link-own-entry/fix-log.md`, *Review*, SHOULD 1), at
commit ca995dd2: the reviewer made `mklink in\f.txt out\T.TXT` and opened `in\f.txt` with the
worker's flags - compression with `FILE_FLAG_BACKUP_SEMANTICS` left the link uncompressed and
compressed the target; times with flags 0 left the link at 2026 and set the target to 2001. Sites:
`src/worker.cpp` `CompressFile` / `UncompressFile` (the `SalCreateFile` calls), `DoChangeAttrs`
(the time handle; `SalAttrsOpenFlags` in `src/common/salreparse.h` returns 0 for a file),
`MyEncryptFile` / `MyDecryptFile`.

## Expected

Change Attributes on a file symbolic link changes only the link (or refuses what a link cannot
take, as 253 does for a directory link's encryption); the target file's compression, times and
encryption stay.

## Notes

Feature 253 kept file symbolic links unchanged because its item named junctions / directory
symbolic links only. The link rule for files must not catch reparse files that are not links
(cloud placeholders, deduplicated files - not name surrogates); creating a file symbolic link needs
the privilege or Developer Mode, so a probe may have to record NOT DRIVEN rows.

## Log

- 2026-10-20 — created (source leftover:253)
- 2026-10-20 — moved to Next position 6
- 2026-10-21 — verified at 8b08f1da: reproduced at 8b08f1da: hidden-desktop probe on a file symlink - COMP/UNCOMP/TIME/SUBC change the target file, not the link (4 FAIL)
