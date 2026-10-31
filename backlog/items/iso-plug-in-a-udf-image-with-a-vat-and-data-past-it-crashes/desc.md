---
title: ISO plug-in: a UDF image with a VAT and data past it crashes Tandem Commander
type: bug
status: open
severity: 7
area: archives
source: review:356
who: agent
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: a UDF image with a VAT and data past it crashes Tandem Commander

## Problem

A UDF-only disc image of a sequentially written medium (a virtual allocation table, VAT - as `mkudffs
--media-type=cdr`, `dvdr`, `bdr` write it, or a dump of a packet-written CD-R / DVD-R) whose file holds
more than the volume - for example 100 sectors of other data after it - crashes Tandem Commander when the
ISO plug-in lists it (an Unpack, Alt+F9, of the whole image): "A problem has occurred, forcing Tandem
Commander to close", access violation reading address 0. The image is kept (nothing is lost), but the
program closes and the user's other work in it is interrupted.

## Evidence

- Review 2 of feature 356 (`specs/356-uniso-udf-rest/fix-log.md`, *Review*): rows R-VCDR100 (mkudffs
  cdr image of 300 sectors + 100 sectors of 0x5A), R-VCLAIM16 and R-VCLAIM100Z (the same image filled up
  to the size its partition descriptor claims, + 16 sectors / + 100 zero sectors) - the bug report's
  stack ends in `CPluginInterfaceForArchiver::UnpackWholeArchive` (`uniso.spl`); the same with main's
  `uniso.spl` (before 356) and with 356's.
- `src/plugins/uniso/udf.cpp`, `CUDF::ReadSupportingTables` (case `mapVirtual`): when no VAT is found
  near the partition length or in the last sectors of the file it shows "Missing virtual allocation
  table." and still returns TRUE, leaving `PartitionMapping.Translation` NULL and `Entries` 0;
  `CUDF::LogSector` (case `mapVirtual`) then tests `lbNum <= PartitionMapping.Entries` and reads
  `PartitionMapping.Translation[lbNum]` - for block 0 (mkudffs puts the file set descriptor at virtual
  block 0) a read of address 0. The `<=` also reads one entry past the table when a VAT is found.

## Expected

A VAT image whose VAT is not found lists nothing and marks the listing incomplete (feature 328's mark:
a whole unpack fails, "Delete archive after unpacking" keeps the image) without a crash; `LogSector`
never reads `Translation` when it is NULL and never at index `Entries` (`lbNum < Entries`); a VAT image
that ends with its VAT lists as today (probe 356 rows C-MKCDR, C-MKCDRC, C-MKDVDR, C-MKBDR).

## Notes

- Out of 356's scope: 356 changes only whether a whole unpack counts as complete (it marks these images
  - a VAT volume not closed by its VAT - but the reader crashes while listing, before that matters).
- Review 2's probe and images: `%TEMP%\rev356b\` on the measuring machine (`rev356b_probe.ps1`,
  `compose2.py`) - not in the repository; the images are rebuilt from `specs/356-uniso-udf-rest/probe/
  mkudf356.sh` (mk_cdr.img) + appended bytes.

## Log

- 2026-10-31 — created (source review:356)
- 2026-10-31 — moved to Next position 2
