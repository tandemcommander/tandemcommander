---
title: ISO plug-in: a failed NRG table read leaves its tracks for the plain-image fallback
type: bug
status: open
severity: 4
area: archives
source: review:369
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: [iso-plug-in-an-nrg-daox-chunk-applies-track-entries-read]
depends-on: []
reason: -
---

# ISO plug-in: a failed NRG table read leaves its tracks for the plain-image fallback

## Problem

When the NRG (Nero) chunk table of an image cannot be read to its end (`ReadNRGRoot` returns FALSE - a
chunk whose declared size runs past the end of the file, so the next chunk header cannot be read),
`CISOImage::Open` falls back to opening the file as a plain image. The tracks and session counts the NRG
reader already added stay in `Tracks` / `Session`: the fallback appends its own track at the end but sets
`LastTrack = 0`, which points at the first NRG track (e.g. an ETNF track), and appends `Session.Add(1)` to
the partial session list. The listing then shows the first NRG track's files only (or a mix of sessions),
not what either reader alone would show.

Since feature 369 the chunk loop reads the next header at every chunk's declared end, so a SINF, DAOX or
ETNF chunk with an oversized size reaches this fallback too (before, only unknown, CUEX, ETN2 and CDTX
chunks did). It is data-safe: the partial listing is marked incomplete and "Delete archive after
unpacking" keeps the image.

## Evidence

- Review 1 of feature 369 (`specs/369-nrg-sinf-chunk-size/fix-log.md`, section *Review*), row
  R-SINFHUGE: ETNF, a SINF chunk declaring 0xFFFFFFF0 bytes (4-byte body, count 1), SINF 4: 1, END!, NER5.
  Before 369: both sessions extracted, image deleted (the old reader ignored the size). After 369: only
  `a.txt`, image kept, no box.
- At 88fac2c5: `src/plugins/uniso/isoimage.cpp` `CISOImage::Open` - `if (ReadSessionInfo(quiet)) {...}
  else` the `CheckFor...` chain; the plain-image branch `LastTrack = 0; Tracks.Add(track);
  Session.Add(1);` without clearing what `ReadSessionNRG` added.

## Expected

When the NRG table read fails, the fallback starts from an empty track and session table (or the image is
listed from the tracks read, consistently) - `LastTrack` names the track the fallback added; the listing
stays marked incomplete so the image is kept.

## Notes

- Same class for CCD images (`ReadSessionCCD` failing after adding tracks) - not verified.

## Log

- 2026-11-01 — created (source review:369)
- 2026-11-01 — moved to Next position 32
