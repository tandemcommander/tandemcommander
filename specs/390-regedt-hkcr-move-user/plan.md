# Implementation Plan: Registry Editor - Move from HKCR into the user's Classes key does nothing

**Branch**: `390-regedt-hkcr-move-user` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/390-regedt-hkcr-move-user/spec.md`

## Summary

A Move (F6) in the Registry Editor plug-in deletes its source by name after the copy. For a source
under `HKEY_CLASSES_ROOT` the name goes through the merged view, which - once the copy created the
user's half of the same path - reaches the new copy instead of the machine's key (measured: silent
no-op). The recursion `CopyOrMoveKeyRec` (`src/plugins/regedt/fs5.cpp`) will note, at each level
and before that level's target key is created, which halves hold the source key
(`HKLM\Software\Classes\<path>`, `HKCU\Software\Classes\<path>`); at the delete, exactly one half =
delete that half by its real path (`RegDeleteKeyW(HKEY_LOCAL_MACHINE | HKEY_CURRENT_USER,
L"Software\\Classes\\<path>")`) with the existing `IDS_REMOVESOURCE` box naming the real key; two
halves = today's delete through HKCR. The decision and the joined path (never cut) are a pure rule in
`src/common/salregkeyid.h` with `saltests` checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI registry (`RegOpenKeyExW`, `RegDeleteKeyW`); none new
**Storage**: the Windows registry (the user's own keys; nothing the program stores changes)
**Testing**: `saltests` (pure rule), GUI probe `specs/390-regedt-hkcr-move-user/probe/hkcr390_probe.ps1` on the hidden desktop; regression probes of 292, 294, 296, 297
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`regedt.spl`)
**Performance Goals**: two extra key opens per copied key, only for a Move whose source is under HKCR
**Constraints**: no new UI string; no plug-in ABI change; never cut a key path; fail closed
**Scale/Scope**: one function of `fs5.cpp` + one header + tests

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency, no project change - PASS |
| II Backward compatibility | Copy, Moves outside HKCR and HKCR keys of both halves unchanged; stored data unchanged - PASS |
| III Incremental modernization | a local change in one plug-in function, a pure rule with tests - PASS |
| IV Windows commitment | WinAPI only - PASS |
| V Plugin architecture | no `spl_*.h` / ABI change - PASS |
| VI UI consistency | the existing error box and texts; no new string, no `.slt` refresh needed - PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/390-regedt-hkcr-move-user/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/hkcr390_probe.ps1 (+ results)
```

No `contracts/`: nothing is exposed to plug-ins or other systems.

### Source Code (repository root)

```text
src/common/salregkeyid.h          # + SalRegHkcrDeleteHalf, SalRegJoinClassesPath (pure, header-only)
src/saltests/saltests.cpp         # + TestRegHkcrHalf390
src/plugins/regedt/fs5.cpp        # CopyOrMoveKeyRec: halves before the copy, the delete by real path
```

**Structure Decision**: the existing plug-in and shared-header layout; header-only because plug-ins
cannot compile a `.cpp` from `src/common` (standing rule).

## Complexity Tracking

None.
