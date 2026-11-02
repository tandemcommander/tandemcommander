---
title: ISO plug-in: an Xbox entry name with a NUL byte inside is listed cut at the NUL
type: bug
status: open
severity: 3
area: archives
source: review:402
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

# ISO plug-in: an Xbox entry name with a NUL byte inside is listed cut at the NUL

## Problem

The ISO plug-in's Xbox (XDVDFS) folder walk copies an entry's name with `strncpy_s`, which stops at the
first NUL byte: a damaged or crafted image whose entry name holds a NUL (`a\0b`, length 3) is listed and
extracted as `a`. The name is cut (CLAUDE.md: a name is never cut), and two entries can end up with one
name (`a\0b` and `a\0c` both `a`) - one may overwrite the other at extraction or be hidden in the listing.

## Evidence

- `src/plugins/uniso/xdvdfs.cpp` `CXDVDFS::ScanDir` at the commit closing feature 402 (branch
  `402-uniso-xbox-name-bound`): `strncpy_s(fileName, (char*)data + offset + 0x000E, len);` - the entry's
  length byte `len` is the name's length, the copy ends at a NUL before it. The walk itself stays
  aligned (the next offset comes from `len`).
- Review 1 of feature 402, NOTE 2 (`specs/402-uniso-xbox-name-bound/fix-log.md`, *Review*); upstream
  code, not reproduced.

## Expected

A name holding a NUL byte is treated as a damaged record (refused, the listing marked incomplete, the
walk's one box), or made safe by the plug-in's name rules (`MakeSafeName`, feature 327) without losing the
bytes after the NUL - never listed cut. A probe row with a crafted Xbox image (`specs/402-uniso-xbox-name-bound/probe/img402.py`
style) proves it.

## Notes

- Same family as `iso-plug-in-an-hfs-name-with-u-0000-inside-is-listed-cut-at` (HFS names); the choice
  between refusing and replacing should follow whatever that item decides.
- Not verified: whether the core merges two entries with one name or lists both.

## Log

- 2026-11-02 — created (source review:402)
- 2026-11-02 — moved to Next position 88
