---
title: ISO plug-in: an HFS+ file skipped or cancelled at extraction leaks its read buffer
type: bug
status: open
severity: 2
area: other-plugins
source: measure:327
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: an HFS+ file skipped or cancelled at extraction leaks its read buffer

## Problem

When a file of an HFS+ volume cannot be created at extraction and the user answers Skip (or Cancel)
in "Error Creating File", the ISO plug-in returns without freeing the read buffer it allocated for
that file. Each skipped file leaks up to 64 KB; the Debug build shows one "Detected memory leaks!"
box per leaked block when the program ends (the program then does not exit until they are closed).

## Evidence

- `src/plugins/uniso/hfs.cpp` at c6e89540 (branch `327-uniso-safe-names`), `CHFS::UnpackFile`:
  `char* buffer = (char*)malloc(...)` (line 535), then `if (toSkip) return UNPACK_ERROR;` (line 550)
  and `if (hFile == INVALID_HANDLE_VALUE) return UNPACK_CANCEL;` (line 555) - neither frees `buffer`.
- Feature 327's probe `specs/327-uniso-safe-names/probe/iso327_probe.ps1`, set HFS on main's build
  (e50d62ad, `probe/result_before.txt`): three HFS+ names refused by Windows, answered Skip; row
  `HFS END` FAIL - "did not exit in 30 s", 136 "Heap Message: Detected memory leaks!" boxes. On the
  fixed build of 327 (no name is refused any more) the row passes - the leak itself is unchanged.

## Expected

`CHFS::UnpackFile` frees its buffer on every return path; a skipped or cancelled HFS+ file leaks
nothing (the HFS set of `iso327_probe.ps1` run on main's binary with a refused name ends with no
"Detected memory leaks!" box).

## Notes

Reproduce on the fixed build with a name Windows still refuses (a read-only target, or an existing
read-only file answered Skip). Not verified: whether the other readers' `UnpackFile` leak on the same
paths (`iso9660.cpp` allocates its buffer after `SafeFileCreate`, so it does not).

## Log

- 2026-10-23 — created (source measure:327)
- 2026-10-23 — moved to Next position 108
