---
title: ISO plug-in: Video CD MPEG files in Form 2 sectors may extract cut to 2048 bytes a sector
type: bug
status: open
severity: 5
area: archives
source: review:335
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: Video CD MPEG files in Form 2 sectors may extract cut to 2048 bytes a sector

## Problem

A Video CD / SVCD stores its MPEG streams (`MPEGAV/AVSEQnn.DAT`, `MPEG2/AVSEQnn.MPG`) in Mode 2 Form 2
sectors of 2324 user bytes. The ISO plug-in reads every sector of a track with the track's one user size
(2048 bytes, Form 1), so extracting such a file probably returns 2048 of each sector's 2324 bytes - a
broken MPEG file, without a message. Not verified on the content of a real Video CD.

## Evidence

- Review 2 of feature 335 (row X-VCDFILE, `specs/335-uniso-raw-track-lost/fix-log.md` section *Review*):
  a crafted CloneCD image whose `a.txt` directory record (no XA attributes) points into Form 2 sectors
  extracts with the wrong content.
- Review 3 of feature 335 (`specs/335-uniso-raw-track-lost/probe/result_review3_realvcd.txt`, real
  vcdimager 2.0.1 images made by `probe/review3/gen335c.py`): `MPEGAV/AVSEQ01.DAT` extracts as 608,256
  bytes = 297 x 2048 - the directory size in 2048-byte units; whether its bytes equal the stream's Form 2
  user data was not compared.
- `src/plugins/uniso/isoimage.cpp` `CISOImage::ReadBlock` / `SetSectorFormat` at d9406b9b (one
  `SectorUserSize` per track).

## Expected

Measured first: extract `AVSEQ01.DAT` of a real vcdimager Video CD (CCD and NRG) and compare it with the
MPEG file the image was made from. If it is cut, a file whose ISO 9660 XA attribute says Form 2 (or whose
sectors' subheaders say Form 2) is read with 2324 user bytes a sector and extracts byte for byte; Form 1
files unchanged.

## Notes

- Reviewer 3's images were made in WSL with ffmpeg (pal-vcd / pal-svcd) and vcdimager; the probe images
  of feature 335 are synthetic.
- The listed size may need the XA-aware size too (2324 x sectors).

## Log

- 2026-10-24 — created (source review:335)
- 2026-10-24 — moved to Next position 9
