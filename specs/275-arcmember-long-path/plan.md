# Implementation Plan: F3 / F4 take archive members whose path inside the archive has 520 bytes or more

**Branch**: `275-arcmember-long-path` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/275-arcmember-long-path/spec.md`

## Summary

F3 (`CFilesWindow::ViewFile`, src/fileswn5.cpp) and F4 / Enter (`CFilesWindow::ExecuteFromArchive`,
src/fileswn6.cpp) of an archive member refuse a path inside the archive of 520+ bytes (feature 095's
`>= 2 * MAX_PATH` test) before the disk cache is asked. Both tests are removed: the path is built
in heap strings since 095, the listing bounds it (about 1,021 bytes), every archiver on the route
takes it (audit in research.md), and the plug-in interface 104 promise covers long names. The disk
cache's rule for the temporary copy (feature 260) stays the only length refusal, with its message.

The CAB plug-in copies the path into `char rootDir[U8_MAX_CAB_NAME]` with `lstrcpyn` - a silent
cut (unreachable with a real cabinet). It now refuses a path that does not fit with its existing
`IDS_TOOLONGNAME` message before copying (FR-003).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI only; existing `CSalHeapString` (salheapstr.h), `CDiskCache::GetName`
with the long mode (feature 260), the CAB plug-in's `Error()`
**Storage**: N/A (no registry, cache-key or file format change)
**Testing**: `saltests` (no rule changes - regression run); hidden-desktop probe
`probe/arcmember275_probe.ps1` (rows VIEWCAP, VIEWDEEP, EDITCAP, 7Z, TAR, OVERLIMIT, CTL); feature
260's probe (ARCCAP changed to expect the viewer) and 222's probe as regressions
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand` + the `uncab` plug-in)
**Performance Goals**: N/A (one member per key press)
**Constraints**: no new UI string (no `.slt` refresh); no plug-in interface change; never cut a
path or name
**Scale/Scope**: two tests removed in two core functions, one check added in one plug-in function

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency, no project change - PASS |
| II. Backward compatibility | plug-in interface unchanged (104's promise already covers long names; F5 hands them since 222); disk-cache keys unchanged; every case the item does not name behaves as before - PASS |
| III. Incremental modernization | removes one obsolete limit, the pattern of 260 - PASS |
| IV. Windows commitment | WinAPI only - PASS |
| V. Plug-in architecture | no interface change; one shipped plug-in hardened inside itself - PASS |
| VI. UI consistency | existing strings only (`IDS_UNPACKTOOLONGNAME`, uncab `IDS_TOOLONGNAME`) - PASS |

Post-design re-check: unchanged - PASS.

## Project Structure

### Documentation (this feature)

```text
specs/275-arcmember-long-path/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/arc-member-path.md
├── fix-log.md
├── probe/arcmember275_probe.ps1 (+ result_before.txt, result_after.txt)
└── tasks.md
```

### Source Code (repository root)

```text
src/fileswn5.cpp                 CFilesWindow::ViewFile - the 095 test removed (F3)
src/fileswn6.cpp                 CFilesWindow::ExecuteFromArchive - the 095 test removed (F4 / Enter)
src/plugins/uncab/uncab.cpp      UnpackOneFile - refuse instead of lstrcpyn into rootDir
specs/260-archive-cache-long-names/probe/cache260_probe.ps1   ARCCAP expects the viewer
specs/260-archive-cache-long-names/contracts/cache-tmp-path.md a pointer to 275
```

**Structure Decision**: no new header - there is no new pure rule (a limit is removed; the
remaining rule, `SalCacheTmpPathFitsU8`, is covered by saltests since 260).

## Complexity Tracking

None.
