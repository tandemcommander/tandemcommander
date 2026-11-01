---
title: Registry Editor: a too long full key path is cut and reported as success
type: bug
status: in-progress
severity: 5
area: other-plugins
source: review:379
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: 2026-11-01 823f2873
effort: S
feature: 380
related: [check-encoding-skips-header-files]
depends-on: []
reason: -
---

# Registry Editor: a too long full key path is cut and reported as success

## Problem

When the core asks the Registry Editor (shipped) for the full path of a path typed relative to the current key, `GetFullFSPath` converts the wide key path back to UTF-8 with `WStrToU8` and treats the result as success with `WStrToU8(...) >= 0 || Error(IDS_LONGNAME)`. `WStrToU8` returns a `DWORD`, so the test is always true; when the UTF-8 path does not fit (`pathSize` is `MAX_PATH` from the core), `WideCharToMultiByte` has filled the buffer before failing and `WStrToU8` terminates it - the cut path is returned as the full path and the panel goes to it. This breaks the rule "a path or name is never cut"; the cut key may be another existing key. The same helper's result is unchecked in the value rename (`fs3.cpp`, `WStrToU8(newName, MAX_PATH, keyName)`; a value name may need up to 765 bytes) and in the Find dialog (`finddlg2.cpp`).

## Evidence

Found by the independent review 2 of feature 379 (`specs/379-plugin-encoding-verdicts/fix-log.md`, *Review*, SHOULD 2), confirmed by reading at 3e0da39c: `src/plugins/regedt/fs2.cpp` `CPluginFSInterface::GetFullFSPath` (`success = WStrToU8(path + l, pathSize - l, buffer) >= 0 || Error(IDS_LONGNAME);`), `src/plugins/regedt/utils.h` `WStrToU8` (returns `DWORD`; on failure terminates `dest[destSize - 1]`), core caller `src/fileswn3.cpp` (`pathSize = MAX_PATH`), `src/plugins/regedt/fs3.cpp` (rename), `src/plugins/regedt/finddlg2.cpp` (unchecked). The reviewer measured that `WideCharToMultiByte(CP_UTF8)` fills the buffer to capacity before failing with error 122. Not reproduced in the GUI.

## Expected

A full key path that does not fit is refused with `IDS_LONGNAME` (the panel stays where it was), never cut; the rename and the Find dialog refuse a name that does not fit as well; a hidden-desktop probe types a relative path under a deep key whose UTF-8 full path exceeds 259 bytes and sees the refusal.

## Approach

Test `WStrToU8(...) > 0` (or make the helper return `int` and refuse on 0); check the two other call sites; prefer a heap buffer where the interface allows a longer path.

## Notes

Severity 5: a wrong result reached only with deep keys and long names (narrow), but the cut key may exist and then the user acts on another key - if a probe shows that, raise it into the 7-8 band. Not a site of `check_encoding.py --plugins`; the helper lives in a header the scan does not read (`check-encoding-skips-header-files`).

## Log

- 2026-11-01 — created (source review:379)
- 2026-11-01 — moved to Next position 1
- 2026-11-01 — verified at 823f2873: still present at 823f2873: hidden-desktop probe regpath380 LONG - panel went to another existing key cut at 259 bytes; CJK cut mid-character
- 2026-11-01 — run started, feature 380
