# Implementation Plan: The information line shows items with very long names

**Branch**: `276-infoline-long-name` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/276-infoline-long-name/spec.md`

## Summary

`CFilesWindow::ItemFocused` (src/fileswn2.cpp) expands the Information Line content into
`char buff[1000]`. The default content holds the name twice (`$(FileName)` and `$(FileDOSName)`,
which is the name itself when the item has no short name - every archive member, and disk files
on volumes without 8.3 names), so a 604-byte name needs more than 1000 bytes and
`DoExpandVarString` (src/salamdr2.cpp) shows "Expanded string is too large." and leaves the line
unchanged.

The fix keeps the first attempt in the 1000-byte stack buffer and, when it does not fit, repeats
the expansion into a heap buffer that grows (2000, 4000, ... 64000, 65535 bytes); the attempts
before the last one pass no message parent, so they never show a box; the last one (at the
65,535-byte bound, unreachable for names alone) passes the panel window and reports as before.
The growth rule is `src/common/salinfolinebuf.h` (`SalInfoLineNextLen`), checked by `saltests`.
The plug-in route (`GetInfoLineContent`, 1000 bytes by contract) is not touched.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI only; the existing `ExpandInfoLineItems` (src/execute.cpp) and
`CStatusWindow::SetText` / `SetSubTexts` (src/stswnd.cpp; heap copies of any length)
**Storage**: N/A (no registry or file change)
**Testing**: `saltests` (`TestInfoLineBuf276`); hidden-desktop probe `probe/infoline276_probe.ps1`
(PIXCTL, ARCCAP, ARCMAX, ARCDEEP, DISK, ARCSHORT); 260's and 275's probes as regressions
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand`)
**Performance Goals**: no change for texts under 1000 bytes (one expansion on the stack as
before); a long text costs at most 7 extra expansions (each microseconds) per focus change
**Constraints**: hot-text positions are WORDs (`MAKELPARAM(out - buffer, totalLen)`), so the
buffer never exceeds 65,535 bytes; never cut a name (CLAUDE.md); the plug-in ABI unchanged
**Scale/Scope**: one function in the core, one new header, one test function

## Constitution Check

| Principle | Check |
|---|---|
| I. Build Reproducibility | no build change; the header is header-only |
| II. Backward Compatibility | texts that fitted behave identically (same first attempt, same buffer); malformed content still reports once; plug-in contract unchanged - PASS |
| III. Incremental Modernization | one call site, a small reviewable change - PASS |
| IV. Windows Platform Commitment | WinAPI / CRT only - PASS |
| V. Plugin Architecture Preservation | `GetInfoLineContent` keeps its 1000-byte buffer - PASS |
| VI. UI Consistency | no dialog or control change; one box fewer - PASS |

Re-check after design: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/276-infoline-long-name/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
├── probe/infoline276_probe.ps1, result_*.txt
└── tasks.md
```

No `contracts/`: the feature has no external interface (the plug-in contract is unchanged).

### Source Code (repository root)

```text
src/common/salinfolinebuf.h   # new: SAL_INFOLINE_FIRST_LEN, SAL_INFOLINE_MAX_LEN, SalInfoLineNextLen
src/fileswn2.cpp              # CFilesWindow::ItemFocused: the growing expansion
src/saltests/saltests.cpp     # TestInfoLineBuf276
```

**Structure Decision**: the core only; the header follows the `src/common/sal*.h` pattern
(feature 260's `salcachename.h`).

## Complexity Tracking

None.
