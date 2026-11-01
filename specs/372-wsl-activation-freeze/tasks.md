# Tasks: Switching back to the program never waits for a slow panel folder

**Input**: `specs/372-wsl-activation-freeze/` (plan.md, spec.md, research.md, data-model.md,
contracts/background-path-check.md, quickstart.md)

## Phase 1: Setup

- [ ] T001 Add `WM_USER_BKGNDCHECK_DONE` (`WM_APP + 421`) and `IDT_AUTOREFRESHVERIFY` (955) with English comments in src/consts.h (verify both numbers are unused in src/ first)

## Phase 2: Foundational

- [ ] T002 Write the header-only rule `SalBkgndCheckRoute`, `SalNeedsAutoRefreshVerify`, `SalBkgndCheckAction` (contract table) in src/common/salbkgndcheck.h (UTF-8 BOM, SPDX header)
- [ ] T003 [P] Add `TestBkgndPathCheck372` covering every row of the contract table, the route and the verify condition in src/saltests/saltests.cpp (include + call in main)
- [ ] T004 Extract the accessibility test of `ThreadCheckPathFBody` into `BOOL SalTestPathAccessible(const char* path, DWORD* error)` without change of behaviour, and use it there, in src/salamdr5.cpp (declaration in src/consts.h next to `SalCheckPath`)
- [ ] T005 Add the background worker `StartBkgndPathCheck(HWND panel, const char* path, CPanelType type)` (heap data with a heap copy of the path, `CreateThread`, `AddAuxThread`, call-stack/exception wrapper like `ThreadCheckPathF`, `PostMessage(WM_USER_BKGNDCHECK_DONE)`, free on a failed post; returns FALSE when the thread cannot start) in src/salamdr5.cpp
- [ ] T006 Add panel members `BkgndCheckRunning`, `BkgndCheckWanted`, `AutoRefreshVerifyTimerSet` (initialized in the constructor) and methods `RequestBkgndPathCheck(int purpose)`, `OnBkgndPathCheckDone(...)` in src/fileswnd.h / src/fileswn1.cpp (constructor) / src/fileswnb.cpp

## Phase 3: User Story 1 - responsive activation with a WSL folder (P1)

**Goal**: no UI-thread wait caused by a WSL panel folder after activation.
**Independent test**: probe rows WSLROOT, WSLBIG, WSLNEW, WSLDEL.

- [ ] T007 [US1] In `CFilesWindow::Activate` (src/fileswn6.cpp) route a network disk/archive panel (`SalBkgndCheckRoute`) to `RequestBkgndPathCheck(SAL_BKCHK_ACTIVATE)` instead of the synchronous `CheckPath`; kill a pending inactive-refresh timer as the old OK branch did; `needToRefreshIcons = FALSE`; when the worker cannot start, fall back to the old synchronous code
- [ ] T008 [US1] In `ChangePathToDisk` (src/fileswn2.cpp) replace `Sleep(400)` + second `CommonRefresh` by the 400 ms one-shot timer `IDT_AUTOREFRESHVERIFY` on the panel (`SalNeedsAutoRefreshVerify`)
- [ ] T009 [US1] Handle `IDT_AUTOREFRESHVERIFY` (-> `RequestBkgndPathCheck(SAL_BKCHK_VERIFY)`) and `WM_USER_BKGNDCHECK_DONE` (-> `OnBkgndPathCheckDone`: same type + `SalPathEqualOrdinalCI`, `SalBkgndCheckAction`, post `WM_USER_REFRESH_DIR_EX` / `WM_USER_REFRESH_DIR` with a fresh `MyTimeCounter` value, or restart) in the panel WindowProc in src/fileswnb.cpp
- [ ] T010 [US1] Extend the probe with rows WSLNEW (folder created while inactive is entered after activation) and WSLDEL (deleted folder left within 3 s, the window answering meanwhile) and the SC-001/SC-003 verdicts, fixture under `\\wsl.localhost\<distro>\tmp\tc372act` removed at the end, in specs/372-wsl-activation-freeze/probe/act372_probe.ps1

## Phase 4: User Story 2 - other network folders (P2)

- [ ] T011 [US2] Probe row SHARE on `\\localhost\<share>` of a local fixture when a share is available (else NOT DRIVEN, recorded) in specs/372-wsl-activation-freeze/probe/act372_probe.ps1

## Phase 5: User Story 3 - local folders unchanged (P3)

- [ ] T012 [US3] LOCAL row verdict: longest wait not longer than before (140 ms + 20 ms tolerance) in specs/372-wsl-activation-freeze/probe/act372_probe.ps1

## Phase 6: Polish & checks

- [ ] T013 Encoding guard `python tools/check_encoding.py --strict` -> TOTAL: 0
- [ ] T014 `build.cmd` -> BUILD SUCCEEDED; saltests -> 0 failed
- [ ] T015 Probe after the fix on the hidden desktop -> result_after.txt; repeat the before-measurement as a negative control on the `main` build if needed; record in specs/372-wsl-activation-freeze/fix-log.md
- [ ] T016 Inbox item for the common ~150 ms idle clipboard check (measure:372); person-step item for the visual cursor check and the cold-distribution check

## Dependencies

T001 -> T002 -> T003; T004 -> T005 -> T006 -> T007, T008 -> T009 -> T010-T012 -> T013-T016.
T003 is parallel to T004-T006.

## Implementation strategy

US1 is the MVP and carries nearly all code; US2/US3 are verification rows of the same mechanism.
