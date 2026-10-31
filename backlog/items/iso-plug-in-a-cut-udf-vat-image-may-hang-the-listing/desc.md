---
title: ISO plug-in: a UDF VAT image cut a few sectors after its partition start may hang the listing
type: bug
status: in-progress
severity: 7
area: archives
source: review:358
who: agent
created: 2026-10-31
updated: 2026-10-31
verified: 2026-10-31 13bcb6a1
effort: S
feature: 359
related: [iso-plug-in-a-damaged-udf-vat-entry-writes-past-its-buffer]
depends-on: []
reason: -
---

# ISO plug-in: a UDF VAT image cut a few sectors after its partition start may hang the listing

## Problem

A UDF disc image of a sequentially written medium (with a virtual allocation table, VAT) whose file ends fewer
than 7 sectors after its partition's start - a truncated download or copy - may make the ISO plug-in's VAT
search loop forever while the image is listed (Enter, Unpack): Tandem Commander stops responding and must be
killed (the user's other work in it is lost). Found by reading; not reproduced.

## Evidence

- `src/plugins/uniso/udf.cpp` at 69bfa6a4 (branch 358-uniso-udf-vat-missing), `CUDF::ReadSupportingTables`, case
  `mapVirtual` (lines 1495-1513): when the read at `vatLoc` fails, `nSectors = size / SECTOR_SIZE - PD.Start`
  (DWORD) and, if `nSectors < vatLoc - 7`, `vatLoc = nSectors - 7; lastVatLoc = nSectors; continue`. With
  `nSectors < 7`, `nSectors - 7` wraps to about 4 * 10^9, the read there fails, `vatLoc - 7` is again larger than
  `nSectors`, and `vatLoc` is set to the same value - the `do` loop never ends (with `7 <= nSectors < 14` the
  same when the read at `nSectors - 7` fails). Older than feature 358 (unchanged by it).
- Review 2 of feature 358 (NOTE 4), `specs/358-uniso-udf-vat-missing/fix-log.md`, *Review*.

## Expected

The VAT search ends for every file size: the fallback to the file's last sectors is taken at most once and never
with a wrapped sector number; a file too short for the partition shows "Error reading virtual allocation table"
(the volume does not open, feature 358) at once. A probe row: an mkudffs cdr image
(`specs/356-uniso-udf-rest/probe/mkudf356.sh`) cut to its partition start + 3 sectors - alive within 30 s, the
image kept.

## Notes

- Not reproduced: whether the descriptors still read in a file cut that short (they lie before the partition in
  mkudffs images) decides reachability; the probe row above settles it.

## Log

- 2026-10-31 — created (source review:358)
- 2026-10-31 — moved to Next position 1
- 2026-10-31 — verified at 13bcb6a1: reproduced at 13bcb6a1: raw Mode 1 dump of mk_cdr cut to 260 sectors, partition start 288 - Enter and Unpack hang (WM_NULL timeout); the cooked +3 cut does not hang
- 2026-10-31 — run started, feature 359
