---
title: ISO plug-in: HFS+ B-tree loader trusts the image; Joliet names cut
type: bug
status: blocked
severity: 5
area: other-plugins
source: leftover:223
who: agent
created: 2026-10-15
updated: 2026-10-20
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: run stopped during the measurement, before specify; the maintainer continues it by hand
---

# ISO plug-in: HFS+ B-tree loader trusts the image; Joliet names cut

## Problem

Left by feature 223 (crafted ISO images): the HFS+ B-tree loader (`hfs.cpp` ~676-715 / 454) trusts the image's node numbers, links and record offsets; a fuzzing pass is owed; Joliet names are cut at their UCS-2 byte length (`iso9660.cpp` `lstrcpyn(fileName, src, LengthOfFileIdentifier + 1)`).

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L712-716. Feature 223 (`specs/223-uniso-crafted-image/`, `iso223_probe.ps1`).

## Expected

Node numbers, links and record offsets of an HFS+ image are bounds-checked (a crafted image is refused, never read out of bounds); a fuzzing pass over HFS+ / ISO9660 / Joliet / Rock Ridge finds nothing; Joliet names are kept whole.

## Notes

Severity 5 is an estimate: no crash was shown; a crafted image reaching an out-of-bounds read would be a crash in an unusual scenario (7).

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-20 — blocked: run stopped during the measurement, before specify; the maintainer continues it by hand
