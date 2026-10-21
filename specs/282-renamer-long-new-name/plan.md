# Implementation Plan: The Renamer builds a new name of any length the file system accepts

**Branch**: `282-renamer-long-new-name` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/282-renamer-long-new-name/spec.md`

## Summary

The Renamer plug-in builds each new name into storage of `REN_MAX_NAME` bytes
(`SAL_MAX_PATH_UTF8` = 3 x 32,767 + 1, the UTF-8 form of the longest Windows path) allocated on the
heap instead of `char[MAX_PATH]`; the builders (`CRenamer::Rename`,
`CRenamerDialog::GetManualModeNewName`) take the size as a parameter. The preview builds into a heap
buffer of the same size, converts texts for the list view into a growing wide buffer, and shows the
path column whole. "Include subdirectories" reads folders in a heap path buffer of the same size;
found items are accepted up to it; `CSourceFile::NameLen` is widened so it holds such a length. The
existing errors stay (no new strings). A depth guard keeps the now unbounded folder recursion off
the end of the thread's stack (research R3).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI; the plug-in interface (`CSalamanderGeneralAbstract`: `SalPathAppend`,
`CutDirectory`, `DupStr`) - unchanged
**Storage**: N/A (no registry or file format change)
**Testing**: hidden-desktop GUI probe `probe/ren_longnew_probe.ps1`; regressions: 199, 206, 207, 209
Renamer probes; `saltests` (no core change - run as the standard check)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, plug-in `src/plugins/renamer`
**Performance Goals**: no visible change - one heap buffer per script build / preview window, one
transient buffer per substitution
**Constraints**: never cut a name (refuse); UTF-8 / WTF-8 names unchanged; plug-in ABI untouched
**Scale/Scope**: 7 source files of one plug-in

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I Build reproducibility | no new dependency; `build.cmd` | PASS |
| II Backward compatibility | every name that worked works the same; only refusals of valid long names disappear; the existing errors for the rest | PASS |
| III Incremental modernization | local buffer changes at the enumerated sites | PASS |
| IV Windows commitment | WinAPI only | PASS |
| V Plug-in architecture | no interface change (internal plug-in structures only) | PASS |
| VI UI consistency | no UI change; existing texts | PASS |

Re-check after design: PASS (no change).

## Project Structure

### Documentation (this feature)

```text
specs/282-renamer-long-new-name/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/ren_longnew_probe.ps1, result_*.txt
```

No `contracts/`: nothing outside the plug-in sees the changed structures.

### Source Code

```text
src/plugins/renamer/
├── crenamer.h     # REN_MAX_NAME; CSourceFile::NameLen widened; Rename(..., newNameSize, ...)
├── crenamer.cpp   # Rename: the size parameter, tmp on the heap, pathLen guarded
├── rendlg.h       # GetManualModeNewName(..., newNameSize, ...)
├── rendlg2.cpp    # BuildScript: newName on the heap; GetManualModeNewName: size, pathLen guarded
├── rendlg.cpp     # ReloadSourceFiles / LoadSubdir: heap path, REN_MAX_NAME limits, depth guard
├── preview.h      # NewNameCache, path text, wide text on the heap
└── preview.cpp    # builds into them; the path column whole
```

## Design

1. `REN_MAX_NAME` (`crenamer.h`) = `SAL_MAX_PATH_UTF8`. Bytes of a built name incl. the terminator.
2. `CRenamer::Rename(file, counter, newName, newNameSize, newPart)`: the folder part is copied only
   when `pathLen + 2 <= newNameSize` (else -1: the existing "too large" error); every `MAX_PATH` /
   `MAX_PATH - pathLen` becomes `newNameSize` / `newNameSize - pathLen`; `tmp` is
   `malloc(newNameSize)` freed on every return.
3. `BuildScript`: `newName = malloc(REN_MAX_NAME)`; none → `Error(IDS_LOWMEM)`, nothing built;
   freed at the end. `GetManualModeNewName(file, index, newName, newNameSize, newPart)` the same
   guard and `GetEditLineU8(..., newNameSize - pathLen)`.
4. Preview: `NewNameCache = malloc(REN_MAX_NAME)` in the constructor (freed in the destructor; none
   → the column shows nothing and the icon is the warning); the manual line and `Rename` into it
   with `REN_MAX_NAME`. Texts for the list view go through a growing `WCHAR` buffer sized by
   `MultiByteToWideChar(..., NULL, 0)`; the path column copies the full name into a growing `char`
   buffer and cuts the last component (`CutDirectory`) - the folder whole.
5. `ReloadSourceFiles`: `pathBuf = malloc(REN_MAX_NAME)` before the window is disabled (none →
   `Error(IDS_LOWMEM)`, an empty listing as for a bad mask); `dirLen + 2 <= REN_MAX_NAME` replaces
   `dirLen < MAX_PATH`; freed at the end. `LoadSubdir(path, subdir, depth)`: `SalPathAppend(...,
   REN_MAX_NAME)`, the find data and the converted name on the heap (small frames), the found
   item's `NameLen < REN_MAX_NAME`; deeper than `REN_MAX_DEPTH` (1024) levels → the existing
   "too long path name" refusal for that folder (Skip / Skip all / Cancel as now).
6. `CSourceFile::NameLen : 29` (was 15; with `IsDir : 1` and `State : 1` still one 32-bit unit).
