---
title: ISO plug-in: an Xbox folder entry claiming a huge size allocates it before reading
type: bug
status: new
severity: 3
area: archives
source: review:402
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: S
feature: -
related: [iso-plug-in-an-nrg-etnf-chunk-claiming-a-huge-size]
depends-on: []
reason: -
---

# ISO plug-in: an Xbox folder entry claiming a huge size allocates it before reading

## Problem

The ISO plug-in's Xbox (XDVDFS) folder walk allocates a buffer of the size a folder entry (or the volume
descriptor, for the root) claims before it reads the folder: a damaged or crafted image whose folder entry
claims up to 4 GiB makes the program ask for that much memory before the read past the end of the image
fails. Plain `new` throws rather than returning NULL, so the walk's out-of-memory path
(`data == NULL` -> `WalkOutOfMemory`, feature 400) may never be taken.

## Evidence

- `src/plugins/uniso/xdvdfs.cpp` `CXDVDFS::ScanDir` at the commit closing feature 402 (branch
  `402-uniso-xbox-name-bound`): `BYTE* data = new BYTE[size]; if (data == NULL) ...` with `size` the
  entry's 32-bit file size, then `Image->ReadBlock(sector, size, data)`.
- Review 1 of feature 402, NOTE 3 (`specs/402-uniso-xbox-name-bound/fix-log.md`, *Review*); upstream
  code, not reproduced.

## Expected

A folder whose claimed size does not lie in the image is refused before any allocation (the walk's one
box, the listing marked incomplete), and an allocation that fails reaches the walk's out-of-memory path
instead of throwing. A probe row (an Xbox image whose folder entry claims 0xFFFFF000 bytes) shows the
program's memory stays small and the image is kept by a whole unpack.

## Notes

- Related: `iso-plug-in-an-nrg-etnf-chunk-claiming-a-huge-size` (the same pattern in the NRG reader) and
  `iso-plug-in-an-iso-9660-folder-length-of-2-gib-or-more-shows`.
- Not verified: whether the plug-in's `new` is the throwing one in this build (`dbg.h` / the CRT's
  `new` handler) - measure first.

## Log

- 2026-11-02 — created (source review:402)
