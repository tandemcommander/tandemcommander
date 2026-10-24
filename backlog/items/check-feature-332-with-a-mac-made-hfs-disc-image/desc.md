---
title: Check feature 332 with a Mac-made HFS+ disc image
type: person-step
status: open
severity: 3
area: archives
source: leftover:332
who: person
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Check feature 332 with a Mac-made HFS+ disc image

## Problem

Feature 332 marks an HFS+ listing incomplete when a catalog record is damaged or of a type the ISO
plug-in does not handle, so a whole Unpack with "Delete archive after unpacking" keeps the image. Thread
records, the volume label and the hard-link folder "<4 x U+0000>HFS+ Private Data" are exempt. The run
proved this on xorriso and mkfs.hfsplus volumes and on crafted catalogs, but had no image made on a Mac
(WSL has no hfsplus support): if a real macOS catalog holds a record the rule calls damaged, every
whole unpack of such images would now fail and keep the image (no data lost, but "Delete archive after
unpacking" would never delete them).

## Evidence

`specs/332-uniso-hfs-skipped-records/fix-log.md`, *Review* - review 2, NOTE 4 ("no real Mac-made image
was tried"); the rule `SalHfsCatalogRecordClass` in `src/common/salhfscatalog.h`; the probe
`specs/332-uniso-hfs-skipped-records/probe/iso332_probe.ps1` (xorriso hybrids only).

## Expected

An intact disc image with an HFS+ part made on a Mac unpacks whole and is deleted when asked, as before
feature 332.

## Steps

- [ ] On a Mac, make a hybrid disc image with an HFS+ part, e.g. `hdiutil makehybrid -hfs -iso -o test.iso <folder>`
  (or take an existing Mac installer / software CD image with an HFS+ part); a folder with a few files,
  one of them hard-linked (`ln a.txt b.txt`) if possible. Keep a copy of the image.
- [ ] In Tandem Commander (a build with feature 332), select the image, Alt+F9 (Unpack), tick "Delete
  archive after unpacking", OK. Expected: every file under "HFS (<label>)" extracted, no error box (an
  "Cannot read sector" box is a known separate item), and the image deleted.
- [ ] If the image is kept instead: report it with the image (or its first MB and the HFS+ catalog), as a
  new backlog item naming feature 332 - a record class of real macOS catalogs is then misjudged.

## Log

- 2026-10-24 — created (source leftover:332)
- 2026-10-24 — moved to Person steps position 40
