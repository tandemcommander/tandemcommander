---
title: ISO plug-in: NRG ETNF / ETN2 and multi-session CCD track tables get wrong sector sizes or ends
type: bug
status: open
severity: 5
area: archives
source: review:335
who: agent
created: 2026-10-24
updated: 2026-10-31
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: NRG ETNF / ETN2 and multi-session CCD track tables get wrong sector sizes or ends

## Problem

The ISO plug-in's track-table readers set some tracks' geometry wrongly, so such images list wrongly or
not at all:

- NRG ETNF: the sector size comes from bit 0 of the mode byte (`0x920` if set, else `0x800`) - mode
  0x06 (raw Mode 2, 2352 bytes) is read as 2048-byte sectors, mode 0x05 (raw Mode 1, 2352 bytes) as 2336.
- NRG ETN2: `Track::End` is set from the chunk's length field, not from an end offset.
- CloneCD (CCD/IMG): the sessions are split where a track's `INDEX 1` is 0; a real multi-session image
  (absolute `INDEX 1` values) is not split, and the last track's sector count (a DWORD) can underflow, so
  `End` wraps.

Since feature 335 such a raw data track is marked (fails closed: the image is kept after a whole unpack)
instead of being lost; the listing itself is still wrong.

## Evidence

- Review 4 of feature 335 (NOTEs 1-2, by reading), `specs/335-uniso-raw-track-lost/fix-log.md` section
  *Review*.
- At d9406b9b: `src/plugins/uniso/nrg.cpp:212` (`readETNF`, `data[offset + 0x0B] & 1`),
  `src/plugins/uniso/nrg.cpp:252` (`readETN2`, `track->End = getLongLong(data + 0x08)`),
  `src/plugins/uniso/img.cpp:483` (the CCD session split, `track->Index == 0`) and the `End` computation
  after it.
- Not measured: no image with ETNF modes 0x05 / 0x06, an ETN2 chunk or a multi-session CloneCD dump was
  made.

## Expected

An NRG ETNF track of modes 0x05 / 0x06 is read with 2352-byte sectors and the right header size; an ETN2
track's end is its start plus its length; a multi-session CloneCD image is split into its sessions with
the right track ends - each measured with a crafted image (feature 335's `probe/img335.py` /
`probe/ccd335.py` style) before and after.

## Notes

- Check the NRG mode table against Nero's format first (0x00 Mode 1 / 2048, 0x02 Mode 2 Form 1 / 2048,
  0x03 Mode 2 / 2336, 0x05 Mode 1 / 2352, 0x06 Mode 2 / 2352, 0x07 audio, 0x0F / 0x10 / 0x11 with
  subchannel - not verified).
- Related: the NRG session-count item.
- Since feature 352, `ReadSessionCCD` marks the listing incomplete whenever the `[Session n]` sections and
  the `INDEX 1 = 0` splits disagree (`SalIsoCcdLayoutTrusted`, `src/common/salisotrack.h`) - every real
  multi-session CloneCD dump (absolute `INDEX 1`) is therefore kept by a whole unpack with "Delete archive
  after unpacking", without a message. Once the split follows the table of contents, that mark should go
  only where the sessions are then read correctly (probe rows R-ABS / R-TWOSEC of
  `specs/352-uniso-ccd-session-bounds/probe/iso352_probe.ps1`).

## Log

- 2026-10-24 — created (source review:335)
- 2026-10-24 — moved to Next position 8
- 2026-10-24 — related item iso-plug-in-an-nrg-session-count-above-the-image-s-tracks done in feature 340
- 2026-10-31 — note added by feature 352: the layout mark of ReadSessionCCD to lift once the CloneCD split is fixed
