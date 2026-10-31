---
title: ISO plug-in: a UDF image with data past its VAT does not open although the VAT is in the file
type: improvement
status: open
severity: 4
area: archives
source: review:358
who: agent
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: M
feature: -
related: [iso-plug-in-a-damaged-udf-vat-entry-writes-past-its-buffer]
depends-on: []
reason: -
---

# ISO plug-in: a UDF image with data past its VAT does not open although the VAT is in the file

## Problem

A UDF disc image of a sequentially written medium (CD-R / DVD-R / BD-R with a virtual allocation table, VAT)
whose file holds more than the volume - a dump padded with other data or zero sectors after the last written
sector - does not open in the ISO plug-in: "Missing virtual allocation table.", nothing listed, nothing can be
extracted, although the VAT is in the file (for example at sector 299 of 400). Since feature 358 this is a
refusal (before it, a crash); the user's files in such an image cannot be reached.

## Evidence

- `src/plugins/uniso/udf.cpp`, `CUDF::ReadSupportingTables` (case `mapVirtual`): the VAT is looked for only
  in 7 sectors on each side of the partition's claimed length and, when that read fails, in the last 7 sectors
  of the file (`GetCurrentTrackEnd`); feature 358 makes a VAT not found there fail the open.
- Probe `specs/358-uniso-udf-vat-missing/probe/iso358_probe.ps1` rows R-VCDR100 (mkudffs cdr volume of 300
  sectors + 100 sectors of 0x5A), R-VCLAIM16, R-VCLAIM100Z, R-V150D100, R-VNOEFED100: the image does not open.
- Review 1 of feature 358 (NOTE "choice made in the spec"), `specs/358-uniso-udf-vat-missing/fix-log.md`.

## Expected

The VAT of such an image is found when it is in the file: for example the last VAT before the first sector
that does not belong to the volume (the last written sector of a sequential medium is the VAT's file entry),
with the found table validated as feature 358 does. An image whose VAT is really missing keeps today's
refusal. Feature 356's rule still marks such a listing (a VAT volume not closed by its VAT), so a whole unpack
with "Delete archive after unpacking" keeps the image.

## Notes

- Not verified how real packet-written dumps end (padding or not) - the person step
  `check-feature-356-with-real-udf-only-disc-images-blu-ray-dvd` may show it.
- Searching backwards through a large padded file costs reads; a bound (for example the 512 sectors 356 reads)
  is a design choice of the feature.

## Log

- 2026-10-31 — created (source review:358)
- 2026-10-31 — moved to Next position 35
