# Implementation Plan: The core never follows a shortcut to a cut target path

**Branch**: `305-core-shortcut-target-cut` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/305-core-shortcut-target-cut/spec.md`

## Summary

`SalShellLinkGetPathU8` (`src/common/salshelllink.h`, feature 128) - the one reader of a
shortcut's target in the core - takes `IShellLinkW::GetPath`'s NOERROR at its word. Measured at
31239f48: on a volume without 8.3 names the answer for a 260+ unit target is exactly 259 units,
`\\?\D:\...` cut mid-name, for both flags the core uses. The fix applies feature 304's rule in the
core: for an answer of 259 units or more, read the link's item list
(`GetIDList` + `SHGetNameFromIDList(SIGDN_FILESYSPATH)`), compare plain forms; equal or extended
→ the whole item-list name (plain); otherwise refuse with
`HRESULT_FROM_WIN32(ERROR_FILENAME_EXCED_RANGE)`. A raw-path question with a 259+ answer is
refused without the item list. `SalFolderShortcutTargetU8` passes that refusal on as its existing
"too long" result. No call site changes.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI shell (`IShellLinkW`, `SHGetNameFromIDList`, `CompareStringOrdinal`)
**Storage**: N/A
**Testing**: `saltests` (pure rule, fake link, end to end with real shortcuts next to `saltests.exe`); GUI probe on the hidden desktop (Enter / Go to Shortcut Target)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core), header-only helper in `src/common/`
**Performance Goals**: N/A - the item list is read only for answers of 259+ units (rare)
**Constraints**: header-only (saltests includes it); no new UI strings; plug-in interface untouched; never cut a path
**Scale/Scope**: one header (2 new pure functions, 2 functions changed), saltests checks, one probe

## Constitution Check

| Principle | Status |
|---|---|
| I. Build reproducibility | Pass - no new dependency (shell32 / kernel32 already linked) |
| II. Backward compatibility | Pass - answers under 259 units unchanged, signatures unchanged |
| III. Incremental modernization | Pass - one helper fixed |
| IV. Windows commitment | Pass - WinAPI only |
| V. Plugin architecture preservation | Pass - plug-ins not touched (their twin was fixed by 304) |
| VI. UI consistency | Pass - existing messages / routes only |

Re-check after design: unchanged (Pass).

## Project Structure

### Documentation (this feature)

```text
specs/305-core-shortcut-target-cut/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/salshelllink-whole-target.md
├── probe/measure_core.cpp     # the measurement program (before / after)
├── probe/mklnk305.cpp         # writes a long-target .lnk from an item list (probe helper)
├── probe/lnk305_probe.ps1     # GUI probe: Enter / Go to Shortcut Target
├── fix-log.md
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salshelllink.h   # SalPlainPathAllocW, SalShellLinkWholeTargetW (new, pure);
                            # SalShellLinkGetPathU8, SalFolderShortcutTargetU8 (changed)
src/saltests/saltests.cpp   # TestShellLinkWholeTarget305
```

**Structure Decision**: the rule lives next to the reader in `salshelllink.h` (header-only,
already included by every caller and by saltests). The plug-ins keep their own twin in
`splfiledlg.h` (feature 304) - the existing pattern for this rule pair
(`SalIsFolderShortcutIni` / `SplFileDlgDetail::IsFolderShortcutIni`); see research R2.

## Complexity Tracking

None.
