---
title: ISO plug-in: an HFS+ name with U+0000 inside is listed cut at it
type: bug
status: open
severity: 3
area: archives
source: review:332
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: S
feature: -
related: [uniso-hfs-names-lossy-surrogates]
depends-on: []
reason: -
---

# ISO plug-in: an HFS+ name with U+0000 inside is listed cut at it

## Problem

An HFS+ catalog name that holds U+0000 after its first unit (a damaged or crafted catalog; HFS+
names are counted, not terminated) is converted whole but then used as a C string, so the entry is
listed - and extracted - under the part before the U+0000: "a\0b" is listed as "a". Two names
"a\0b" and "a\0c" in one folder become the same name (the second extraction asks to overwrite the
first). CLAUDE.md: a path or name is never cut - refuse it instead.

## Evidence

At d8e666a7 (branch 332-uniso-hfs-skipped-records): `src/plugins/uniso/hfs.cpp` `CHFS::ListDirectory`
copies `nameLen` units into `fileNameW`, converts `nameLen + 1` units with
`WideCharToMultiByte(CP_UTF8, ...)` into `fileName` and then treats `fileName` as a C string
(`DupStr`, `FixIllegalFSChars`, `MakeSafeName`). The unit check `TestHfsRecordClass332` in
`src/saltests/saltests.cpp` (case "U+0000 inside a name: an entry") documents that such a record is
an entry. Review 1 of feature 332 (`specs/332-uniso-hfs-skipped-records/fix-log.md`, *Review*, NOTE 5),
found by reading; not reproduced with an image. A U+0000 as the first unit is handled by feature 332
(damaged, the listing marked incomplete) except for TN1150's "<4 x U+0000>HFS+ Private Data" folder.

## Expected

A name with U+0000 inside is never listed cut: the record is skipped as damaged (the listing marked
incomplete, as feature 332 does for the first unit) or the name is kept whole in a safe form.

## Notes

- Related: `uniso-hfs-names-lossy-surrogates` (the same conversion changes lone surrogates to
  U+FFFD); the two could be one feature.
- A probe can reuse feature 332's `probe/img332.py` (patch a unit of `side.txt`'s name).

## Log

- 2026-10-24 — created (source review:332)
- 2026-10-24 — moved to Next position 71
