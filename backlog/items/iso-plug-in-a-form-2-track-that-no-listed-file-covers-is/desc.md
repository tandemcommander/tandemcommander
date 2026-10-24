---
title: ISO plug-in: a Form 2 track that no listed file covers is deleted with the image
type: bug
status: in-progress
severity: 7
area: archives
source: review:335
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: 2026-10-24 e2e41399
effort: M
feature: 336
related: []
depends-on: []
reason: -
---

# ISO plug-in: a Form 2 track that no listed file covers is deleted with the image

## Problem

Feature 335 marks a data track in which no file system is found unless its sectors 16..31 are Mode 2
Form 2 (a Video CD's MPEG stream). A Form 2 track is then taken as safe whether or not any listed file
covers it: on a real Video CD the stream is extracted through `MPEGAV/AVSEQnn.DAT` of track 1's ISO 9660
directory, but a Form 2 track that no directory references (a Form 2 stream in its own session, a
Video CD whose ISO 9660 track lost the file entries) lists nothing, the listing is not marked, and Unpack
(Alt+F9) with "Delete archive after unpacking" deletes the image with the stream.

## Evidence

- Review 4 of feature 335 (S2), `specs/335-uniso-raw-track-lost/fix-log.md` section *Review*.
- Probe `specs/335-uniso-raw-track-lost/probe/iso335_probe.ps1` rows S-VCD and M-FORM2 (`result_after_review4.txt`):
  the synthetic Form 2 track (64 sectors) is referenced by no directory, the image is deleted, the
  track's sectors were never extracted.
- `src/plugins/uniso/isoimage.cpp` `CISOImage::Open` at d9406b9b (the `RawLost` decision: `outside || !form2`)
  and `src/common/salisotrack.h` `SalIsoTrackMarksListing`.

## Expected

A Form 2 track that no listed file's extent starts in marks the listing incomplete (a whole unpack fails,
the image is kept); a real Video CD / SVCD (its AVSEQnn.DAT / AVSEQnn.MPG entries cover the stream
tracks) still unpacks whole and is deleted (feature 335's rows C-VCD, C-VCDREAL and reviewer 3's
real-vcdimager rows R-VCD-CCD, R-SVCD-CCD, R-VCD-NRG).

## Approach

After `ListImage`, compare the listed files' start extents (`CFilePos::Extent`, `GetTrackFromExtent`)
with the Form 2 tracks; mark a Form 2 track no extent starts in. A pure rule (tracks x extents) in
`salisotrack.h` with saltests checks. Measure first that S-VCD / M-FORM2 keep the image and the
real-vcdimager images (reviewer 3's `probe/review3/gen335c.py`, vcdimager + ffmpeg in WSL) do not.

## Notes

- A Form 2 track listed through a session folder of its own (M-FORM2) is the same case.
- Cost: a Video CD whose directory does not reference a stream track would keep its image after a whole
  unpack (no data lost).

## Log

- 2026-10-24 — created (source review:335)
- 2026-10-24 — related item iso-plug-in-a-data-track-in-which-no-file-system-is-found done in feature 335
- 2026-10-24 — moved to Next position 1
- 2026-10-24 — verified at e2e41399: still present at e2e41399: uniso code unchanged since d9406b9b; 335 probe result_after_review4 rows S-VCD, M-FORM2 (Form 2 track referenced by no file) deleted the image; RawLost = outside or not form2 only
- 2026-10-24 — run started, feature 336
