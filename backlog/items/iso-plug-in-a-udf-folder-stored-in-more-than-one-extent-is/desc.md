---
title: ISO plug-in: a UDF folder stored in more than one extent is listed cut and the image deleted
type: bug
status: new
severity: 6
area: archives
source: review:362
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: [iso-plug-in-a-udf-folder-entry-without-descriptors-is-listed]
depends-on: []
reason: -
---

# ISO plug-in: a UDF folder stored in more than one extent is listed cut and the image deleted

## Problem

A UDF folder whose entry has several allocation descriptors is read only up to its first extent; the rest of its entries are not listed and a whole unpack with Delete archive after unpacking deletes the image.

## Evidence

- Review 1 of feature 362 (`specs/362-uniso-udf-folder-no-descs/fix-log.md`, *Review*, SHOULD 2), on the Debug
  build of the 362 branch: a genisoimage `-udf` image with 40 files in the root (root data 2,920 bytes, one short
  descriptor); the root's descriptor split into two contiguous ones (2,048 bytes at block 3 + 872 at block 4 - a
  valid fragmented folder). Alt+F9 with "Delete archive after unpacking": 68 of 80 files extracted, the UDF part's
  `a_rather_long_file_name_38.txt` .. `_49.txt` missing, no window, the image **deleted**. Control (intact image):
  80 files, deleted. Reviewer's scripts `%TEMP%/rev362/mkbig.sh`, `imgrev.py rootsplit`, `probe2.ps1` (not kept).
- `src/plugins/uniso/udf.cpp` at the 362 branch: `CUDF::MapICB(CAD, CICBTag*, CAD*)` reads the folder's entry with
  `ReadFileEntry(..., file, 1)` - room for one descriptor; the reader stops at the second (`maxAds <= 0`,
  "UNSUPPORTED: Not enough CAD structures" trace only); `CUDF::ScanDir` walks `dirICB.Length` of the first extent
  only and returns `ERR_OK` - the listing is not marked (feature 330's `ListingLeftOut`).
- Older than 362 (the one-descriptor call predates it); not run on a `main` build. Files are read in several
  extents (`UnpackFile`, `icbs[32]`); only folders take one.

## Expected

Every extent of a folder is walked, or a folder that is not read whole marks the listing incomplete (a whole
unpack then keeps the image).

## Notes

- Plausible on fragmented rewritable or packet-written UDF media. A folder whose descriptors continue in an
  allocation extent descriptor (extent type 3) is the same case.

## Log

- 2026-11-01 — created (source review:362)
