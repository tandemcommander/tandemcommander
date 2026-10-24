---
title: Check feature 335 with real NRG and CloneCD dumps of Video CDs and a damaged data CD
type: person-step
status: new
severity: 6
area: archives
source: leftover:335
who: person
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: -
feature: -
related: [check-feature-334-with-real-nrg-and-ccd-disc-images]
depends-on: []
reason: -
---

# Check feature 335 with real NRG and CloneCD dumps of Video CDs and a damaged data CD

## Problem

Feature 335 keeps a disc image after a whole unpack with "Delete archive after unpacking" when one of its
data tracks shows no file system and is not a Mode 2 Form 2 stream (sectors 16..31). It was proven on
crafted NRG / CloneCD images and on vcdimager-made Video CD / SVCD images (Debug build). Images dumped
from physical discs by Nero or CloneCD / Alcohol may differ (a track starting at INDEX 00 with its
pregap, subchannel data in 2448-byte sectors, dumper fills of unreadable sectors): a real Video CD must
still be deleted after a whole unpack, a damaged data session must be kept.

## Evidence

- `specs/335-uniso-raw-track-lost/fix-log.md` (probe `iso335_probe`, 32 rows on crafted images;
  reviewer 3's real-vcdimager rows in `probe/result_review3_realvcd.txt`), `specs/335-uniso-raw-track-lost/quickstart.md`.

## Expected

The Steps confirm on real dumps that Video CDs / SVCDs unpack whole and are deleted, and that a data
session without a readable file system keeps the image.

## Steps

- [ ] With a Release build carrying feature 335, take a Video CD and an SVCD dumped as NRG (Nero) and as
  CCD/IMG (CloneCD or Alcohol, with and without subchannel data). For each: select it, Alt+F9 (Unpack),
  tick "Delete archive after unpacking", OK. Expected: the `MPEGAV` / `MPEG2`, `VCD` / `SVCD` folders
  extracted, no message, the image deleted.
- [ ] A real multi-session data CD dumped as NRG and as CCD/IMG whose second session's volume descriptors
  are overwritten in a copy (sector 16 onwards of session 2's track, e.g. with a hex editor): the same.
  Expected: session 1's files extracted, the image KEPT.
- [ ] If a real Video CD / SVCD is kept, or the damaged copy is deleted: report it as a new backlog item
  naming feature 335, with the image's track table (F3 on the image) and the first 24 bytes of the
  stream track's sectors 16..31.

## Log

- 2026-10-24 — created (source leftover:335)
