---
title: ISO plug-in: a raw 2352-byte-sector dump of a UDF VAT disc does not open
type: bug
status: new
severity: 4
area: archives
source: measure:359
who: agent
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: S
feature: -
related: [iso-plug-in-a-udf-image-with-data-past-its-vat-does-not-open]
depends-on: []
reason: -
---

# ISO plug-in: a raw 2352-byte-sector dump of a UDF VAT disc does not open

## Problem

A raw dump (2352-byte sectors, for example a `.bin` / `.iso` that starts with the CD sync pattern) of a UDF disc
of a sequentially written medium (CD-R with a virtual allocation table, VAT) does not open in the ISO plug-in:
"Error reading virtual allocation table at sector #...", nothing listed, although the whole volume and its VAT
are in the file. The same volume as a 2048-byte image opens.

## Evidence

- `src/plugins/uniso/udf.cpp` at the branch `359-uniso-udf-vat-cut`, `CUDF::ReadSupportingTables` (case
  `mapVirtual`): when the read at the partition's claimed end fails, the file's last sectors are found as
  `Image->GetCurrentTrackEnd(...) / SECTOR_SIZE` - the track's bytes divided by 2048, while
  `CISOImage::ReadBlock` reads `SectorRawSize` (2352) bytes per sector. The count is about 15 % too high, so
  the fallback window lies past the file's end and its read fails.
- Probe `specs/359-uniso-udf-vat-cut/probe/iso359_probe.ps1` row L-RAWFULL: the mkudffs cdr image `mk_cdr.img`
  (300 sectors, partition start 257, the VAT in sector 299) written as a raw Mode 1 dump by
  `probe/rawimg359.py` -> "Error reading virtual allocation table at sector #00000050" (the window 80 .. 86
  of a 344-sector count instead of 36 .. 42).
- Feature 359 kept this count (scope) and only made the search end.

## Expected

The file's last sectors are counted in the track's real sector size (`SectorRawSize` of the track, the bytes
before the first sector's data left out), so a raw dump of a whole VAT volume opens as its 2048-byte image does
(probe row L-RAWFULL lists without a window); cut raw dumps keep feature 359's read error.

## Notes

- Related to `iso-plug-in-a-udf-image-with-data-past-its-vat-does-not-open` (a padded file): both are about
  where the VAT search looks; this one is only the sector size of the count.
- Not verified with a real raw dump of a packet-written CD-R (only mkudffs images converted by the probe).

## Log

- 2026-10-31 — created (source measure:359)
