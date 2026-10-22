---
title: Unpacking a tar leaves hard-linked files out silently and Delete archive after unpacking then deletes the archive
type: bug
status: open
severity: 7
area: data-safety
source: review:308
who: agent
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Unpacking a tar leaves hard-linked files out silently and Delete archive after unpacking then deletes the archive

## Problem

Unpacking a whole tar archive (Unpack, Alt+F9) leaves out every member stored as a hard link without a word, and the unpack still counts as successful - with "Delete archive after unpacking" ticked the archive is deleted and those files are lost. GNU tar and Python `tarfile` store a second name of the same file (a hard link in the source tree, common in backups and package trees) as a link member that refers to the first one, so the file arrives under its first name only and its other names disappear with the archive. Symbolic links are skipped the same way (the plug-in never extracts links).

## Evidence

Measured by the independent review of feature 308 (branch `308-pax-deep-unpack`, Debug x64, hidden desktop, fixtures in the reviewer's `%TEMP%\rev308`, row R-HARDLINK-DEL, log `rev_hardlink.txt`): a tar with `a.txt` and a hard link `sub/b.txt` to it, whole Unpack with Delete-after-unpack - only `a.txt` extracted, no message, the archive deleted. Code: `src/plugins/tar/untar.cpp` `CArchive::ReadTarHeader` sets `header.Ignored` for link types (the type switch near the end of the function, "What we don't support (everything except files & dirs) has zero size and Ignored set"); `CArchive::DoUnpackArchive` skips Ignored members and returns TRUE; `CPluginInterfaceForArchiver::UnpackWholeArchive` (`src/plugins/tar/tardll.cpp`) has put the archive into `archiveVolumes` and the core (`src/fileswn7.cpp`, the unpack handler) deletes it on TRUE. Behaviour inherited from Open Salamander (also in 0.1.10, not caused by feature 308).

## Expected

A hard-link member is extracted as a copy of (or a hard link to) the file it names, when that file was extracted in the same operation; a link member that cannot be reproduced (a symbolic link, a hard link to a member outside the selection) is reported, and a whole unpack that left a member out ends as failed so "Delete archive after unpacking" keeps the archive - the rule feature 308 applied to refused PAX names. Measured with an Unpack + Delete row (hard link, symbolic link) and the 308 probe unchanged.

## Notes

Severity from the band "data loss in a narrow scenario" (link members + the delete option; silent omission without it). Whether symbolic links should be created (they need a privilege or Developer Mode on Windows) is a separate question; this item only asks that leaving them out is reported and keeps the archive.

## Log

- 2026-10-22 — created (source review:308)
- 2026-10-22 — moved to Next position 2
