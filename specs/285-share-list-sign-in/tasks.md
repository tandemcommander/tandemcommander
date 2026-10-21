# Tasks: A server's share list that needs a password offers the sign-in

**Input**: Design documents from `specs/285-share-list-sign-in/` (plan.md, spec.md, research.md,
data-model.md, contracts/sign-in.md, quickstart.md)
**Tests**: `saltests` checks for the pure rules (FR-009) and the hidden-desktop probe (SC-001..003)
are part of the feature.

## Phase 1: Setup

- [ ] T001 Probe `specs/285-share-list-sign-in/probe/signin_probe.ps1` and its baseline `probe/result_before.txt` in the feature folder (measured at eb173f7f, recorded in `fix-log.md`)

## Phase 2: Foundational (blocking)

- [ ] T002 Add the pure rules `SalUncShareListStep` (with `SALUNC_LIST_SHOW` / `_NOTHING` / `_SIGNIN` / `_ERROR`) and `SalUncSignInTarget` to `src/common/saluncserver.h` (header comment list updated, feature 285)
- [ ] T003 [P] Add `TestUncShareListSignIn285` to `src/saltests/saltests.cpp` (every row of data-model.md; refusal of an empty / separator / too-long server, exact fit, UTF-8 name) and call it next to `TestUncShareRoot284`
- [ ] T004 Add `SignInToUncServerW` with the `SIGNIN_CONNECTED` / `SIGNIN_CANCELLED` / `SIGNIN_ERRORSHOWN` results and the Debug-only seam (`TC_PROBE_UNC_SIGNIN`, `_KEEP`, `_LOG`) to `src/drivelst.cpp`; declare it, the results and `IsLogonFailureErr` in `src/consts.h` (contracts/sign-in.md)

## Phase 3: User Story 1 - Signing in opens the share list (P1)

**Goal**: a refused list offers Windows' sign-in once; after it the list appears.
**Independent test**: probe row A1.

- [ ] T005 [US1] Rework `CFilesWindow::PickServerShare` in `src/fileswnb.cpp` into at most two rounds of the 125 list (Esc primed before each round); between them, on `SALUNC_LIST_SIGNIN`, the sign-in to `SalUncSignInTarget(server)` converted with `SalU8ToWAlloc`; map the results to `PSS_*` (data-model.md "Route states"); the list, wait window, menu and messages of 125 unchanged
- [ ] T006 [US1] Build Debug (`.\build.cmd`), run `saltests`, run probe row A1 with `-Expect fixed`

## Phase 4: User Story 2 - The way up signs in the same way (P2)

**Independent test**: probe row A2 (no code beyond T005: the 284 routes call the same `ChangeDir`).

- [ ] T007 [US2] Run probe row A2 with `-Expect fixed`; confirm by reading that the 284 routes (`fileswn1.cpp` GotoRoot, `fileswn2.cpp` Execute of `..`, `fileswn8.cpp` open in other panel) reach `PickServerShare` only through `ChangeDir`

## Phase 5: User Story 3 - Cancel and failures (P3)

**Independent test**: probe rows C1, F1, W1, K1.

- [ ] T008 [US3] Run probe rows C1, F1, W1, K1 and the controls N1, R1 with `-Expect fixed`; store the whole run as `specs/285-share-list-sign-in/probe/result_after.txt`

## Phase 6: Polish & cross-cutting

- [ ] T009 [P] List the three new seam variables in `specs/125-unc-server-shares/contracts/probe-seam.md` (pointer to this feature's contract)
- [ ] T010 Encoding guard `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; a negative control of the probe (a row whose expectation is wrong must FAIL) recorded in `fix-log.md`
- [ ] T011 Release build string check: `TC_PROBE_UNC_SIGNIN` absent from a Release `tandemcommander.exe` - or, when no Release build is made in the run, the `#ifdef _DEBUG` guard checked by reading and recorded
- [ ] T012 `fix-log.md`: before / after, commands, results

## Dependencies

T001 -> T002 -> T003, T004 -> T005 -> T006 -> T007 -> T008 -> T009..T012. US2 and US3 need no code of
their own; they are verified on the code of US1.

## Parallel opportunities

T003 alongside T004 (different files); T009 alongside T010.

## Implementation strategy

MVP = US1 (T001-T006); US2 and US3 are verification of the same change.
