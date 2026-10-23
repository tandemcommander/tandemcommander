---
title: ISO plug-in: an NRG session count above the image's tracks lists past the track table
type: bug
status: open
severity: 6
area: archives
source: measure:331
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

# ISO plug-in: an NRG session count above the image's tracks lists past the track table

## Problem

An NRG (Nero) image lists one folder per session ("Session NN", the default "session as directory"
option) when it holds two or more SINF chunks. Each SINF chunk's track count comes from the image and
is never checked against the tracks the CUEX / ETNF chunks added: the listing walks `Tracks[track]`
for as many tracks as the session counts add up to, past the end of the track table (Debug: the
array's range assertion; Release: a read through whatever pointer lies past the table).

## Evidence

- `src/plugins/uniso/nrg.cpp` `readSINF` (at dda36ad3, feature 331's branch, line 329):
  `iso->AddSessionTracks(count)` with `count` read from the image (byte-swapped DWORD), no bound.
- `src/plugins/uniso/isoimage.cpp` `CISOImage::ListImage` (line 1399):
  `int trackCount = Session[session]; ... for (track = firstSessionTrack; track < lastSessionTrack; track++) switch (Tracks[track]->FSType)`
  - no check that `lastSessionTrack <= Tracks.Count`.
- Found by reading while doing feature 331 (`specs/331-nrg-label-bounds/research.md` R5). Not measured.

## Expected

The session listing never indexes past the tracks the image holds: a session count that does not fit
the track table is refused (the session's missing tracks are not listed, and the listing is marked
incomplete as feature 328 / 330 do), never read past the array.

## Notes

- Related to, but not covered by, `iso-plug-in-unpack-with-delete-archive-deletes-a-multi` (a
  session track that does not open); this one is about the session counts themselves.
- Not reproduced by a run (the run found it by reading).

## Log

- 2026-10-24 — created (source measure:331)
- 2026-10-24 — moved to Next position 4
