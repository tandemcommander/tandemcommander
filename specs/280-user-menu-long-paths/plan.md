# Implementation Plan: User Menu on items in folders of 260 or more bytes - work, or refuse aloud

**Branch**: `280-user-menu-long-paths` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/280-user-menu-long-paths/spec.md`

## Summary

Every value the User Menu inserts into a command reaches it whole, or the command is refused
with "too long name" before anything runs. Three pure rules (copy whole, path with a trailing
backslash, folder + name) go into a new header `src/common/salumvalue.h` with saltests checks.
The internal enumeration contract (`UM_GetNextFileName`) hands folder and name in buffers of
`SAL_MAX_PATH_UTF8` bytes and can answer "too long"; `CMainWindow::UserMenu` refuses an item that
does not fit its 259-byte expansion before preparing its command, and the route without a shell
prepares every item's command first and starts them only when all were prepared. The panel and
Find routes fill `FullPathLeft/Right` and `CompareName1/2` with the whole-or-refuse rules and
record "too long" flags, which `UserMenu` turns into the "too long name" refusal when the command
uses the value; the panel's `$(ListOfSelectedFullNames)` is built whole (`CSalPathBuf`, as Find).

## Technical Context

**Language/Version**: C++20 (MSVC v143), pure WinAPI; the core (`src/`)  
**Primary Dependencies**: none new  
**Storage**: N/A  
**Testing**: `saltests` (new `TestUserMenuValue280`, with negatives that reproduce the 259-byte cut ending at a backslash); GUI probe `probe/um280_probe.ps1` on the hidden desktop (24 rows); regression probes of 226, 229, 234  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application (core)  
**Performance Goals**: none (one heap allocation of two 96 KB buffers per User Menu command; the direct route keeps the prepared commands in memory until started)  
**Constraints**: no new UI strings (`IDS_TOOLONGNAME` reused); no plug-in interface change (`UM_GetNextFileName` and `CUserMenuAdvancedData` are core-internal); behaviour with short values unchanged  
**Scale/Scope**: `mainwnd.h`, `mainwnd3.cpp`, `mainwnd4.cpp`, `finddlg1.cpp`, `execute.h`, new `src/common/salumvalue.h`, `saltests.cpp`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | a header only; no new project, no dependency | PASS |
| II. Backward compatibility | short values: unchanged (FR-007, control rows, 226/229/234 probes); the configuration and registry untouched | PASS |
| III. Incremental modernization | local change; pure rules tested | PASS |
| IV. Windows commitment | unchanged | PASS |
| V. Plugin architecture | `UM_GetNextFileName` is not in `src/plugins/shared`; no `spl_*.h` change | PASS |
| VI. UI consistency | the existing "too long name" box | PASS |
| CLAUDE.md "a path or name is never cut" | every cut site replaced by whole-or-refuse | PASS |
| CLAUDE.md data rules | no command runs on a cut path; a refusal before anything runs (fails closed) | PASS |

Post-design re-check: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/280-user-menu-long-paths/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/um-enumeration.md      (the internal enumeration contract, changed)
├── fix-log.md
├── probe/ (um280_probe.ps1, results)
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salumvalue.h   new - SalUMCopyWhole, SalUMPathWithBackslash, SalUMJoinWhole
src/saltests/saltests.cpp TestUserMenuValue280
src/mainwnd.h             UM_GetNextFileName: int result (UMNEXT_*), buffer size UM_ITEM_TEXT_SIZE
src/execute.h             CUserMenuAdvancedData: FullPath*TooLong, CompareName*TooLong
src/mainwnd4.cpp          GetNextFileFromPanel (whole), CMainWindow::UserMenu (heap item buffers,
                          refusal, prepared runs of the direct route, too-long flags)
src/mainwnd3.cpp          User Menu command: FullPath*, ListOfSelFullNames, CompareName*
src/finddlg1.cpp          GetNextItemFromFind (whole), OnUserMenu CompareName*
```

**Structure Decision**: core only; the pure rules in a header under `src/common/` (CLAUDE.md
working method).

## Complexity Tracking

None.
