---
title: Renamer: Include subdirectories descends into junctions and folder links
type: bug
status: new
severity: 4
area: data-safety
source: review:282
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Renamer: Include subdirectories descends into junctions and folder links

## Problem

The Renamer's "Include subdirectories" reads every directory below the selected folder, also a
junction or a directory symbolic link: the files of the link's TARGET (possibly outside the
selection) are offered for renaming, and a link pointing back up (a loop) lists the same files once
per level. Before feature 282 the 260-byte path stopped a loop after some 50-130 levels; since 282
the listing goes down to its depth guard (1024 levels below the selected folder) - a loop lists the
same files about a thousand times before the "too long path name" box, and one rename of them
renames the first path and fails on the others.

## Evidence

By reading (not driven): `src/plugins/renamer/rendlg.cpp` `CRenamerDialog::LoadSubdir` at the
head of branch 282-renamer-long-new-name - `if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)`
recurses without a look at `FILE_ATTRIBUTE_REPARSE_POINT`. Found by the first review of 282
(`specs/282-renamer-long-new-name/fix-log.md`, *Review*, NOTE 3). The core's rule of 197 / 212
("a destructive recursion never descends into a reparse directory it could not prove a plain one")
is for deletes; a rename listing is not destructive, but renaming files outside the selection is
not what the user asked for.

## Expected

"Include subdirectories" lists a junction / directory link itself as an item (as a folder of the
selection) and does not descend into it - or descends only into links whose target lies inside the
selected folder and never twice into the same folder (by identity). A probe row: a junction to a
folder outside the fixture and a junction loop; the preview lists no file of the target, the
listing ends without the depth box.

## Notes

Which of the two behaviours is right may be the maintainer's choice (the core's own recursive
operations treat links per 197 / 212); the conservative one is "never descend into a link".

## Log

- 2026-10-21 — created (source review:282)
