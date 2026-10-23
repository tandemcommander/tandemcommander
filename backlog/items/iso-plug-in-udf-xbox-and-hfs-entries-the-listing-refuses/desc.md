---
title: ISO plug-in: UDF, Xbox and HFS+ entries the listing refuses end their folder with Error
type: bug
status: new
severity: 6
area: archives
source: measure:328
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: UDF, Xbox and HFS+ entries the listing refuses end their folder with Error

## Problem

Feature 328 made the ISO 9660 reader leave out (and report) an entry the panel listing refuses. The
other readers of the ISO plug-in still answer such an entry the old way: UDF and Xbox (XDVDFS) show a
bare "Error" and drop the rest of that folder (UDF returns `ERR_TERMINATE` for it, XDVDFS
`ERR_CONTINUE` before the remaining records); HFS+ shows "too long path" and ends the whole HFS+
listing; the audio track reader clears the listing. The image opens with entries missing, and a
whole-image Unpack with "Delete archive after unpacking" deletes the image after the partial unpack
(`UnpackWholeArchive` fails only when the listing recorded a left-out entry - 328 records them only
for ISO 9660).

## Evidence

- `src/plugins/uniso/udf.cpp` `CUDF::AddFileDir` (`Error(IDS_ERROR); throw FALSE;` on a refused
  `AddDir` / `AddFile`) and `ScanDir` (`return ERR_TERMINATE`).
- `src/plugins/uniso/xdvdfs.cpp` `CXDVDFS::AddFileDir` / `ScanDir` (`return ERR_CONTINUE` after a
  failed add).
- `src/plugins/uniso/hfs.cpp` `CHFS::ListDirectory` (`Error(IDS_ERR_TOO_LONG_PATH)`, `return FALSE`).
- `src/plugins/uniso/audio.cpp` `CAudio::AddFileDir` (`dir->Clear`).
- Found by reading while doing feature 328 (`specs/328-uniso-refused-entry/research.md` R5); not
  measured with images (genisoimage `-udf` in WSL, as 328's `probe/mkimg328.sh`, may build the UDF one).

## Expected

As feature 328 for ISO 9660: an entry the listing refuses is left out alone, the rest of its folder
and the other file systems are listed, it is named in the report (`CISOImage::ListingLeftOut`,
`src/common/salisonamefit.h`), and a whole-image unpack of such a listing fails so the image is not
deleted.

## Log

- 2026-10-23 — created (source measure:328)
- 2026-10-23 — related item iso-plug-in-an-entry-the-listing-refuses-ends-the-listing done in feature 328
