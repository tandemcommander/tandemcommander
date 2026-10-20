# Implementation Plan: Plug-in closing - forced Disk Map unload, stray comparator box

**Branch**: `266-close-stray-box` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/266-close-stray-box/spec.md`

## Summary

Three small changes in two plug-ins, no new text, no interface change:

1. File Comparator (`src/plugins/filecomp`): the main window marks both file views "close
   begun" at the start of its `WM_DESTROY` (before it destroys their data and before the wait
   for a running comparison pumps messages); the hex view's `WM_USER_HANDLEFILEERROR` handler
   returns at once when the mark is set - no `DialogError`, no posted `CM_CLOSEFILES`.
2. `CFileMapping::Destroy` resets `FileSize` to 0 next to the handles it closes.
3. Disk Map (`src/plugins/diskmap`): no behaviour change; `CPluginInterface::Release` documents
   that a forced release ends a map thread still inside a shell command by force (the core's
   force semantics; 143 FR-004 forbids answering the shell's window), so the next reader does
   not "fix" it into a hang or a cancelled shell window.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI; the plug-in SDK (`src/plugins/shared`)
**Storage**: N/A
**Testing**: build (`build.cmd`), `saltests` (unchanged - no pure rule is added), the 143 probe
rows E4-E6 as a Disk Map regression check; the comparator's timing is NOT DRIVEN (research R2)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (plug-ins)
**Performance Goals**: N/A
**Constraints**: no new UI strings (would need the `.slt` refresh), plug-in ABI untouched
**Scale/Scope**: ~4 files, ~20 lines

## Constitution Check

| Principle | Status |
|---|---|
| I Build reproducibility | PASS - no build change |
| II Backward compatibility | PASS - no interface, registry or text change |
| III Incremental modernization | PASS - smallest change at the sites |
| IV Windows commitment | PASS |
| V Plugin architecture preservation | PASS - `spl_*.h` untouched; `LAST_VERSION_OF_SALAMANDER` unchanged |
| VI UI consistency | PASS - removes a box that has no meaning during a close |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/266-close-stray-box/
├── spec.md
├── plan.md
├── research.md
├── quickstart.md
├── tasks.md
├── fix-log.md
└── checklists/requirements.md
```

No `data-model.md` (no data) and no `contracts/` (no interface is exposed or changed).

### Source Code (repository root)

```text
src/plugins/filecomp/viewwnd.h      CFileViewWindow: CloseBegun flag + BeginClose()
src/plugins/filecomp/viewwnd.cpp    CFileViewWindow constructor: CloseBegun = FALSE
src/plugins/filecomp/viewwnd3.cpp   CHexFileViewWindow WM_USER_HANDLEFILEERROR: return when CloseBegun
src/plugins/filecomp/mainwnd.cpp    CMainWindow WM_DESTROY: BeginClose() on both views first
src/plugins/filecomp/filemap.cpp    CFileMapping::Destroy: FileSize = 0
src/plugins/diskmap/DiskMapPlugin/DiskMapPlugin.cpp   Release: comment on the force path
```

**Structure Decision**: edits in place in the two plug-ins; no new files.

## Complexity Tracking

None.
