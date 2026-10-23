# Implementation Plan: Undelete warns when it cannot tell the restore target's volume

**Branch**: `324-undelete-unknown-volume` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/324-undelete-unknown-volume/spec.md`

## Summary

The Undelete plug-in's three "same volume?" checks (`src/plugins/undelete/fs2.cpp`:
`CopyOrMoveFromFS` - the `IDS_SAMEPARTITION` warning; `GetTempDirOutsideRoot` - the system
temporary folder and the configured alternative) ask the core's `PathsAreOnTheSameVolume`, which
answers "different" (estimation flag set) when it read only one of the two volume names. They
now go through one plug-in helper: the core's answer first; a "different" that is only an
estimation is re-decided by the file system's identity - the volume serial number of each path's
nearest existing folder (wide API, `\\?\` form, any length) - and an identity that cannot be read
counts as the same volume (fail closed). The core, its plug-in contract and every UI string stay
as they are. The decision and the identity read are header-only (`src/common/salsamevolume.h`,
on top of 103's `salsamefile.h`) with `saltests` checks, including a real-file-system check on
the measured fixture (a junction named `Zálohy` to the volume root, a junction to a volume-GUID
subfolder).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; `src/common/salsamefile.h` (103), `splunicode.h`
(`SplU8ToWExtAlloc`)
**Storage**: N/A
**Testing**: `saltests` (pure decision table, root / cut helpers, real-FS identity on junction
fixtures under `%TEMP%`, no admin); measurement script `probe/measure_volume.py` (before: the
core's API facts); the restore through the elevated Undelete GUI is NOT DRIVEN (person step)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (plug-in DLL `undelete.spl`)
**Performance Goals**: at most two extra handle opens per check, only when the core is unsure
**Constraints**: no change to the plug-in interface, the core's answer, UI strings, stored data;
paths never cut, never through a code-page API
**Scale/Scope**: 1 plug-in source file, 1 new header, saltests

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency; header-only rule - PASS |
| II. Backward compatibility | no ABI, registry, configuration or file-format change; the core's answer to other plug-ins unchanged - PASS |
| III. Incremental modernization | a minimal fix at the three defective call sites - PASS |
| IV. Windows commitment | wide Win32 API only - PASS |
| V. Plug-in architecture | the plug-in interface is untouched - PASS |
| VI. UI consistency | no UI change (the existing warning / folder question) - PASS |

CLAUDE.md standing rules touched: *Never lose the user's data* - a "safe?" check fails closed
(098): unknown = same volume; same-place decisions by identity (103): the volume serial of an open
handle; UTF-8 paths to the wide API, whole (066, 097). Post-design re-check: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/324-undelete-unknown-volume/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md
└── probe/measure_volume.py      (the measurement of step 3, before / after facts)
```

### Source Code (repository root)

```text
src/common/salsamevolume.h        new: SalVolumeSerialMatch, SalVolumeGuardSame,
                                  SalWPathRootLength, SalWPathCutLast,
                                  SalGetNearestVolumeIdentityW, SalVolumeGuardForPaths
src/plugins/undelete/fs2.cpp      UndPathsMayShareVolume(); the three call sites use it
src/saltests/saltests.cpp         TestSameVolume324()
```

No contracts folder: the change is internal to the Undelete plug-in (no plug-in API, file format
or protocol changes).

## Complexity Tracking

None.
