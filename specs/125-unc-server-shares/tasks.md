# Tasks: From a server name to its shared folders (feature 125)

**Input**: `specs/125-unc-server-shares/` - spec.md, plan.md, research.md, data-model.md, contracts/probe-seam.md, quickstart.md
**Tests**: requested by the maintainer ("independent tests for every issue").

## Phase 1: Setup

- [x] T001 Write the measuring probe `specs/125-unc-server-shares/probe/unc_probe.ps1` (rows S1-S5, U1, X1)
- [x] T002 Build with `nethood=on` (measurement only, `plugins.cfg` restored afterwards)

## Phase 2: Foundational (measure first)

- [x] T003 Run the probe on 0.1.9 -> `probe/unc_measure_v019.txt`
- [x] T004 Run the probe on the build with the plug-in -> `probe/unc_measure_with_nethood_plugin.txt`
- [x] T005 Audit of the plug-in by a separate agent; decision recorded in `research.md` R2
- [x] T006 Start `specs/125-unc-server-shares/fix-log.md`

## Phase 3: User Story 1 - from a server name to its shares (P1)

**Independent test**: probe rows L* (the list) and P* (picking), saltests `TestUncServer125`.

- [x] T007 [P] [US1] `src/common/saluncserver.h`: `SalUncServerOfPath`, `SalUncShareOffered`, `SalUncShareHidden`, `SalUncShareCompare`, `SalUncBuildSharePath`, `SalUncMenuText`
- [x] T008 [P] [US1] `src/saltests/saltests.cpp`: `TestUncServer125` (server-only paths, offered kinds, hidden, order, path building incl. refusal, `&` doubling)
- [x] T009 [US1] `src/salamand.h` + `src/shares.cpp`: `CUncShare`, `CUncSharesJob` (reference-counted), `StartUncSharesJob`, the worker: `NetShareEnum` level 1 with resume, `WNetOpenEnumW` fallback, Debug-only seam per `contracts/probe-seam.md`
- [x] T010 [US1] `src/fileswnd.h` + `src/fileswnb.cpp`: `CFilesWindow::PickServerShare(const char* serverPath, char* sharePath, int sharePathSize)` - menu under the directory line, outcomes picked / cancelled / error shown / nothing to offer
- [x] T011 [US1] `src/fileswn3.cpp` `CFilesWindow::ChangeDir`: in the incomplete-UNC branch, when no Network plug-in is found and the error is `IDS_SHARENAMEMISSING`, call `PickServerShare` and continue per research R6

## Phase 4: User Story 2 - a server that cannot be read (P1)

**Independent test**: probe rows E* (error), W* (wait window, Esc), N* (nothing to offer).

- [x] T012 [US2] `src/fileswnb.cpp` `PickServerShare`: 400 ms quiet wait, then the safe wait window with `IDS_CHECKINGPATHESC`, Esc abandons the job; an error is shown with `IDS_PATHERRORFORMAT` and `GetErrorText`; a too long built path with `IDS_TOOLONGPATH`

## Phase 5: User Story 3 - a Network plug-in keeps priority (P2)

**Independent test**: the probe on a build with `nethood=on`: `\\localhost\` opens `net:\\localhost`.

- [x] T013 [US3] Verify by code reading and by the probe that the fallback is reached only when `GetFirstNethoodPluginFSName` returns FALSE

## Phase 6: Claims, tests, gates, records

- [x] T014 `PRIVACY.md`: extend the bullet *Network drives and shared folders* (asking a named server for its shared folders)
- [x] T015 Extend `probe/unc_probe.ps1` with `-Expect fixed` rows: L1 list from the seam (order, hidden after visible, IPC and printers absent, non-ASCII), P1 pick with the seam (`C$` on localhost), R1 real enumeration of `\\localhost\` and pick, E1 seam error, E2 real nonexistent host, W1 delay + Esc, N1 only non-folder shares, C1 close request while the menu is open, C2 close while reading
- [x] T016 Builds: `build.cmd` Debug, `build.cmd full release`; saltests all pass; `tools/check_encoding.py` `TOTAL: 0`; Release binary has no `TC_PROBE_UNC` string
- [x] T017 Run the probe: fixed build (`probe/unc_result.txt`), 0.1.9 control, build with the plug-in (US3)
- [x] T018 Independent review by a separate agent (refute-first); fix or record every finding
- [x] T019 Records: `fix-log.md`, `specs/FEATURE-HISTORY.md`, `CHANGELOG.md`, `specs/NEXT-WORK.md` (the plug-in decision), `issues/issue_5_report.md`, `issues/PROGRESS.md`
- [x] T020 Commit on `125-unc-server-shares` (`[125] ...`), nothing pushed

## Dependencies

T007 -> T009 -> T010 -> T011 -> T012; T008 after T007; T015 after T011; T016-T018 after all code.

## Parallel opportunities

T007 and T008 are different files; T014 with any code task.

## Implementation strategy

MVP = US1 + US2 together (asking the network without the wait/cancel half would be a
regression against today's instant answer). US3 is a guard.
