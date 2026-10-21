# Implementation Plan: An entry moved aside for an 8.3 clash is never left under `salNNN` silently

**Branch**: `281-moved-aside-leftovers` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/281-moved-aside-leftovers/spec.md`

## Summary

The create paths (`SalCreateFileEx`, `SalCreateDirectoryEx` in `src/worker.cpp`,
`CSalamanderSafeFile::SafeFileCreate` in `src/safefile.cpp`, and `MakeUnpackFoldersOwn` in
`src/salamdr3.cpp` through `SalCreateDirectoryEx`) learn to hand back where an entry stayed when its
move back failed (a `CMovedAsideLeft` record: the UTF-8 `salNNN` path and the error). Each caller
shows it with the existing texts (title `IDS_ERRORRENAMINGFILE`, the OK-only error dialog
`IDD_ERROR3` with the path and the reason - the form 221 uses in the worker); a caller that passes
no record (the plug-in interface wrappers) gets the message shown by the create function itself,
owned by a window of the calling thread. PictView and the Renamer move back through a shared,
header-only retry rule (`src/common/salmoveback.h`), which the core's `SalMoveFileBack` uses too;
the header also carries the Debug-only probe seam `TC_PROBE_MOVE_BACK_FAIL`.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI; winliblt dialogs; the core's `DialogError`
**Storage**: N/A (no configuration, no registry change)
**Testing**: `saltests` (the retry rule and the seam's count), hidden-desktop GUI probe
`specs/281-moved-aside-leftovers/probe/left281_probe.ps1` (driver: 203's `create_clash_probe.ps1`)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application + plug-ins (`.spl`)
**Performance Goals**: no change on the success path; on the failure path the existing bounded
retry (about 1 s per move back, 221)
**Constraints**: plug-in ABI unchanged (`LAST_VERSION_OF_SALAMANDER` 108 stays); no new UI strings;
paths never cut; nothing deleted
**Scale/Scope**: 9 call sites in the core, 2 plug-ins, 1 new header, 1 probe

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I Build reproducibility | no new dependency; header-only rule; `build.cmd` | PASS |
| II Backward compatibility | plug-in interface signatures and results unchanged; a plug-in only additionally sees a message box in a case that left the user's entry renamed | PASS |
| III Incremental modernization | small, local changes at the named sites | PASS |
| IV Windows commitment | WinAPI only | PASS |
| V Plug-in architecture | no ABI change; plug-ins include a header-only rule like `salnameorder.h` (115) | PASS |
| VI UI consistency | existing dialog, title and form (221) | PASS |

Re-check after design: PASS (no change).

## Project Structure

### Documentation (this feature)

```text
specs/281-moved-aside-leftovers/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
├── contracts/probe-seam.md
└── probe/left281_probe.ps1, result_*.txt
```

### Source Code (repository root)

```text
src/common/salmoveback.h        new: retry rule + Debug seam (header-only)
src/common/salfileio.cpp        SalMoveFileBack uses the rule
src/consts.h                    CMovedAsideLeft, ReportMovedAsideLeft, new optional parameters
src/worker.cpp                  SalCreateFileEx, SalCreateDirectoryEx (produce); DoCopyFile, DoCreateDir (report)
src/salamdr3.cpp                MakeUnpackFoldersOwn (pass on), CheckAndCreateDirectory (report)
src/safefile.cpp                SafeFileCreate (its own move aside + MakeUnpackFoldersOwn: report)
src/fileswn5.cpp                F7 Create Directory, Edit New File (report)
src/zip.cpp                     plug-in wrappers: the create function reports itself (no record)
src/plugins/pictview/render1.cpp   PvMoveAsideShortNameClash: retried move back
src/plugins/renamer/rendlg3.cpp    MoveAsideShortNameClash: retried move back
src/saltests/saltests.cpp       checks of salmoveback.h
```

**Structure Decision**: the existing tree; one new header under `src/common/`.

## Complexity Tracking

No violations.
