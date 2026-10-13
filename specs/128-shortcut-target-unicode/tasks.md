# Tasks: A shortcut opens its target, whatever letters the path has (feature 128)

**Input**: `specs/128-shortcut-target-unicode/` - spec.md, plan.md, research.md, quickstart.md
**Tests**: requested by the maintainer ("independent tests for every issue").

## Phase 1: Setup

- [x] T001 Write `probe/lnk_probe.ps1` (seven shortcuts written with `IShellLinkW`; rows ENTER 1-6, GOTO 2, 3, 7)

## Phase 2: Foundational (measure first)

- [x] T002 Run the probe on 0.1.9 -> `probe/lnk_result_before_v019.txt` (7 FAIL; the report's box reproduced)
- [x] T003 Start `fix-log.md`

## Phase 3: User Story 1 - Enter on a shortcut (P1)

- [x] T004 [P] [US1] `src/common/salshelllink.h`: `SalShellLinkGetPathU8`
- [x] T005 [P] [US1] `src/saltests/saltests.cpp`: `TestShellLink128`
- [x] T006 [US1] `src/fileswn2.cpp` `CFilesWindow::Execute`: `IShellLinkW`, the three `GetPath` calls through the helper with `SAL_MAX_PATH_UTF8`

## Phase 4: User Story 2 - Go to Shortcut Target (P1)

- [x] T007 [US2] `src/fileswn0.cpp` `CFilesWindow::FocusShortcutTarget`: `IShellLinkW`, the two `GetPath` calls through the helper

## Phase 5: Tests, gates, records

- [x] T008 Builds (Debug, Release), saltests, `tools/check_encoding.py`
- [x] T009 Probe on the fixed build -> `probe/lnk_result.txt` (18 PASS)
- [x] T010 Independent review (refute-first): later code in both functions that assumed a path under `MAX_PATH`
- [x] T011 Records: `fix-log.md`, FEATURE-HISTORY, CHANGELOG, NEXT-WORK, `issues/issue_8_report.md`, `issues/PROGRESS.md`
- [x] T012 Commit on `128-shortcut-target-unicode`, nothing pushed

## Dependencies

T004 -> T006, T007; T005 with T004; T008-T010 after the code.
