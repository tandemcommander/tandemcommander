---
title: ISO plug-in: Joliet and ISO 9660 names are not made safe before extraction
type: bug
status: open
severity: 7
area: archives
source: review:326
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: 2026-10-23 e50d62ad
effort: M
feature: -
related: [iso-plug-in-a-fuzzing-pass-over-the-hfs-iso-9660-joliet-and]
depends-on: []
reason: -
---

# ISO plug-in: Joliet and ISO 9660 names are not made safe before extraction

## Problem

The ISO plug-in lists and extracts Joliet names and plain ISO 9660 identifiers as the image stores
them. An image can hold any bytes there: a Joliet name `..\x.txt`, `12:30.txt`, `con.txt`, a name
ending in a dot. Joined to the target folder, such a name writes outside the folder or into an NTFS
alternate stream - what feature 087 forbids for archive item names (`salarcname.h`). Feature 326
cleans Rock Ridge names only (`SalSuspCleanRockRidgeName`); the Joliet path and the ISO 9660
fallback were outside its item.

## Evidence

- Review 1 of feature 326 (`specs/326-uniso-rrip-without-rr/fix-log.md`, *Review*): with Rock Ridge
  names uncleaned, an xorriso file `..\escape.txt` was written two levels above the target and
  `12:30.txt` became the file `12` with the data in a stream (probe rows ESC / COLON,
  `probe/result_review1_before.txt`). The same flow takes Joliet and ISO 9660 names.
- `src/plugins/uniso/iso9660.cpp` (at the commit of feature 326): `CISO9660::ConvJolietName` and the
  `lstrcpyn(fileName, src, dr.LengthOfFileIdentifier + 1)` fallback of `ExtractExtFileName` copy the
  bytes; `ListDirectoryRe` passes them through `EnsureU8Name` (encoding only) to `AddFileDir`;
  `UnpackFile` joins `fileData->Name` with `SalPathAppend`.
- Not verified: whether the UDF and HFS+ readers of the plug-in (`udf.cpp`, `hfs.cpp`) clean names.

## Expected

Every name the ISO plug-in lists, from any of its readers, is made safe as feature 087 does
(`salarcname.h`): no name writes outside the target folder or into a stream; a reserved device name
or a trailing dot is renamed, never dropped; never a cut name.

## Notes

Not reproducible with IMAPI2 (Windows refuses such Joliet names); needs a crafted image (a byte
patch of a Joliet identifier, as feature 326's probe patches `rr.iso` in `Make-Legacy`).

## Log

- 2026-10-23 — created (source review:326)
- 2026-10-23 — moved to Next position 1
- 2026-10-23 — verified at e50d62ad: iso327 probe at e50d62ad: 39 FAIL - Joliet/ISO 9660/UDF/Xbox/HFS+ names keep colon (stream), device, trailing dot; a crafted volume label writes outside the target
