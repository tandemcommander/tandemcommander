---
title: Check feature 353 with real CloneCD dumps whose .ccd is removed
type: person-step
status: new
severity: 3
area: archives
source: leftover:353
who: person
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: S
feature: -
related: [check-feature-352-with-real-clonecd-dumps-one-and-two]
depends-on: []
reason: -
---

# Check feature 353 with real CloneCD dumps whose .ccd is removed

## Problem

Feature 353 marks the listing of a CloneCD `.img` opened without its `.ccd` incomplete when the image
is raw (starts with the CD sync pattern) and the file holds more than 16 whole sectors past the volume the
plain detection lists, when it ends within that volume, or when the volume's size cannot be read; a whole
unpack with "Delete archive after unpacking" then keeps the image. It was measured with crafted images
only (genisoimage sessions written as raw Mode 1 sectors). How a real CloneCD dump places a later session
in the `.img`, and how many sectors a real single-session dump holds past its volume (post-gap, run-out,
padding), were not seen.

## Evidence

- `specs/353-uniso-noccd-sessions/fix-log.md` (*Measurements after*, *Review*); probe
  `specs/353-uniso-noccd-sessions/probe/iso353_probe.ps1`, images by `probe/img353.py` (crafted).
- `src/common/salisotrack.h` (`SalIsoPvdVolumeSectors`, `SalIsoNoCcdRestMarks`),
  `src/plugins/uniso/isoimage.cpp` (`CISOImage::Open`, the branch without a track table).

## Expected

A real one-session CloneCD dump without its `.ccd` lists and unpacks as before and, unless its track holds
more than 16 sectors past its volume, is deleted with "Delete archive after unpacking"; a real two-session
dump without its `.ccd` is kept.

## Steps

- [ ] With a build carrying feature 353, take a real CloneCD dump of a single-session data CD
  (`.img` + `.ccd` + `.sub`), copy only the `.img` into an empty folder. Select it, Enter: expected the
  box "Missing .CCD file. Displayed image could be incomplete." and the files listed. Alt+F9 (Unpack),
  tick "Delete archive after unpacking", OK: expected every file extracted; note whether the image was
  deleted or kept (kept = the dump holds more than 16 sectors past its volume - record the `.img` size
  and the volume size shown by any ISO tool in a new backlog item if it is kept).
- [ ] The same with a real CloneCD dump of a two-session data CD, only the `.img` copied: expected the
  "Missing .CCD file" box, the first session's files extracted, and the image KEPT.

## Log

- 2026-10-31 — created (source leftover:353)
