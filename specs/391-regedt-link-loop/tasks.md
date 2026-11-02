# Tasks: Registry Editor - Copy and Find never loop through a registry link

**Input**: Design documents from `specs/391-regedt-link-loop/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

Tests: the feature's probe and `saltests` checks are required by the project rules (CLAUDE.md
*Working method*), so they are listed.

## Phase 1: Setup

- [ ] T001 Record the before measurement and the design in specs/391-regedt-link-loop/fix-log.md (probe results specs/391-regedt-link-loop/probe/loop391_before.txt, loop391_before_find.txt)

## Phase 2: Foundational (blocking)

- [ ] T002 Add the pure rule `SalRegKeyIdLeadsBack(chain, count, id)` with its header comment to src/common/salregkeyid.h
- [ ] T003 Add saltests checks of `SalRegKeyIdLeadsBack` (self, ancestor, root, sibling, child, case, whole element, empty id / entries, count 0) to src/saltests/saltests.cpp
- [ ] T004 Add `CRegWalkChain` (heap identities, Count, PopTo, guard) and the declarations of `RegWalkEnterTop` / `RegWalkEnter` to src/plugins/regedt/regedt.h
- [ ] T005 Implement `RegWalkEnterTop` (best effort: `GetRegKeyIds` + the opened handle's identity) and `RegWalkEnter` (opened identity, leads-back test, push) in src/plugins/regedt/fs5.cpp

## Phase 3: User Story 1 - Copy refuses a key that leads back (P1)

**Goal**: Copy writes each key once; a looping link is refused with the existing box.
**Independent test**: probe rows COPYSELF, COPYCANCEL, COPYANC, COPYCYCLE.

- [ ] T006 [US1] Move 296's refusal box of `CopyOrMoveKeyRec` into a helper `RefuseCopyIntoItself` in src/plugins/regedt/fs5.cpp (same text, same buttons)
- [ ] T007 [US1] Give the operation (`CRegCopyTop`, created in `CopyOrMoveKey`) a walk chain and, in `CopyOrMoveKeyRec` right after the source key is opened, enter it (top or below; error -> `RegOperationError(IDS_OPEN)`, Retry repeats; leads back -> close, `RefuseCopyIntoItself`), popping the level on every return, in src/plugins/regedt/fs5.cpp

## Phase 4: User Story 2 - Find skips a key that leads back (P2)

**Goal**: Find lists each key once, no box.
**Independent test**: probe rows FINDSELF, FINDANC, FINDCYCLE.

- [ ] T008 [US2] Add a `CRegWalkChain&` parameter to `CFindThread::ScanKeyAux` in src/plugins/regedt/finddlg.h
- [ ] T009 [US2] Create the chain in `ScanKey` and, in `ScanKeyAux` after the key is opened, enter it (error -> `RegOperationError(IDS_OPEN, IDS_SEARCHERROR)`; leads back -> close, return TRUE without searching), popping the level on every return, in src/plugins/regedt/finddlg.cpp

## Phase 5: User Story 3 - A link elsewhere stays followed (P1)

- [ ] T010 [US3] Verify the control rows COPYELSE and FINDELSE of specs/391-regedt-link-loop/probe/loop391_probe.ps1 pass unchanged (no code beyond US1 / US2)

## Phase 6: Polish & verification

- [ ] T011 Run `python tools/check_encoding.py --strict` (TOTAL: 0) and `.\build.cmd` (BUILD SUCCEEDED); check that `git diff main -- src/plugins/regedt/lang src/plugins/regedt/regedt.rh2` is empty (FR-006: no new UI text)
- [ ] T012 Run saltests (0 failed) and record the count in specs/391-regedt-link-loop/fix-log.md
- [ ] T013 Run the probe specs/391-regedt-link-loop/probe/loop391_probe.ps1 after the fix, English and Czech (results loop391_after*.txt), every row PASS
- [ ] T014 Negative control: the leads-back test forced off in a copy of the sources (or the probe on the old build) fails the looping rows; record in specs/391-regedt-link-loop/fix-log.md
- [ ] T015 Regression probes of 292, 294, 296, 297, 390 (specs/2*/probe, specs/390-regedt-hkcr-move-user/probe) - all PASS; record in specs/391-regedt-link-loop/fix-log.md

## Dependencies

T001 -> T002 -> T003; T002 -> T004 -> T005 -> (T006 -> T007) and (T008 -> T009) -> T010 -> T011 -> T012..T015.
US1 and US2 share only the foundational chain; either can be done first.

## Parallel opportunities

T003 [tests] and T004 touch different files once T002 is done; T008/T009 (finddlg) and T006/T007 (fs5)
touch different files once T005 is done.

## Implementation strategy

MVP = US1 (Copy writes dozens of keys); then US2; US3 is the control that nothing else changed.
