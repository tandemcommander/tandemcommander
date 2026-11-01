---
title: Check feature 366 with a real Video CD dump: the extracted video plays whole
type: person-step
status: new
severity: 3
area: archives
source: leftover:366
who: person
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: -
feature: -
related: [check-feature-335-with-real-nrg-and-clonecd-dumps-of-video]
depends-on: []
reason: -
---

# Check feature 366 with a real Video CD dump: the extracted video plays whole

## Problem

Feature 366 reads the video files of a Video CD / SVCD (CD-XA attribute Form 2) 2324 bytes a sector; it was
proven on vcdimager 2.0.1 images (VCD 2.0 and SVCD, as CloneCD and NRG) and crafted variants of them, not on
a dump of a physical disc. A dumper's image may differ (2448-byte sectors with subchannel data, a pregap
stored with the track, other authoring software's records).

## Evidence

- `specs/366-uniso-form2-files/fix-log.md` (probe `iso366_probe`, real vcdimager images: AVSEQ01.DAT 690,228
  bytes containing the source MPEG whole, the SVCD's AVSEQ01.MPG equal to its source), `quickstart.md`.

## Expected

The Steps confirm on real dumps that the video files extract whole and play to the end.

## Steps

- [ ] With a build carrying feature 366, open a Video CD and an SVCD dumped as NRG (Nero) and as CCD/IMG
  (CloneCD or Alcohol, with and without subchannel data). In the panel, `MPEGAV/AVSEQ01.DAT` /
  `MPEG2/AVSEQ01.MPG` shows a size that is a multiple of 2324. Expected: yes.
- [ ] Copy (F5) `AVSEQ01.DAT` / `AVSEQ01.MPG` out and play it in a media player (VLC, MPC-HC) to the end.
  Expected: plays without picture or sound errors; on 0.2.0 the same file is 2048 / 2324 of the size and breaks
  up.
- [ ] If the size is a multiple of 2048 or the file does not play: report it as a new backlog item naming
  feature 366, with the image's track table (F3 on the image) and the file's directory record (its XA
  attributes).

## Log

- 2026-11-01 — created (source leftover:366)
