---
title: ISO plug-in: a Joliet file name with an unpaired surrogate is garbled, other letters too
type: bug
status: open
severity: 3
area: archives
source: review:255
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: [uniso-hfs-names-lossy-surrogates]
depends-on: []
reason: -
---

# ISO plug-in: a Joliet file name with an unpaired surrogate is garbled, other letters too

## Problem

The ISO plug-in (UnISO) converts a Joliet name (UCS-2) to UTF-8 with the WTF-8 `SplWToU8`
(`ConvJolietName`), so an unpaired surrogate is kept as its 3-byte form. For **files** (not
folders) the listing then also calls `EnsureU8Name`, whose raw strict UTF-8 probe rejects that
form and re-reads the whole name in the system code page. The name in the listing - and the
extracted file - is garbled, and so is every other non-ASCII letter of it: `a<U+D800>č.txt`
becomes `aí €ÄŤ.txt` with cp1250. Folders skip `EnsureU8Name` and keep their name.

## Evidence

Found by the review of feature 255 (`specs/255-plugin-encoding-findings/fix-log.md`, *Review*, branch `255-plugin-encoding-findings`),
by reading and a Python emulation of the same conversions, at e849e68c:
`src/plugins/uniso/iso9660.cpp` (the file branch of the directory listing: `ConvJolietName`, then
`EnsureU8Name` with the comment "A no-op for Joliet"), `src/plugins/uniso/uniso.cpp`
`EnsureU8Name` (`MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, ...)`). Reported by
`python tools/check_encoding.py --plugins` (`strict-probe-rejects-wtf8`, `uniso.cpp`); verdict
in `specs/255-plugin-encoding-findings/verdicts.md` (branch `255-plugin-encoding-findings`).

## Expected

A Joliet image holding the file `a<U+D800>č.txt` lists and extracts it under that name (WTF-8 in
the program, the lone surrogate on NTFS); `check_encoding.py --plugins` no longer reports
`uniso.cpp`.

## Approach

Probe with `SplU8ToW` (WTF-8, `splunicode.h`) in `EnsureU8Name`, or skip `EnsureU8Name` for Joliet
names as the folder branch does. A fixture image can be made with `oscdimg`/IMAPI from an NTFS
folder holding such a file.

## Notes

Only names with an unpaired surrogate are affected (narrow); the same function serves plain ISO
9660, UDF 8-bit and XDVDFS names, where the bytes are not WTF-8.

## Log

- 2026-10-20 — created (source review:255)
- 2026-10-20 — moved to Inbox
- 2026-10-20 — moved to Next position 51
