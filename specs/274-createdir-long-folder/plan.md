# Implementation Plan: Create Directory takes a relative name in a long folder

**Branch**: `274-createdir-long-folder` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/274-createdir-long-folder/spec.md`

## Summary

`CFilesWindow::CreateDir` (src/fileswn5.cpp, F7 on a disk panel) joins a typed relative name with
the panel path through `SalGetFullName` with its default `nameBufSize` (MAX_PATH), although its
buffer and the rest of the routine take `SAL_MAX_PATH_UTF8` (feature 027). The call gets
`nameBufSize = SAL_MAX_PATH_UTF8`, as Edit New File did in feature 259. A joined path that does
not fit keeps the existing refusal "The path specified is too long." (`IDS_TOOLONGPATH`).

With the join fixed, a new folder name over 255 UTF-16 units would reach Windows, which answers
error 123 "invalid name" (measured for files in 259). The name is judged first with the existing
`SalNameTooLongForFileSystemU8` (salmaskname.h) and refused with the existing
`IDS_TOOLONGNAME` - before anything is created (also before missing parent folders are made).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI only; existing `SalGetFullName` (salamdr3.cpp),
`SalNameTooLongForFileSystemU8` (src/common/salmaskname.h, saltests-covered since 259)
**Storage**: N/A (no registry or file format change)
**Testing**: `saltests` (unchanged rules - run as a regression); hidden-desktop probe
`probe/createdir274_probe.ps1` (rows SHORT, REL, CJK, U255, U256, LIMIT)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand`)
**Performance Goals**: N/A (one name per F7)
**Constraints**: no new UI string (no `.slt` refresh); no plug-in ABI change; never cut a path
or name
**Scale/Scope**: one function (`CFilesWindow::CreateDir`, disk branch), a few lines

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency, no project change - PASS |
| II. Backward compatibility | no registry, file format or plug-in interface change; every case the item does not name behaves as before - PASS |
| III. Incremental modernization | a local fix of one call, the pattern of 259 - PASS |
| IV. Windows commitment | WinAPI only - PASS |
| V. Plug-in architecture | the plug-in FS branch of CreateDir is untouched - PASS |
| VI. UI consistency | existing strings only (`IDS_TOOLONGPATH`, `IDS_TOOLONGNAME`, `IDS_ERRORCREATINGDIR`); the same message box as the other pre-creation refusals of F7 - PASS |

Post-design re-check: unchanged - PASS.

## Project Structure

### Documentation (this feature)

```text
specs/274-createdir-long-folder/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
├── probe/createdir274_probe.ps1 (+ result_before.txt, result_after.txt)
└── tasks.md
```

No `contracts/`: the change has no interface another component relies on.

### Source Code (repository root)

```text
src/fileswn5.cpp      CFilesWindow::CreateDir - the SalGetFullName call and the name check
```

**Structure Decision**: a single core source file; no new header (the rule
`SalNameTooLongForFileSystemU8` already exists in `src/common/` with saltests checks).

## Complexity Tracking

None.
