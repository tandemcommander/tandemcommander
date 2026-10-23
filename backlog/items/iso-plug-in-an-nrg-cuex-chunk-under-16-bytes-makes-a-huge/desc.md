---
title: ISO plug-in: an NRG CUEX chunk under 16 bytes makes a huge track count
type: bug
status: new
severity: 5
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

# ISO plug-in: an NRG CUEX chunk under 16 bytes makes a huge track count

## Problem

Opening an NRG (Nero) image whose CUEX chunk claims fewer than 16 bytes makes the ISO plug-in compute
its track count from an unsigned underflow (`(Size - 0x10) / 0x10`, about 268 million) and allocate one
track per iteration until a read fails at the end of the file. The count is never compared with the
chunk's or the image's size, nor is the read length checked, so a damaged image costs memory and time
at the open and leaves tracks built from stale bytes.

## Evidence

- `src/plugins/uniso/nrg.cpp` `readCUEX` (at dda36ad3, feature 331's branch, line 131):
  `int trackCount = (header->Size - 0x10) / 0x10;` with `header->Size` a DWORD read from the image;
  each iteration `file.Read(&data, 0x10, ...)` (the read count unchecked) and `new CAudioTrack` +
  `iso->AddTrack`.
- Found by reading while doing feature 331 (`specs/331-nrg-label-bounds/research.md` R5). Not measured.

## Expected

The CUEX reader takes only as many entries as its chunk holds (a chunk under 16 bytes holds none), checks
the chunk against the image's size and each read's length, and never builds a track from a short read.

## Notes

- Feature 331 bounded the CDTX and DAOX readers with `src/common/salnrgcdtext.h`
  (`SalNrgChunkFits`); the same rule fits here.

## Log

- 2026-10-24 — created (source measure:331)
