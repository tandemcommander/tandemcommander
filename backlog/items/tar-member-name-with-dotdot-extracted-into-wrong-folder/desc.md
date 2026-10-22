---
title: A tar member whose name contains .. is extracted into a wrong folder
type: bug
status: new
severity: 4
area: archives
source: review:309
who: agent
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# A tar member whose name contains .. is extracted into a wrong folder

## Problem

The TAR plug-in normalizes every member name read from a tar (or cpio) with one rule, inherited from Open Salamander, that resolves a `..` component wrongly: `x/../a.txt` becomes `x\a.txt` and `sub/../a.txt` becomes `s\a.txt` (one letter of the folder survives). Such a member is listed and extracted under that wrong path - possibly next to, or over (after the overwrite question), an unrelated file of the archive. Writers rarely store `..` (GNU tar strips it), so the reach is small.

## Evidence

- `src/common/saltarlink.h` `SalTarNormalizeNameU8` (the loop moved unchanged out of `CArchive::ReadArchiveHeader`, `src/plugins/tar/untar.cpp`, by feature 309): after `dst -= 2` and the walk back to a separator, the `dst++` of the "testAIX.tar ... ../../empty" workaround keeps the first character of the dropped component.
- saltests `TestTarLink309` (`src/saltests/saltests.cpp`): `TarNorm309("sub/../a.txt") == "s\\a.txt"` pins the legacy result.
- Review 1 of feature 309 compiled the header alone and confirmed `x/../a.txt` -> `x\a.txt`. Feature 309 refuses a hard-link target with a `..` component for this reason (probe row UNP-HARD-DOTDOT-DEL); member names keep the rule.

## Expected

A `..` component removes the whole previous component (never climbing above the archive root - `../../empty` stays `empty`), or a member whose name holds `..` is refused and reported like feature 306's refused names; the saltests pin changes with it, and feature 309's link rule may then normalize `..` link names too.

## Notes

Not reproduced in the GUI with a member name (only through the shared rule and saltests). Changing the rule changes listed names of such archives - check the 306 / 308 / 309 probes.

## Log

- 2026-10-22 — created (source review:309)
