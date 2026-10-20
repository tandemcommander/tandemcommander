# Tasks: Plug-in closing - forced Disk Map unload, stray comparator box

**Input**: `specs/266-close-stray-box/` - spec.md, plan.md, research.md, quickstart.md
**Tests**: no new automated tests (no pure rule; research R2: the comparator timing is NOT
DRIVEN); the 143 probe rows E4-E6 are the regression check of Disk Map.

## Phase 1: Setup

- [ ] T001 Create the running log specs/266-close-stray-box/fix-log.md with the measurement at 5eb288af (research R1-R3)

## Phase 2: Foundational

- [ ] T002 Add `BOOL CloseBegun` and `void BeginClose() { CloseBegun = TRUE; }` to `CFileViewWindow` in src/plugins/filecomp/viewwnd.h and initialise `CloseBegun = FALSE` in the `CFileViewWindow` constructor in src/plugins/filecomp/viewwnd.cpp

## Phase 3: User Story 1 - no stray error box while the comparator closes (P1)

**Goal**: FR-001, FR-002. **Independent test**: code review (NOT DRIVEN, research R2).

- [ ] T003 [US1] In `CMainWindow::WindowProc` `WM_DESTROY` in src/plugins/filecomp/mainwnd.cpp call `BeginClose()` on both existing file views first, before `DestroyData` and the worker wait
- [ ] T004 [US1] In `CHexFileViewWindow::WindowProc` `WM_USER_HANDLEFILEERROR` in src/plugins/filecomp/viewwnd3.cpp return 0 at once when `CloseBegun` (no `DialogError`, no `CM_CLOSEFILES`)

## Phase 4: User Story 2 - a destroyed mapping reports no size (P2)

**Goal**: FR-003. **Independent test**: code review of `Destroy` and its callers (research R3).

- [ ] T005 [P] [US2] Reset `FileSize = 0` in `CFileMapping::Destroy` in src/plugins/filecomp/filemap.cpp

## Phase 5: User Story 3 - forced Disk Map unload keeps its documented behaviour (P3)

**Goal**: FR-004. **Independent test**: 143 probe rows E4-E6 (quickstart step 4).

- [ ] T006 [P] [US3] Document the force path (termination inside a shell command is the core's force semantics; 143 FR-004; why not wait / cancel) at `ThreadQueue.KillAll` in `CPluginInterface::Release` in src/plugins/diskmap/DiskMapPlugin/DiskMapPlugin.cpp

## Phase 6: Polish & verification

- [ ] T007 clang-format the changed sources; encoding guard `python tools/check_encoding.py --strict` -> TOTAL 0
- [ ] T008 Build `.\build.cmd` (PowerShell) -> BUILD SUCCEEDED; saltests -> 0 failed
- [ ] T009 Run the 143 probe rows E4,E5,E6 on the hidden desktop (quickstart step 4) into specs/266-close-stray-box/probe/; record in specs/266-close-stray-box/fix-log.md
- [ ] T010 Record the results, the NOT DRIVEN row and the decision on part (1) in specs/266-close-stray-box/fix-log.md

## Dependencies

T001 -> T002 -> T003 -> T004; T005, T006 independent of US1; T007-T010 after all.

## Parallel opportunities

T005 and T006 (different plug-ins / files) can be done alongside T002-T004.

## Implementation strategy

MVP = US1 (T002-T004); US2 and US3 are one-line / comment changes done in the same pass.
