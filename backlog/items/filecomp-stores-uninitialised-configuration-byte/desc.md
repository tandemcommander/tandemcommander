---
title: File Comparator stores an uninitialised byte in its saved configuration
type: bug
status: open
severity: 1
area: other-plugins
source: measure:080
who: agent
created: 2026-09-20
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# File Comparator stores an uninitialised byte in its saved configuration

## Problem

Byte 77 of the File Comparator's 92-byte `Configuration` registry blob differs between any two runs (`02` / `01`) with unchanged settings. Harmless for the comparison, but configuration exports differ for no reason (and an uninitialised byte is read from the stack or heap).

## Evidence

specs/080-restart-manager-upgrade/REMAINING-WORK.md, *Found on the way, not part of this feature* (L105-109): "Likely padding after `unsigned char WhiteSpace` in `src/plugins/filecomp/dlg_com.h`". At 7993914c `struct CRegBLOBConfiguration` (`dlg_com.h` ~L152-165, "as stored in binary form in registry. DO NOT MODIFY") has `BOOL`, `int`, `int`, `LOGFONT` (60 bytes), `BOOL`, then `unsigned char WhiteSpace` at offset 76 followed by the 4-byte `CFileViewMode ViewMode` - bytes 77-79 are padding, which matches byte 77. Not in specs/NEXT-WORK.md at 7993914c.

## Expected

Two runs with the same settings store byte-identical `Configuration` blobs (the structure is zero-initialised before it is filled, or the padding is made explicit), and older stored blobs still load.

## Notes

Possibly done - verify: no later feature records a fix, but the blob was not compared again at HEAD. Measure first (export the key twice across two runs, compare).

## Log

- 2026-10-17 — migrated from specs/*/REMAINING-WORK.md (feature 242)
