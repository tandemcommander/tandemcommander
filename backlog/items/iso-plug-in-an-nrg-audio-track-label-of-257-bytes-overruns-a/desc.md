---
title: ISO plug-in: an NRG audio track label of 257+ bytes overruns a stack buffer
type: bug
status: open
severity: 7
area: archives
source: measure:329
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: an NRG audio track label of 257+ bytes overruns a stack buffer

## Problem

Opening an NRG (Nero) image whose CD-Text block gives an audio track a label of 257 bytes or more
writes past a stack buffer of the ISO plug-in: the track's listed name ("NN label") is formatted with
`sprintf` into `char audioTrack[MAX_PATH]`. The label comes straight from the image (a crafted or
damaged file), with no length bound - a stack overrun while the archive is listed (Debug: a /GS
failure; Release: memory corruption).

## Evidence

- `src/plugins/uniso/audio.cpp` `CAudio::ListDirectory` (at 5ce9b420 / feature 329's branch):
  `char audioTrack[MAX_PATH]; ... sprintf(audioTrack, "%02d %s", Track + 1, label);`.
- `src/plugins/uniso/nrg.cpp` `readCDTX`: the labels are the 0-terminated strings of the chunk (12 of
  every 18 bytes after 4 bytes of flags) - their length is limited only by the chunk size read from
  the image. The same function moves 12-byte blocks with `memmove(dst, src, min(12, i))` from `src =
  data + 4 + 18k`, which can read up to a few bytes past the `header->Size + 1 + trackCount` bytes it
  allocated when the chunk size is not a multiple of 18 (not measured).
- `readDAOX` uses `iso->GetTrack(i - 1)` for track numbers read from the image without checking them
  against the tracks `readCUEX` added (not measured).
- Found by reading while doing feature 329 (`specs/329-uniso-other-readers-refused/research.md` R5);
  feature 329's probe builds such NRG images (`probe/img329.py nrg`, a 253-byte label - one that fits).

## Expected

A label of any length never writes or reads past a buffer: the track name is built in a heap or
bounded buffer, never cut (CLAUDE.md: a name is never cut - a name the listing cannot take is left
out and reported, as feature 329 does for a 256-byte name); the CD-Text and DAOX readers check the
image's sizes and track numbers.

## Notes

- Not reproduced with a run: the 253-byte label of feature 329's probe fits the buffer. A probe row
  needs `img329.py` with a longer label (e.g. 300 x L) and a Debug build (the /GS check reports it).

## Log

- 2026-10-23 — created (source measure:329)
- 2026-10-23 — related item iso-plug-in-udf-xbox-and-hfs-entries-the-listing-refuses done in feature 329
- 2026-10-23 — moved to Next position 2
