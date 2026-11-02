---
title: ISO plug-in: an Xbox entry name can be read past the end of its directory
type: bug
status: open
severity: 5
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

# ISO plug-in: an Xbox entry name can be read past the end of its directory

## Problem

The ISO plug-in's Xbox (XDVDFS) folder walk reads each directory entry from a heap buffer of the
directory's size. Before it copies the entry's name it only checks that the 14-byte head of the entry
lies in the buffer, not the name: a crafted or damaged image whose last entry gives a name length of
up to 255 bytes makes the walk copy that many bytes from past the end of the buffer (a heap over-read:
garbage in the name, or a crash when the read crosses into an unmapped page).

## Evidence

- `src/plugins/uniso/xdvdfs.cpp` `CXDVDFS::ScanDir` at a27641df: line 269
  `while ((offset + 0x0E) <= size && ...)`, line 294 `BYTE len = GET_BYTE(data, offset + 0x000D);`,
  line 296 `strncpy_s(fileName, (char*)data + offset + 0x000E, len);` - `offset + 0x0E + len` is not
  compared with `size`.
- Found by review 2 of feature 400 (`specs/400-uniso-walk-after-unreadable/fix-log.md`, *Review*,
  NOTE 3); older than 400 (the line is upstream's).

## Expected

An entry whose name does not lie whole in the directory data is treated as a damaged record: the walk
of that directory ends there (the listing marked incomplete, feature 330 / 400's one box), never
reading outside the buffer. A probe row with a crafted Xbox image (img400.py style) and, if the check
is a pure rule, a `saltests` check prove it.

## Notes

- Not reproduced: found by reading; the Debug heap may or may not report the over-read.
- Same family as feature 223's ISO 9660 record bounds and 363's UDF identifier bounds.

## Log

- 2026-11-02 — created (source review:400)
- 2026-11-02 — moved to Next position 2
