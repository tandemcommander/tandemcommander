# Tasks: Translated sentences with names and error texts are readable (feature 127)

**Input**: `specs/127-mixed-template-texts/` - spec.md, plan.md, research.md, quickstart.md
**Tests**: requested by the maintainer ("independent tests for every issue").

## Phase 1: Setup

- [x] T001 Write `probe/mixed_probe.ps1` + `probe/lvtext_lib.ps1` (rows LOG, STATUS, BOX)
- [x] T002 Write `probe/scan_mixed.py` (inventory of every template composition with a name / error argument)

## Phase 2: Foundational (measure first)

- [x] T003 Run the probe on 0.1.9 in Czech -> `probe/mixed_result_before_v019.txt`
- [x] T004 `tools/check_encoding.py`: `GetErrorText(` as an argument, `params.Text =` / `log.Text =` as sinks; record the 22 findings -> `probe/guard_before.txt`
- [x] T005 Triage of the 46 candidates and of compositions without printf by a separate agent (research R3-R5, R7)
- [x] T006 Start `fix-log.md`

## Phase 3: User Story 1 - Find Files (P1)

- [x] T007 [US1] `src/salamdr2.cpp` `LoadStrU8`: wrap and convert again when the text does not fit the rest of the buffer
- [x] T008 [US1] `src/finddlg1.cpp`: status base through `LoadStrU8` (`char buf[300]`); the three titles (`IDS_FF_NAME`, `IDS_FF_NAMED`) through `LoadStrU8`, tail trimmed
- [x] T009 [US1] `src/find.cpp`: `IDS_FIND_DUPS_RESULTS` x2, the five log compositions (bounded), `IDS_FILEREADERROR2`, `IDS_CANTSHOWRESULTS`, `IDS_FINDLOG_SKIP` through `LoadStrU8`; `CSearchingString::Set` cuts with `SalFindTrimTornTail`

## Phase 4: User Story 2 - message boxes and texts (P1)

- [x] T010 [P] [US2] `src/dialogs3.cpp`, `src/icncache.cpp` x2, `src/mainwnd4.cpp` x3, `src/salamdr1.cpp` x2, `src/codetbl.cpp` x4: template through `LoadStrU8`, bounded
- [x] T011 [P] [US2] `src/fileswn5.cpp`: `IDS_ERROREXECVIEW` / `IDS_ERROREXECEDIT` x4 (with `GetErrorText` and with `IDS_TOOLONGNAME`), the two menu items
- [x] T012 [P] [US2] `src/fileswn6.cpp`: `IDS_NAMEISTOOLONG`, `IDS_TOOLONGNAME2`, `IDS_CANNOTREADDIR` x3, `IDS_FILEISTOOBIGFORFAT32`, the junction text
- [x] T013 [P] [US2] `src/fileswn3.cpp` `IDS_PATHINARCHIVENOTFOUND`; `src/fileswn9.cpp` `IDS_CANNOT_CREATE_UNC_NAME`; `src/fileswn8.cpp` `IDS_COPYDLGTITLE` / `IDS_MOVEDLGTITLE` x2
- [x] T014 [US2] `src/callstk.cpp`: the allowed-exception marker with its reason

## Phase 5: User Story 3 - the copy name (P1)

- [x] T015 [US3] `src/fileswn6.cpp`: `IDS_NEWNAME_COPY` / `IDS_NEWNAME_OF` through `LoadStrU8`

## Phase 6: User Story 4 - Registry Editor (P2)

- [x] T016 [US4] `src/plugins/regedt/fs2.cpp` x2, `fs3.cpp` x2, `utils.cpp`: templates through the plug-in's `LoadStrU8`, bounded

## Phase 7: User Story 5 - the guard (P2)

- [x] T017 [US5] `tools/check_encoding.py`: documentation text of the rule; guard on the fixed tree = 0 -> `probe/guard_after.txt`; a re-broken line is reported (negative control)

## Phase 8: Tests, gates, records

- [x] T018 Extend the probe: TITLE, COPYNAME (Slovak, from disk), REGDEL, English LOG/BOX
- [x] T019 Builds (Debug, Release), saltests, guard
- [x] T020 Probe: fixed build Czech (+ Slovak, English rows) -> `probe/mixed_result.txt`; 0.1.9 control with the extended probe
- [x] T021 Independent review (refute-first): every changed site - argument encodings, buffer bounds, sinks
- [x] T022 Records: `fix-log.md`, FEATURE-HISTORY, CHANGELOG, NEXT-WORK (R4 items, plug-ins), `issues/issue_7_report.md`, `issues/PROGRESS.md`
- [x] T023 Commit on `127-mixed-template-texts`, nothing pushed

## Dependencies

T007 first (more `LoadStrU8` callers follow); T008-T016 independent of each other by file except `fileswn6.cpp` (T012, T015) and `fileswn5.cpp` (T011); T017-T021 after the code.
