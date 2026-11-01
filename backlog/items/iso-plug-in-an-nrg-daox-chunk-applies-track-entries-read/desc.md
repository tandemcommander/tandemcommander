---
title: ISO plug-in: an NRG DAOX chunk applies track entries read past its own end
type: bug
status: new
severity: 4
area: archives
source: measure:369
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: [iso-plug-in-nrg-cuex-index-records-are-paired-into-wrong]
depends-on: []
reason: -
---

# ISO plug-in: an NRG DAOX chunk applies track entries read past its own end

## Problem

The NRG (Nero) DAOX reader of the ISO plug-in (`readDAOX`) reads a 0x16-byte header and then one
0x2A-byte entry for every track number from the header's first to its last track - whatever the chunk's
size. A damaged DAOX chunk whose track range claims more entries than its size holds makes the reader
take the following chunks' bytes (SINF, ETNF, END!, the footer) as track entries and write them into the
tracks' sector size, mode, start and end; the listing is not marked incomplete. Since feature 369 the
chunk loop reads the next chunk header at the chunk's end, so the rest of the table is no longer
misread - only the wrong entries remain.

## Evidence

- At 88fac2c5 (branch 369-nrg-sinf-chunk-size): `src/plugins/uniso/nrg.cpp` `readDAOX` - `for (i =
  firstTrack; i <= lastTrack; i++)` reading `BYTE data[0x2A]` each, no comparison with `header->Size`;
  the header is read whole only by its own check (`read != sizeof(daox_hdr)`).
- Found by reading while implementing feature 369 (`specs/369-nrg-sinf-chunk-size/fix-log.md`, T010);
  not measured - no image with such a chunk was made.

## Expected

A DAOX chunk gives only the whole entries its size holds (`(Size - 0x16) / 0x2A`, at most the track
range); a chunk whose range claims more entries than that, or that does not lie within the image, gives
none beyond them and marks the listing incomplete (a whole unpack fails, the image is kept) - as
`readCUEX` / `readETN2` / `readSINF` bound their chunks (features 350, 365, 369).

## Notes

- Feature 331 already bounds the track numbers a DAOX entry applies to (`SalNrgDaoTrackInRange`).
- Related: the CUEX pairing item (index points make extra tracks the DAOX chunk does not fill).

## Log

- 2026-11-01 — created (source measure:369)
