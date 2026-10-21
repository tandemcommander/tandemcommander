# Tasks: An entry moved aside for an 8.3 clash is never left under `salNNN` silently

**Input**: Design documents from `specs/281-moved-aside-leftovers/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/probe-seam.md, quickstart.md

**Tests**: the project's checks - `saltests` for the pure rule (FR-007) and the hidden-desktop probe
(SC-001..SC-004) - are part of the feature.

## Phase 1: Setup

- [X] T001 Start the running log `specs/281-moved-aside-leftovers/fix-log.md` with the measurement by reading at 17ac1562 and the enumerated callers

## Phase 2: Foundational (blocking)

- [X] T002 Create the header-only retry rule and the Debug-only seam (`SalMoveBackRetryable`, `SAL_MOVE_BACK_RETRIES`, `SAL_MOVE_BACK_WAIT_MS`, `SalMoveBackSeamTake`, `SalMoveBackRetry`) in src/common/salmoveback.h per contracts/probe-seam.md
- [X] T003 Make `SalMoveFileBack` use `SalMoveBackRetry` in src/common/salfileio.cpp (same numbers as 221)
- [X] T004 [P] Add `saltests` checks of salmoveback.h (retryable errors, attempts, last error kept, success at the k-th attempt, the seam's count) in src/saltests/saltests.cpp
- [X] T005 Write the probe specs/281-moved-aside-leftovers/probe/left281_probe.ps1 (driver of 203's create_clash_probe.ps1; rows cp-left, cp-brief, dir-left, zip-left, zipdir-left, f7-left, new-left (Edit New File), ren-left, ren-brief - a row that cannot be driven is recorded NOT DRIVEN; env `TC_PROBE_MOVE_BACK_FAIL`; each `*-left` row requires exactly one "Error Renaming File" box naming the `salNNN` path (FR-005); registry backed up and restored)
- [X] T006 Build (`build.cmd`), run saltests, run the probe on the build with only T002-T003 -> `probe/result_before.txt` (expected: `*-left` rows FAIL - no box naming `salNNN`), record in fix-log.md

## Phase 3: User Story 1 - the core's create routes tell (P1) MVP

**Goal**: copy, folder copy, F7, Edit New File, unpack tell where the other entry stays.
**Independent test**: probe rows cp-left, dir-left, zip-left, zipdir-left, f7-left PASS; cp-brief PASS.

- [X] T007 [US1] Declare `CMovedAsideLeft`, `ReportMovedAsideLeft`, `GetMovedAsideReportParent` and the optional `CMovedAsideLeft* left = NULL` parameters of `SalCreateFileEx`, `SalCreateDirectoryEx`, `MakeUnpackFoldersOwn` in src/consts.h
- [X] T008 [US1] Implement `ReportMovedAsideLeft` / `GetMovedAsideReportParent` (DialogError BUTTONS_OK, IDS_ERRORRENAMINGFILE) in src/salamdr3.cpp
- [X] T009 [US1] `SalCreateFileEx` and `SalCreateDirectoryEx` fill the record when the second move back fails (error = that move back's), or report themselves when no record was passed, in src/worker.cpp
- [X] T010 [US1] The worker's file copy (`SalCreateFileEx` calls) and `DoCreateDir` report a left entry through `WM_USER_DIALOG` 5 in src/worker.cpp
- [X] T011 [US1] `MakeUnpackFoldersOwn` passes the record on; `CheckAndCreateDirectory` reports it (the caller's parent, else `GetMovedAsideReportParent`) in src/salamdr3.cpp
- [X] T012 [US1] `SafeFileCreate`: its own move aside reports a left entry (hParent) before its create error; the `MakeUnpackFoldersOwn` route likewise, in src/safefile.cpp
- [X] T013 [US1] F7 Create Directory and Edit New File report a left entry before their error in src/fileswn5.cpp

## Phase 4: User Story 2 - plug-in create services tell (P2)

**Goal**: FTP, SFTP, Renamer, DemoPlug creating through the program are covered.
**Independent test**: probe row ren-left shows the box for the Renamer's folder create (or the
wrapper path is covered by reading, recorded NOT DRIVEN).

- [X] T014 [US2] The plug-in wrappers `CSalamanderGeneral::SalCreateFileEx` / `SalCreateDirectoryEx` pass no record (the create function reports itself, owner of the calling thread); comment it in src/zip.cpp

## Phase 5: User Story 3 - PictView and the Renamer retry (P3)

**Goal**: a short hold no longer leaves the entry aside.
**Independent test**: probe row ren-brief: renamed, nothing left, no box.

- [X] T015 [P] [US3] `PvMoveAsideShortNameClash` moves back through `SalMoveBackRetry` in src/plugins/pictview/render1.cpp
- [X] T016 [P] [US3] `MoveAsideShortNameClash` moves back through `SalMoveBackRetry` in src/plugins/renamer/rendlg3.cpp

## Phase 6: Polish

- [X] T017 Encoding guard, build, saltests; the probe after -> `probe/result_after.txt`; regression 203 (`regress_203.txt`) and 201 (`regress_201.txt`); fix-log before/after
- [ ] T018 Independent review (SKILL step 7), findings into fix-log.md

## Dependencies

T002 -> T003, T004, T015, T016; T002-T005 -> T006; T007 -> T008..T014; T006 before any of T009..T016
(the before measurement); T017 after all.

## Parallel opportunities

T004 with T005; T015 with T016.

## Implementation strategy

MVP = Phase 3 (the core's routes, the item's main gap); then US2 (one wrapper change), US3.
