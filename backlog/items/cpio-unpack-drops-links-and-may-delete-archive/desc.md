---
title: Unpacking a cpio or rpm leaves links out silently and may delete the archive
type: bug
status: open
severity: 6
area: archives
source: measure:309
who: agent
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: M
feature: -
related: [a-cpio-or-rpm-archive-with-a-member-name-the-panel-cannot]
depends-on: []
reason: -
---

# Unpacking a cpio or rpm leaves links out silently and may delete the archive

## Problem

The TAR plug-in also reads cpio archives (and the cpio payload of rpm packages). A cpio member whose mode is neither a regular file nor a folder - a symbolic link above all - is skipped, and the unpack still ends as successful, so "Delete archive after unpacking" deletes the archive with the links left out. cpio stores hard links differently from tar (the "new" format repeats the name with nlink > 1 and the data only in the last occurrence), so the earlier names may arrive as empty files. Feature 309 fixed the same pattern for tar link members only.

## Evidence

- `src/plugins/tar/untar.cpp` `CArchive::ReadArchiveHeader`: for non-tar formats `(header.Mode.LoDWord & CP_IFMT) != CP_IFREG` (and not a folder) sets `Ignored`; `DoUnpackArchive` skips `Ignored` members and returns TRUE; `SCommonHeader::LinkType` (feature 309) stays 0 for cpio. rpm: `CpioDoUnpackArchive` (`untar.cpp`) - not read in detail.
- Read during feature 309 (branch `309-tar-link-members`); **not measured** - no cpio fixture was run.

## Expected

Measure first (a newc cpio with a symbolic link and a hard-linked file, made by GNU cpio or Python, whole Unpack with "Delete archive after unpacking"). Then: a cpio link left out is reported and the unpack fails, so the archive is kept (the rule of features 308 / 309); hard-linked names arrive with their content.

## Notes

Severity from the tar case (7), one lower because not verified.

## Log

- 2026-10-22 — created (source measure:309)
- 2026-10-22 — moved to Next position 2
