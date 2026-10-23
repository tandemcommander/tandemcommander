# Tasks: FTP panel Create Directory and Quick Rename update the upload listing cache

**Input**: Design documents from `specs/323-ftp-upload-cache-args/` (spec.md, plan.md, research.md,
data-model.md, quickstart.md); the stopped run's record `fix-log-302.md`.
**Tests**: the spec's success criteria are probe rows (SC-001..SC-005) and the pure rule gets
`saltests` checks (project rule: pure decisions in `src/common/` with `saltests`).

## Phase 1: Setup

- [X] T001 Start `specs/323-ftp-upload-cache-args/fix-log.md` (carried-over state, measurement at 4c33e2fc, plan of this run)
- [X] T002 Move 302 review 2's test server into the probe folder: `specs/323-ftp-upload-cache-args/probe/ftpmini_hide.py` (copy of `probe/review2/ftpmini_hide.py`; keep the review2 record as it is)

## Phase 2: Foundational

- [X] T003 Build the carried-over state (`.\build.cmd` -> `BUILD SUCCEEDED`) and record it in `specs/323-ftp-upload-cache-args/fix-log.md`

## Phase 3: User Story 1 - A file renamed in the panel is not overwritten without the question (P1)

**Goal / independent test**: probe row REN-UP PASS (carried over from 302).

- [X] T004 [US1] Confirm the carried-over Quick Rename calls in `src/plugins/ftp/ctrlcon5.cpp` pass `(userBuffer, hostBuf, portBuf, ...)` and `ReportRename` / `ReportUnknownChange` in `src/plugins/ftp/operats9.cpp` call `InvalidateAllListings()`; record in fix-log

## Phase 4: User Story 3 - Create Directory with a path never hides an existing folder's files (P1)

**Goal / independent test**: probe rows MKD-HID and MKD-CASE PASS; saltests checks of the rule.

- [X] T005 [P] [US3] Create the pure rule `src/common/salftpmkdirreport.h` (header-only): `SalFtpMkdirIsNamedComponent(name)` (not NULL, empty, `.`, `..`) and `SalFtpMkdirComponentAction(unknownResult, isLastNamed, parentListsIt)` -> record created / nothing / invalidate the parent listing (data-model.md table)
- [X] T006 [P] [US3] Add saltests checks of the rule in `src/saltests/saltests.cpp` (every row of the decision table; named-component cases `""`, `.`, `..`, `.cfg`, `...`, NULL)
- [X] T007 [US3] Use the rule in `CUploadListingsOnServer::ReportCreateDirs` (`src/plugins/ftp/operats9.cpp`): relative branch - pre-scan a copy of `newDirs` for the number of named components, skip empty components; absolute branch - the first cut component is the last named one; an earlier component: parent listing ready / newer listing holding the name -> nothing, otherwise `InvalidateListing`; never `AddEmptyListing` for it; update the comment of `ReportCreateDirs` in `src/plugins/ftp/operats.h`
- [X] T008 [US3] Add rows MKD-HID and MKD-CASE (from `probe/review2/ftp302_rv.ps1`, server `probe/ftpmini_hide.py`) to `specs/323-ftp-upload-cache-args/probe/ftp302_probe.ps1`

## Phase 5: User Story 2 - A folder created from the panel is known to a running upload (P2)

**Goal / independent test**: probe rows MKD-ABS, MKD-REN, REN-PATH PASS (carried over).

- [X] T009 [US2] Confirm the carried-over Create Directory calls in `src/plugins/ftp/ctrlcon5.cpp` (created / result unknown) pass `(userBuffer, hostBuf, portBuf, ...)`; record in fix-log

## Phase 6: Polish & verification

- [X] T010 Build (`.\build.cmd`), saltests (`build\tandemcommander\Debug_x64\saltests\saltests.exe` -> 0 failed), encoding guard (`python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`); record in fix-log
- [X] T011 Probe `specs/323-ftp-upload-cache-args/probe/ftp302_probe.ps1` on the fixed build -> `probe/result_after.txt`, all rows PASS
- [X] T012 Negative controls: the probe on `main`'s FTP sources (`result_main.txt`: MKD-ABS, REN-UP fail) and on 302's state (`result_302state.txt`: MKD-HID, MKD-CASE fail); restore the sources with `git checkout HEAD -- src/plugins/ftp` and rebuild
- [X] T013 Regression `specs/288-ftp-per-server-encoding/probe/ftp288_probe.ps1` -> `probe/regress_288.txt` 20 / 0
- [X] T014 Record before / after, commands and results in `specs/323-ftp-upload-cache-args/fix-log.md`

## Dependencies

T001-T003 first; US1 (T004) and US2 (T009) only confirm carried-over code; US3 T005/T006 in parallel,
then T007, T008; Phase 6 after all. MVP: the carried-over fix + US3 (without US3 the argument fix is
a regression - it must not ship alone).
