# Tasks: Create Directory takes a relative name in a long folder

**Input**: Design documents from `specs/274-createdir-long-folder/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: the hidden-desktop probe `probe/createdir274_probe.ps1` (already written and run
before the fix, `probe/result_before.txt`); `saltests` as a regression run (no new pure rule -
`SalNameTooLongForFileSystemU8` is covered since 259).

## Phase 1: Setup

- [X] T001 Confirm the probe in specs/274-createdir-long-folder/probe/createdir274_probe.ps1 finds its library by the relative path (no `-Lib`) and its header names rows SHORT, REL, CJK, U255, U256, LIMIT

## Phase 2: Foundational

None - the change is one function.

## Phase 3: User Story 1 - New folder by a relative name in a long folder (P1)

**Goal**: F7 joins a typed relative name with the panel path up to the program's path limit.
**Independent Test**: probe rows REL, CJK, U255 (SHORT as the control) PASS.

- [X] T002 [US1] In `CFilesWindow::CreateDir` (disk branch) in src/fileswn5.cpp pass `NULL, SAL_MAX_PATH_UTF8` as `callNethood, nameBufSize` to `SalGetFullName`, with a feature-274 comment; keep the existing `strlen(path) >= SAL_MAX_PATH_UTF8` guard

## Phase 4: User Story 2 - Refusals that say the true reason (P2)

**Goal**: a new folder name over 255 UTF-16 units is refused with "too long name" before anything is created; a too long joined path keeps "The path specified is too long.".
**Independent Test**: probe rows U256 and LIMIT PASS.

- [X] T003 [US2] In `CFilesWindow::CreateDir` in src/fileswn5.cpp, after a successful `SalGetFullName` and before `GetRootPath` / `CheckAndCreateDirectory`, judge the last component of `path` with `SalNameTooLongForFileSystemU8` (include src/common/salmaskname.h if fileswn5.cpp does not see it); over 255 units -> `errTextID = IDS_TOOLONGNAME` in the existing message box branch (title `IDS_ERRORCREATINGDIR`) and `goto CREATE_AGAIN`

## Phase 5: Polish & Cross-Cutting

- [X] T004 Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [X] T005 Build: PowerShell `.\build.cmd` -> `BUILD SUCCEEDED`
- [X] T006 Regression rules: `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `0 failed`
- [X] T007 Probe after the fix on the hidden desktop (quickstart.md step 3) -> all rows PASS into specs/274-createdir-long-folder/probe/result_after.txt; registry restored and identical
- [X] T008 Record before / after, commands and results in specs/274-createdir-long-folder/fix-log.md

## Dependencies

T001 -> T002 -> T003 -> T004..T006 -> T007 -> T008. T002 and T003 edit the same function (not parallel).

## Parallel opportunities

T004 can run while T005 builds; nothing else.

## Implementation strategy

MVP = US1 (T002): the measured refusal of valid names goes away. US2 (T003) is needed for the
item's *Expected* ("a name over 255 UTF-16 units ... refused with a message that says so"),
because with the join fixed Windows itself would answer "invalid name".
