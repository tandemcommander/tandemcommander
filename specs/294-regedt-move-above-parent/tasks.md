# Tasks: Registry Editor - Copy / Move of a key into the key above its parent

**Input**: Design documents from `specs/294-regedt-move-above-parent/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/key-below.md, quickstart.md

**Tests**: `saltests` checks for the pure rule (FR-006) and the hidden-desktop probe
`probe/above294_probe.ps1` (written and run as the negative control before the feature).

## Phase 1: Setup

- [X] T001 Start `specs/294-regedt-move-above-parent/fix-log.md` with the measurement at e752f9b9 (probe `-Expect before`: 14 PASS / 10 FAIL, `probe/above294_before.txt`, `probe/result_before.txt`) and the cause traced in `src/plugins/regedt/fs5.cpp`

## Phase 2: Foundational (blocking)

- [X] T002 Add `SalRegKeyIdBelow(key, outer)` (contract `contracts/key-below.md`) to `src/common/salregkeyid.h`, with its line in the header comment
- [X] T003 Add `TestRegKeyIdBelow294` to `src/saltests/saltests.cpp` (strictly inside -> remainder; equal, not inside, partial element `Key2` vs `Key`, empty / NULL, case ignored, trailing-element only; consistency with `SalRegKeyIdWithin` / `SalRegKeyIdSame`) and call it beside `TestRegKeyId292`
- [X] T004 Negative control: run `saltests` with `SalRegKeyIdBelow` returning the remainder also for equal identities (or without the whole-element test) and record that checks fail; restore

## Phase 3: User Story 1 - Move into the key above the parent loses nothing (P1)

**Goal**: F6 of a key into the key holding its parent, with the repeated chain, is refused before anything is written.
**Independent test**: probe rows ABOVEMOVE, ABOVEALIAS, ABOVEDEEP, ABOVEOK.

- [X] T005 [US1] Add `SafeRegKeyHoldsPath(root, key, below, holds, errorTitle, skip, skipAll)` in `src/plugins/regedt/fs5.cpp` beside `SafeGetRegKeyIds`: heap-joined `key\below` (never cut), `RegOpenKeyExW(KEY_READ)`, not found -> FALSE holds, success -> TRUE holds, other errors -> `RegOperationError(IDS_OPEN)` loop (box names the joined path when shorter than `MAX_KEYNAME`, else the source key); allocation failure -> `Error(IDS_LOWMEM)`, does not go on
- [X] T006 [US1] In `CPluginFSInterface::CopyOrMoveFromFS` (`src/plugins/regedt/fs5.cpp`), after 292's `into = SalRegKeyIdsAnyWithin(targetIds, sourceIds)`, when still not `into`: for every pair with `SalRegKeyIdBelow(sourceIds.Id[i], targetIds.Id[j])` non-NULL call `SafeRegKeyHoldsPath`; holds -> `into = TRUE` (existing refusal box follows); Skip -> the key is left alone; Cancel -> `success = FALSE`
- [X] T007 [US1] Build (`build.cmd`), run `saltests`, then the probe on the hidden desktop (quickstart step 2) -> ABOVEMOVE / ABOVEALIAS / ABOVEDEEP / ABOVEOK PASS; record in `fix-log.md`

## Phase 4: User Story 2 - The same Copy is refused (P2)

**Goal**: F5 of the same is refused, the source not written.
**Independent test**: probe row ABOVECOPY.

- [X] T008 [US2] Confirm from the probe run of T007 that ABOVECOPY passes (the check of T006 is shared by Copy and Move); record in `specs/294-regedt-move-above-parent/fix-log.md`

## Phase 5: User Story 3 - Legitimate operations keep working (P3)

**Goal**: merge without the repeated chain, move to another key, refusals of before unchanged.
**Independent test**: probe rows FLATTEN, FLATCOPY, MOVE, MOVESELF; 292's probe.

- [X] T009 [US3] Confirm FLATTEN, FLATCOPY, MOVE, MOVESELF PASS in the T007 run; run `specs/292-regedt-alias-move-self/probe/alias292_probe.ps1` on the new build -> all rows PASS; record in `specs/294-regedt-move-above-parent/fix-log.md`

## Phase 6: Polish

- [X] T010 Run the probe with `-Lang czech` -> all rows PASS; record in `specs/294-regedt-move-above-parent/fix-log.md`
- [X] T011 Encoding guard `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; record the final check numbers in `specs/294-regedt-move-above-parent/fix-log.md`

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008, T009 -> T010 -> T011.
US2 and US3 need no code of their own; they are verified on the US1 build.

## Parallel execution

T003 and T005 touch different files and may be written in parallel once T002 exists; the probes
run one at a time (they share the product's registry key).

## Implementation strategy

MVP = US1 (the data loss); US2 and US3 are proven by the same build and probe run.
