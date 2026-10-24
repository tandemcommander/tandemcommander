---
title: ISO plug-in: a track of a CCD or NRG image may keep an uninitialised file-system type
type: bug
status: open
severity: 5
area: archives
source: review:334
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: a track of a CCD or NRG image may keep an uninitialised file-system type

## Problem

`CISOImage::Track::Track()` sets only `FileSystem` and `Bootable` (and, since feature 334,
`OutsideImage`); `FSType`, `Mode`, `Start`, `End`, `SectorSize` and the rest are left as whatever the
heap held. The CCD/IMG reader sets `FSType` only for audio tracks (mode 0) - a Mode 1 / Mode 2 data
track keeps the heap's value; the NRG reader's CUEX chunk makes a track per entry and a DAOX entry that
is skipped (feature 331's range check) leaves that track's fields unset. When the value happens to be
0 (`fsUnknown`) or 1 (`fsAudio`), `CISOImage::Open` never detects the data track's file system, and its
files are not listed (since feature 334 such a listing is at least marked incomplete, so a whole unpack
keeps the image); other values make the track be detected as data with garbage start / end.

## Evidence

- Review 1 of feature 334, NOTE 3 (`specs/334-uniso-session-missing/fix-log.md`, section Review), found
  by reading, not reproduced.
- `src/plugins/uniso/isoimage.cpp` `CISOImage::Track::Track()`; `src/plugins/uniso/img.cpp` the CCD
  track loop (`switch (ccdtrk->Mode)`: case 1 / 2 set only `Mode`); `src/plugins/uniso/nrg.cpp`
  `readCUEX` / `readDAOX`.
- In the Debug build the heap fills new blocks with 0xCD, so the defect would show only in Release
  (not verified).

## Expected

Every field of a track has a defined value at construction (`FSType` such that a data track without a
known type is detected, e.g. set by the CCD reader for modes 1 / 2), and a track the track table does
not describe is not listed with garbage bounds.

## Notes

- Review 2 of feature 334 (NOTE 2): with 334 a garbage `FSType` of 0 (`fsUnknown`) or 1 (`fsAudio`)
  marks the listing, so a whole unpack of such a CCD image may fail at random in Release (fails safe:
  the image is kept). No probe drove a CCD image (all NRG, Debug).

- A probe needs a Release build and a CCD/IMG image of a data track (and an NRG whose DAOX skips an
  entry); feature 334's `probe/img334.py` writes NRG images.

## Log

- 2026-10-24 — created (source review:334)
- 2026-10-24 — moved to Next position 7
- 2026-10-24 — related item iso-plug-in-a-data-track-in-which-no-file-system-is-found done in feature 335
