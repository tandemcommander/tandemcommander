---
title: ISO plug-in: a crafted image of folders naming one directory with many lengths lists slowly
type: bug
status: open
severity: 4
area: archives
source: review:401
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: a crafted image of folders naming one directory with many lengths lists slowly

## Problem

Since feature 401 the ISO 9660 walk of the ISO plug-in recognises a folder met before by its start
block and its data length together (as the Xbox walk since 400): a crafted image can make the walk
read one directory once per distinct length any folder record gives it. An image whose root holds N
folder records naming one directory with N different lengths, the directory holding N file records,
is listed with N copies of the directory - the work and the memory grow with N squared. Measured by
review 1 of 401: N = 2,000 (an image of 8 MB, about 170 KB non-zero) takes 19.4 s and 525 MB private
memory to open (main before 401: 0.3 s, 50 MB, because it dropped the 2,000 folders silently). The
program answers again afterwards; nothing is lost.

## Evidence

- `src/plugins/uniso/iso9660.cpp` `CISO9660::ListDirectoryRe` - the visited key
  `SalIsoFolderVisitKey(block, size)` (feature 401); `src/plugins/uniso/xdvdfs.cpp`
  `CXDVDFS::VisitFolder` (feature 400) - the same key.
- `src/common/salisowalk.h` `SalIsoFolderVisitKey` - the comment names the bound (one walk per
  distinct pair of the image's records).
- Review 1 of feature 401 (`specs/401-uniso-share-length/fix-log.md`, *Review*): image generator
  `revimg.py isobomb out.iso 2000 2000` and `bomb_probe.ps1` (Enter on the image, hidden desktop) in
  the reviewer's scratch folder (not kept in the repository).

## Expected

A crafted image cannot make a listing take minutes or gigabytes: past a budget of folder walks (or of
listed entries) per listing that no real disc reaches, the walk stops descending, the listing is
marked incomplete (a whole unpack fails and keeps the image) and one box tells the user. Real images
(one record per directory) list as before.

## Notes

- The output is the image's real content (2,000 distinct folders); keying by start alone would bring
  back the data loss 401 fixed - the budget is the way out, not the key.
- The budget's value and its box text are a design choice; a new UI string needs the `.slt` refresh.

## Log

- 2026-11-02 — created (source review:401)
- 2026-11-02 — moved to Next position 22
