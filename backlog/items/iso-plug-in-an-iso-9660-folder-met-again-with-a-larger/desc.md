---
title: ISO plug-in: an ISO 9660 folder met again with a larger length is listed empty
type: bug
status: open
severity: 7
area: archives
source: review:400
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: an ISO 9660 folder met again with a larger length is listed empty

## Problem

The ISO 9660 folder walk meets each directory once (feature 328's visited set, against crafted
folder loops). It keys a directory by its start block alone, but every directory record gives its own
data length. In a crafted or damaged image where two folder records point to the same block - the
first with a short length, the second with a longer one - the second folder is listed empty, the
listing is not marked incomplete and no box is shown. A whole Unpack with "Delete archive after
unpacking" then counts as complete and deletes the image although the files in the longer part of the
directory were never extracted.

## Evidence

- `src/plugins/uniso/iso9660.cpp` `CISO9660::ListDirectoryRe` at e48568c6: lines 820-821 take
  `block` and `size` from the record; line 835 `if (!Visited->insert(block).second) return ERR_OK;`
  (feature 328 review) - the size is not part of the key.
- Review 1 of feature 400 (`specs/400-uniso-walk-after-unreadable/fix-log.md`, *Review*) found the
  same pattern in the Xbox walk 400 added and reproduced it there (`xd_share.iso`: `b` at sector S with
  2048 bytes, then `a` at S with 4096 bytes; 400's first build extracted `b/a1.txt` and `top.txt` only,
  no window, and the image was deleted). 400 fixed the Xbox walk by keying on sector and size (probe
  row XD-SHARE of `iso400_probe.ps1`); the ISO 9660 walk dates from 328 and was left as it is.

## Expected

A folder record that points to a block met before with a different (larger) data length is either
walked again for that length or marks the listing incomplete, so a whole unpack fails and the image is
kept. Loops stay bounded (the key comes from the image's records). A probe row in the style of
XD-SHARE for an ISO 9660 image proves it.

## Approach

As 400's `CXDVDFS::VisitFolder`: key the visited set by block and data length (`std::set` of a 64-bit
key); count walks (`CountUnder`, `VisitedLog`) take their keys out the same way.

## Notes

- Not verified on an ISO 9660 image: the reasoning follows the code and the Xbox reproduction.
- Crafted or damaged images only (genisoimage / xorriso never write two records for one directory).

## Log

- 2026-11-02 — created (source review:400)
- 2026-11-02 — related item iso-plug-in-after-a-folder-that-cannot-be-read-no-later done in feature 400
- 2026-11-02 — moved to Next position 1
