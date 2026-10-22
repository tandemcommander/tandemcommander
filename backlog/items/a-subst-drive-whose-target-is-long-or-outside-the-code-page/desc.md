---
title: A subst drive whose target is long or outside the code page resolves to a cut or code-page path
type: bug
status: in-progress
severity: 5
area: long-paths
source: review:289
who: agent
created: 2026-10-21
updated: 2026-10-22
verified: 2026-10-22 0f7bd140
effort: M
feature: 301
related: []
depends-on: []
reason: -
---

# A subst drive whose target is long or outside the code page resolves to a cut or code-page path

## Problem

The target of a subst drive is read by `MyQueryDosDevice`: the wide `QueryDosDeviceW` into
`MAX_PATH` UTF-16 units, converted to UTF-8 into the caller's buffer - every caller passes
`MAX_PATH` bytes. A target whose UTF-8 form does not fit (a non-ASCII path of more than ~86-130
characters, or any target over `MAX_PATH`) makes the conversion fail, and the function falls back
to the code-page `QueryDosDevice` - '?' for every character outside the code page, or a cut text.
`GetSubstInformation` then copies the target with `lstrcpyn` at `pathMax` (`MAX_PATH`) - a cut
path. The result is used for path resolution (`ResolveSubsts`), not only for display.

## Evidence

At `cf860604` / branch `289-drive-list-wide-texts` (code read by the independent review of
feature 289, not reproduced):

- `src/salamdr2.cpp` `MyQueryDosDevice` - `QueryDosDeviceW(..., MAX_PATH)`, `SalWToU8(targetW, -1,
  target, maxTarget)`, else `return QueryDosDevice(deviceName, target, maxTarget); // legacy fallback`.
- `src/salamdr2.cpp` `GetSubstInformation` - `char target[MAX_PATH]`, `MyQueryDosDevice(driveNum,
  target, MAX_PATH)`, `lstrcpyn(path, target + 4, pathMax)` / `lstrcpyn(path + 1, target + 7, pathMax - 1)`.
- Callers: `src/salamdr2.cpp` `ResolveSubsts` (`GetSubstInformation(..., tgt, MAX_PATH)`),
  `src/fileswn9.cpp` (`GetSubstInformation(..., target, MAX_PATH)`), `src/dialogs3.cpp`
  (`buff, 300`), `src/drivelst.cpp` `BuildData` (the Change Drive menu text of a subst to UNC,
  `volumeName, MAX_PATH`), `src/bugreprt.cpp` (`MyQueryDosDevice(..., nameBuf, MAX_PATH)`).
- Related cut in the same menu: `src/drivelst.cpp` `BuildData`, case `drvtRemote` - the remembered
  remote path is copied with `l = min(l, MAX_PATH - 1)` (display only).

## Expected

A subst target is read whole (a heap or `SAL_MAX_PATH_UTF8` buffer, the wide answer without a
code-page fallback), and a target that cannot be represented is refused - `ResolveSubsts` and the
other callers never work with a cut or '?' path (CLAUDE.md: a path is never cut).

## Notes

- Not reproduced: needs `subst X: <long or non-code-page folder>` (no admin rights needed) and a
  check of what `ResolveSubsts` callers then do (delete confirmation of a link - feature 069
  F-P1-13 - same-file checks); measure first.
- `subst` itself may refuse targets over `MAX_PATH`; `DefineDosDeviceW` does not - check which
  lengths are reachable.
- Severity 5 as a wrong result with a workaround; raise it if measuring shows a data-safety
  check (`ResolveSubsts` in a delete / same-file decision) acting on the wrong path.

## Log

- 2026-10-21 — created (source review:289)
- 2026-10-21 — moved to Next position 7
- 2026-10-22 — verified at 0f7bd140: reproduced at 0f7bd140: subst Z: to an 80-CJK folder (282 UTF-8 bytes) - F8 on junction J asks to delete directory J, Drive Information type line empty; ASCII and over-MAX_PATH controls pass
- 2026-10-22 — run started, feature 301
