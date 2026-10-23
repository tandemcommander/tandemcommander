---
title: ISO plug-in: HFS+ B-tree loader trusts the image; Joliet names cut
type: bug
status: in-progress
severity: 5
area: other-plugins
source: leftover:223
who: agent
created: 2026-10-15
updated: 2026-10-23
verified: 2026-10-23 a222bd88
effort: M
feature: 322
related: []
depends-on: []
reason: -
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
- 2026-10-23 — unblocked: the 2026-10-20 run stopped during the measurement (no branch, no decision needed); a new run starts it from the beginning
- 2026-10-23 — verified at a222bd88: confirmed at a222bd88 by code reading: BTree ctor indexes firstLeafNode/fLink/record offsets unchecked; Joliet UTF-8 name cut by lstrcpyn to UCS-2 byte length; uniso on
- 2026-10-23 — run started, feature 322
