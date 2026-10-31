---
title: ISO plug-in: an NRG ETNF chunk claiming a huge size allocates it whole
type: bug
status: open
severity: 4
area: archives
source: review:350
who: agent
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: S
feature: -
related: [iso-plug-in-nrg-sinf-and-etn2-chunks-are-read-without-regard]
depends-on: []
reason: -
---

# ISO plug-in: an NRG ETNF chunk claiming a huge size allocates it whole

## Problem

Opening an NRG (Nero) image whose ETNF chunk (the track table of track-at-once images) claims a huge
size makes the ISO plug-in allocate and zero that many bytes before it reads anything: a 47 KB image
whose ETNF chunk claims 1 GiB grows the program to about 1.1 GB, then the image is reported as
"Unknown file format"; a claimed size near 4 GiB asks for a 4 GiB allocation. A chunk of that kind
lying within the image also makes one track per 20 bytes of it - the same unbounded track count
feature 350 removed from the CUEX reader.

## Evidence

- `src/plugins/uniso/nrg.cpp` `readETNF` (at the commit closing feature 350, branch
  `350-nrg-cuex-bounds`): `BYTE* data = new BYTE[header->Size]; ZeroMemory(data, header->Size);`
  with `header->Size` a DWORD from the image, no `SalNrgChunkFits` check (unlike `readCDTX` since 331
  and `readCUEX` since 350), then `header->Size / 0x14` tracks; the `Read` count is not checked.
- Review 3 of feature 350, NOTE 1 (`specs/350-nrg-cuex-bounds/fix-log.md`, section *Review*): kind
  `etnfpast` (the ok image of `specs/350-nrg-cuex-bounds/probe/img350.py` with an ETNF chunk claiming
  0x40000000 bytes before its chunks, 47 KB in all) - peak working set 1095 MB, then "Unknown file
  format". The 4 GiB case was not run.

## Expected

The ETNF reader reads its chunk only when it lies within the image (`SalNrgChunkFits`, skipped like
an unknown chunk otherwise), checks the read's length, and makes no more tracks than a disc can have,
as the CUEX reader does since feature 350 (`SalNrgCuexSizePlausible` / `SalNrgCuexTotalPlausible` in
`src/common/salnrgcdtext.h`); well-formed track-at-once images list as before.

## Notes

- Not covered by `iso-plug-in-nrg-sinf-and-etn2-chunks-are-read-without-regard` (SINF and ETN2) or
  `iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables` (wrong modes and ends).

## Log

- 2026-10-31 — created (source review:350)
- 2026-10-31 — related item iso-plug-in-an-nrg-cuex-chunk-under-16-bytes-makes-a-huge done in feature 350
- 2026-10-31 — moved to Next position 31
