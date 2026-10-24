---
title: ISO plug-in: an HFS+ file whose data is compressed or only in its resource fork extracts empty
type: bug
status: in-progress
severity: 7
area: archives
source: review:338
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: 2026-10-24 75fc0f43
effort: M
feature: 339
related: [iso-plug-in-hfs-hard-links-extract-as-empty-files-their-data]
depends-on: []
reason: -
---

# ISO plug-in: an HFS+ file whose data is compressed or only in its resource fork extracts empty

## Problem

The ISO plug-in reads only the data fork of an HFS+ file. A file whose content lives elsewhere - an
HFS+-compressed file (macOS `decmpfs`: the data in the resource fork or in a `com.apple.decmpfs`
attribute, the data fork empty) or a file with only a resource fork - is listed with the data fork's size
(often 0) and extracted as an empty file that counts as extracted whole. A whole unpack (Alt+F9) with
"Delete archive after unpacking" then succeeds and deletes the image with the file's only real content.

## Evidence

- Review 1 of feature 338 (`specs/338-uniso-skip-fails-unpack/fix-log.md`, section *Review*, SHOULD 1);
  read at c99f39e5, reachability not measured (needs an HFS+ image made on macOS with a compressed file).
- `src/plugins/uniso/hfs.cpp` `CHFS::ListDirectory` (the listed size is `dataFork.logicalSize`, around line
  547) and `CHFS::UnpackFile` (reads `rec.file->dataFork` only, around lines 610-756): no handling of the
  resource fork or of the `decmpfs` attribute; `bFileComplete` stays TRUE.

## Expected

A file whose content the reader cannot extract (compressed, resource fork only) is either extracted with its
content or counted as not extracted (feature 338's rule: the whole unpack then fails and the image is
kept); never an empty file counted as done. Measured first with a Mac-made image (or a crafted one).

## Notes

- Related to HFS+ hard links extracting empty (332's limit, the related item) - another case of a file the
  reader writes empty.
- Detecting "compressed" needs the attributes B-tree (`UF_COMPRESSED` in the BSD flags of the catalog record
  is a cheaper sign) - not verified which images carry it.

## Log

- 2026-10-24 — created (source review:338)
- 2026-10-24 — moved to Next position 1
- 2026-10-24 — verified at 75fc0f43: reproduced at 75fc0f43: crafted xorriso HFS+ hybrid, side.txt resource-fork-only / UF_COMPRESSED extracts empty, image deleted (probe iso339 6 FAIL)
- 2026-10-24 — run started, feature 339
