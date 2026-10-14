# Tasks: Disk Map closes safely while one of its loops is open

**Input**: `specs/143-diskmap-release-guard/` (spec, plan, research, data-model, contracts, quickstart)
**Tests**: the spec asks for them (saltests for the rule, the GUI probe on the hidden desktop).

## Phase 1: Setup

- [x] T001 Keep the build before the feature as `build/tandemcommander/Debug_x64_pre143` (copy of `Debug_x64` at `8e5d6c8a`)
- [x] T002 Write the probe `specs/143-diskmap-release-guard/probe/release_guard_probe.ps1` (rows E0-E6, M1-M3, U1-U4)
- [x] T003 Run it on `Debug_x64_pre143` with `-Expect before`; keep `specs/143-diskmap-release-guard/probe/result_pre143.txt` (E1, E4, U1 crash)
- [x] T004 Start `specs/143-diskmap-release-guard/fix-log.md` with the measurement

## Phase 2: Foundational

- [x] T005 Write the rule `src/common/salloopclose.h` (`CSalLoopCloseState`, `SalLoopEnter`, `SalLoopLeave`, `SalLoopCloseRequest`; header-only, no globals) per `data-model.md`
- [x] T006 Add `TestLoopClose143` to `src/saltests/saltests.cpp` (include, function, call in `main`): no loop -> destroy; menu -> pending + end menu; own box -> pending + cancel; shell -> pending only; box inside shell -> no cancel; nested enter/leave; leave with pending -> close now once; leave without -> declare again; counters never below 0; double request -> one close

## Phase 3: User Story 1 - normal exit never crashes (P1)

**Goal**: E1-E4 end cleanly. **Independent test**: probe rows E0-E4.

- [x] T007 [US1] `src/plugins/diskmap/DiskMap/GUI.MainWindow.h`: a `CSalLoopCloseState` member, an RAII guard `CMapLoopScope` (enter/leave with the window's state and handle), `OnClose()` applying `SalLoopCloseRequest` (`EndMenu`, `IDCANCEL` to the thread's enabled dialogs owned by the map), the About command and the Esc confirmation inside an own-box scope; give `CShellMenu` the state pointer in `OnCreate`
- [x] T008 [US1] `src/plugins/diskmap/DiskMap/GUI.MainWindow.cpp`: `case WM_CLOSE` -> `OnClose()`; the guard's leave posts `WM_CLOSE` when the rule says "close now"
- [x] T009 [US1] `src/plugins/diskmap/DiskMap/GUI.ShellMenu.h`: menu scope around both `TrackPopupMenuEx`, shell scope around the three `InvokeCommand` calls; a setter for the loop owner
- [x] T010 [US1] Build Debug (`build.cmd`), `saltests`, `tools/check_encoding.py`
- [x] T011 [US1] Probe rows E0-E4 on `Debug_x64` (`-Expect fixed`)

## Phase 4: User Story 2 - installer's close declines inside a loop (P2)

**Goal**: U1-U4 decline. **Independent test**: probe rows U1-U4, 118 rows M1-M4, X1.

- [x] T012 [US2] `src/plugins/diskmap/DiskMapPlugin/DiskMapPlugin.cpp`: `DiskMapLoopsOpen` counter, `DiskMapLoopStateChanged(HWND, BOOL inLoop)` (counter + `SetWindowClosesUnattended(hWnd, !inLoop)` in a 107 core only), called by the guard on the first enter / last leave (not re-declared while a close is pending)
- [x] T013 [US2] Same file, `CPluginInterface::Release`: unattended and `DiskMapLoopsOpen > 0` -> `return FALSE` before posting anything
- [x] T014 [US2] Probe rows U1-U4; the 118 probe `-Only M1,M2,M3,M4,X1`

## Phase 5: User Story 3 - closing the map itself unchanged (P3)

- [x] T015 [US3] Probe row E0 and the 118 rows above cover the map's own close routes; File > Exit / Esc-Yes are unchanged code - checked by reading in the review

## Phase 6: Polish

- [x] T016 Independent refute-first review of the diff (agent); fix what it finds
- [x] T017 Full probe on the final build; keep `probe/result.txt`
- [x] T018 Records: `fix-log.md` (results), `specs/FEATURE-HISTORY.md` entry `- 143-...`, `specs/NEXT-WORK.md` (A.1 done, 118 R7 corrected: the menu was not "milliseconds"), `CHANGELOG.md` `[0.1.11] — unreleased`, spec status
- [x] T019 Commit on `143-diskmap-release-guard`

## Dependencies

T001-T003 done -> T004-T006 -> US1 (T007-T011) -> US2 (T012-T014, needs the guard of T007) -> US3 -> Polish.
T005/T006 and T004 can run in parallel; T009 parallel to T007 only after the guard's interface is fixed.

## Implementation strategy

MVP = US1 (no crash on exit). US2 is a few lines on top of the same guard.
