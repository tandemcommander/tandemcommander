---
title: Unpack refused at a link names a temporary folder, not the archive folder
type: improvement
status: open
severity: 2
area: archives
source: leftover:249
who: agent
created: 2026-10-19
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Unpack refused at a link names a temporary folder, not the archive folder

## Problem

When an external unpacker restores a folder of the archive path as a junction / directory link,
feature 249 refuses the unpack (nothing is moved) with the existing message `IDS_PACKERR_GENERAL`:
"System error: C:\...\out\PACK8F.tmp\top: (4395) The object manager encountered a reparse point
while retrieving an object." The path is the temporary folder (already removed when the message is
shown), and the system text does not say what happened or what to do. The user cannot tell which
archive folder was the problem or that the unpacker restored a link.

## Evidence

`src/pack1.cpp` `PackUniversalUncompress`, the archive-path walk (feature 249, branch
`249-temp-walks-junctions`): `text.Printf("%s: %s", srcDir, GetErrorText(ERROR_REPARSE_POINT_ENCOUNTERED))`
-> `IDS_PACKERR_GENERAL`. Probe `specs/249-temp-walks-junctions/probe/tempjunction249_probe.ps1`,
rows UNPACK / DEEP in `result_after.txt` show the text. Review 1 of 249, NOTE 1
(`specs/249-temp-walks-junctions/fix-log.md`, *Review*). An existing string was used because a new one
needs the two-stage `.slt` refresh, which an autonomous run does not do.

## Expected

A dedicated message, e.g. "The archive folder 'a\top' was unpacked as a link (junction or symbolic
link) by the external archiver; nothing was copied, to keep the files the link points to." - the
archive path (`archiveRoot` up to the level met), not the temporary path. Rows UNPACK / DEEP of the
249 probe adjusted to the new text.

## Notes

Cosmetic (the refusal itself is correct and safe). Adds a UI string: the two-stage `.slt` refresh
(`translate.merge --templates`) is part of the work.

## Log

- 2026-10-19 — created (source leftover:249)
- 2026-10-19 — related item temp-dir-walks-follow-junctions done in feature 249
- 2026-10-20 — moved to Next position 50
