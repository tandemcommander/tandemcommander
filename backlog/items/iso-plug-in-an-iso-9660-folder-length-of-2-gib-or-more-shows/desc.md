---
title: ISO plug-in: an ISO 9660 folder length of 2 GiB or more shows a stuck memory box
type: bug
status: in-progress
severity: 5
area: archives
source: review:401
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: 2026-11-02 618dae27
effort: S
feature: 403
related: [iso-plug-in-a-fuzzing-pass-over-the-hfs-iso-9660-joliet-and]
depends-on: []
reason: -
---

# ISO plug-in: an ISO 9660 folder length of 2 GiB or more shows a stuck memory box

## Problem

A folder record of an ISO 9660 volume whose data length is 2 GiB or more (a crafted or damaged image)
makes the ISO plug-in allocate a negative size: the core's modal box "Insufficient memory to allocate
18446744073709549568 bytes" with Abort / Retry / Ignore appears and the listing waits for it; Abort
ends the whole program. Nothing is lost (the image is kept), but a damaged image should not offer to
end the program. Feature 401 made the case reachable also through a block met before with another
length; it existed before for any folder at a new block.

## Evidence

- `src/plugins/uniso/iso9660.cpp` `CISO9660::ListDirectoryRe`: `int size = root->DataLength;` then
  `char* data = new char[size];` - a `DataLength` of `0x80000000` or more is a negative `int`.
- Review 1 of feature 401 (`specs/401-uniso-share-length/fix-log.md`, *Review*, S2): `revimg.py isoneg`
  (A at block 21 with 2048 bytes, B at 21 with `0xFFFFF800`, TOP.TXT) - HEAD of 401 shows the box,
  nothing extracted, the image kept; control `isonegfresh` (the same record at an unvisited block 30)
  shows the same box on main before 401.

## Expected

A folder whose length cannot be a directory of this image (negative as `int`, past the end of the
image, larger than a sane limit) is treated as a folder that cannot be read (features 330 / 400): one
"Error reading directory structure" box per walk, the listing marked incomplete, later folders still
walked - no memory box, no way to end the program from a damaged image.

## Notes

- Not checked: the same length type in the Joliet and UDF-hybrid paths that share `ListDirectoryRe`
  (`CUDFISO::ListDirectory`), and in the file extraction path (`DataLength` of a file).
- Related to the planned fuzzing pass over the readers, which would find such cases in bulk.

## Log

- 2026-11-02 — created (source review:401)
- 2026-11-02 — moved to Next position 2
- 2026-11-02 — verified at 618dae27: still present at 618dae27: probe iso403 IS-NEG, IS-NEG2, IS-MIN show the memory box; Ignore ends the program (bad_alloc, bug report)
- 2026-11-02 — run started, feature 403
