---
title: ISO plug-in: a file covering part of a Form 2 stream lets the image be deleted
type: bug
status: open
severity: 7
area: archives
source: review:336
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: M
feature: -
related: [keep-video-cd-images-after-a-whole-unpack-until-their-video]
depends-on: []
reason: -
---

# ISO plug-in: a file covering part of a Form 2 stream lets the image be deleted

## Problem

Feature 336 keeps a disc image after a whole unpack when a Mode 2 Form 2 stream track (a Video CD's MPEG
track) has no listed file starting in it. A file that starts in the stream covers it, however little of
the track it holds: a damaged or crafted directory whose `AVSEQ01.DAT` record is shorter than its stream
extracts that part, and Unpack (Alt+F9) with "Delete archive after unpacking" deletes the image with the
rest of the stream.

## Evidence

- Review 2 of feature 336 (`specs/336-uniso-form2-uncovered/fix-log.md`, *Review*), row S-VCDPART of
  `specs/336-uniso-form2-uncovered/probe/iso336_probe.ps1` (image `single_vcdpart.nrg` by `img336.py`):
  `avseq01.dat` of 2048 bytes covers 1 of the stream's 64 sectors - one sector extracted, the image
  deleted, 63 sectors lost (`probe/result_after_review2.txt`, a recorded limit row).
- `src/common/salisotrack.h` `SalIsoNoteFileStart` (the file's start extent only) and
  `src/plugins/uniso/isoimage.cpp` `CISOImage::MarkUncoveredStreams` on the 336 branch.

## Expected

A stream track counts as covered only when the listed files that start in it reach (nearly) its end;
otherwise the listing is marked incomplete and the image kept. Real vcdimager Video CDs / SVCDs (their
`AVSEQnn` files span the track from INDEX 01; the pregap of 150 sectors and the front / rear margins lie
around them) are still deleted - feature 335's reviewer-3 images in `%TEMP%\rev335c\imgs`
(`specs/335-uniso-raw-track-lost/probe/review3/gen335c.py` remakes them).

## Notes

- Needs a tolerance measured on real images (the pregap before INDEX 01, the margins after the stream);
  the track's end comes from the track table (`End` / `DataEnd`), which some readers set wrongly (Inbox
  `iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables`) - a wrong end must fail closed.
- Only damaged or crafted directories reach this; vcdimager's files cover their streams.

## Log

- 2026-10-24 — created (source review:336)
- 2026-10-24 — severity 7: data loss in a narrow scenario (a damaged directory)
- 2026-10-24 — moved to Next position 1
