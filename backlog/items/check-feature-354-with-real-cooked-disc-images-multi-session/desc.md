---
title: Check feature 354 with real cooked disc images (multi-session dd copy, Linux ISOs)
type: person-step
status: open
severity: 4
area: archives
source: leftover:354
who: person
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Check feature 354 with real cooked disc images (multi-session dd copy, Linux ISOs)

## Problem

Feature 354 marks the listing of a cooked (2048-byte sector) disc image incomplete when the file holds more
than 16 whole sectors past the ISO 9660 volume at its sector 16 and that rest is not zero bytes only (read
up to 512 sectors; a longer rest, a file shorter than its volume or an unreadable size mark it too); a
whole unpack with "Delete archive after unpacking" then keeps the image. It was measured with crafted
images only (genisoimage sessions joined, xorriso-made images); no real `.iso` was available. How a real
`dd` copy of a multi-session disc ends, and which common real images (Linux installation ISOs with an
appended EFI partition, isohybrid images, Windows ISOs) are now kept, were not seen.

## Evidence

- `specs/354-uniso-cooked-sessions/fix-log.md` (*Measurement before*, *Checks*, *Review*, *Limits*);
  probe `specs/354-uniso-cooked-sessions/probe/iso354_probe.ps1`, images by `probe/img354.py` and
  `probe/mkxorriso354.sh` (crafted).
- `src/common/salisotrack.h` (`SalIsoCookedRestDecision`), `src/plugins/uniso/isoimage.cpp`
  (`CISOImage::Open`, the plain branch's `cookedIso` block).

## Expected

A real one-volume `.iso` (a Windows ISO, a Linux ISO without an appended partition) unpacks and is deleted
with "Delete archive after unpacking" as before; a real cooked copy of a multi-session disc, and an image
with an appended partition, are kept.

## Steps

- [ ] With a build carrying feature 354, copy a Windows installation or other plain `.iso` into an empty
  folder; Alt+F9 (Unpack) the whole image with "Delete archive after unpacking" ticked, OK: expected every
  file extracted and the image deleted. If it is kept, record the file size and the volume size shown by an
  ISO tool (`isoinfo -d`) in a new backlog item.
- [ ] The same with an Ubuntu installation ISO (20.10 or newer): expected the files extracted and the image
  KEPT (its appended EFI partition is not listed); note it if it is deleted.
- [ ] Burn a CD-R with two data sessions (for example with a disc-burning tool's "multisession" option,
  a different file in each), copy the disc with a 2048-byte reader (`dd if=/dev/cdrom` or an "ISO image"
  copy), and unpack the copy the same way: expected the files the listing shows extracted and the image
  KEPT.

## Log

- 2026-10-31 — created (source leftover:354)
- 2026-10-31 — moved to Person steps position 28
