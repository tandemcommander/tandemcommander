---
title: ISO plug-in: a multi-session image opened through another plain layout lists one session, then Unpack deletes it
type: bug
status: new
severity: 7
area: archives
source: review:355
who: agent
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: a multi-session image opened through another plain layout lists one session, then Unpack deletes it

## Problem

A disc image that the ISO plug-in's plain detection opens through a layout other than "raw with the CD
sync pattern at sector 0" (feature 355) or "cooked, 2048-byte sectors from offset 0" (feature 354) - for
example an Easy CD Creator image (`CheckForECDC`: Mode 2 sectors with the 16-byte sync and header zeroed),
or one accepted by the NRG-offset, 2336, NCD, PDI, C2D, CIF, CIF2332 or Xbox checks - lists only the volume
at its sector 16. When it holds a second session past that volume, a whole Unpack (Alt+F9) with "Delete
archive after unpacking" extracts the first session and deletes the image with the later session's files.

## Evidence

- Review 1 of feature 355 (`specs/355-uniso-raw-sessions/fix-log.md`, *Review*, SHOULD S1): the reviewer's
  row X-ECDCTWO (s1 + s2 of 334's `mkimg334.sh` as Mode 2 sectors with sync and header zeroed, named
  `.bin`) - a.txt extracted, the image deleted, b.txt lost, on the 355 build and on main 4cc97934 alike.
- `src/plugins/uniso/isoimage.cpp` at b4ff2965, `CISOImage::Open` plain branch: `rawStart` is
  `SectorType != stISO` right after `DetectSectorType` (sync and mode 1 / 2 at sector 0 only); `cookedIso`
  needs `!rawStart` and the 2048-byte layout at offset 0; the other checks (`CheckForECDC` and the rest)
  reach neither 353's, 354's nor 355's block.

## Expected

An image of the plain detection opened through any of the other layouts whose file holds more than 16 whole
sectors past the listed volume, with sector data that is not zero in the user data (as 355's
`SalIsoRawRestDecision` at the opened layout), marks the listing incomplete; a one-session image of those
layouts unpacks and is deleted as today - measured with crafted two-session and one-session images per
layout before and after.

## Notes

- The reviewer's seed builder was `%TEMP%\rev355\img355x.py` (kind `ecdctwo`) - not kept in the repository;
  355's `specs/355-uniso-raw-sessions/probe/img355.py` is the base to extend.
- 355's rule may apply as it is: its CHECK reads the user data at `DataOffset + n * SectorRawSize +
  SectorHeaderSize`, which is the opened layout's - measure per layout which of them can carry a later
  session at all (an Xbox or HFS image hardly can).

## Log

- 2026-10-31 — created (source review:355)
