# Implementation Plan: Registry Editor - a too long full key path is refused, never cut

**Branch**: `380-regedt-full-path-cut` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/380-regedt-full-path-cut/spec.md`

## Summary

The Registry Editor plug-in converts wide key paths and names to UTF-8 with the inline helper
`WStrToU8` (`src/plugins/regedt/utils.h`), which returns the byte count or 0 on failure and, on
failure, leaves a cut string terminated at the buffer's end. Four sites whose output reaches the
panel do not check that result correctly; each gets a check (research R1-R4):

1. `fs2.cpp` `CPluginFSInterface::GetFullFSPath` - `>= 0` (always true for a `DWORD`) becomes a
   real test: a failed conversion sets `success = FALSE` after `Error(IDS_LONGNAME)`; the earlier
   failed conversion of the typed path (`U8ToWStr`) sets `success = FALSE` with the same message
   instead of returning with the caller's `success` untouched.
2. `fs3.cpp` `QuickRename` - the focus name: a failed conversion leaves `newName` empty.
3. `fs5.cpp` (rename by Move, `nextFocus`) - the same.
4. `finddlg2.cpp` *Focus* (`CMD_FINDFOCUS`) - both conversions checked; a failure shows
   `IDS_LONGNAME` and posts nothing.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: Win32 (`WideCharToMultiByte`), the plug-in interface (`spl_fs.h`, unchanged)
**Storage**: N/A (the registry is the plug-in's data; nothing new is stored)
**Testing**: hidden-desktop probe `probe/regpath380_probe.ps1` (rows SHORT / LONG / CJK); build;
encoding guard. No `saltests` rule: the decisions are single result checks inside plug-in code,
nothing pure to put under `src/common/`.
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (plug-in DLL `regedt.spl`)
**Performance Goals**: N/A
**Constraints**: plug-in ABI unchanged; no new UI string (`IDS_LONGNAME` exists); never cut a path
**Scale/Scope**: 4 sites in 4 files of one plug-in

## Constitution Check

| Principle | Status |
|---|---|
| I. Build reproducibility | PASS - no build change |
| II. Backward compatibility | PASS - paths that fit behave as before; only cut results become refusals |
| III. Incremental modernization | PASS - targeted fixes, no rewrite of the helper |
| IV. Windows commitment | PASS |
| V. Plug-in architecture preservation | PASS - interface and `LAST_VERSION_OF_SALAMANDER` untouched |
| VI. UI consistency | PASS - the plug-in's existing "too long path" message |

Re-check after design: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/380-regedt-full-path-cut/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md
└── probe/regpath380_probe.ps1, result_before.txt, result_after.txt
```

No `contracts/`: no interface changes.

### Source Code (repository root)

```text
src/plugins/regedt/
├── fs2.cpp       # GetFullFSPath
├── fs3.cpp       # QuickRename focus name
├── fs5.cpp       # rename by Move, nextFocus
└── finddlg2.cpp  # Find window, Focus command
```

**Structure Decision**: changes stay in the four call sites; `utils.h` is unchanged (research R5).

## Complexity Tracking

None.
