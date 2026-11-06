---
description: "Tasks for 406 - Registry Editor: Move of an HKCR key held by both halves"
---

# Tasks: Registry Editor - Move of an HKCR key held by both halves

**Input**: `specs/406-regedt-hkcr-both-halves/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: requested by the project rules (pure rule in `saltests`, hidden-desktop probe).

## Phase 1: Setup

- [X] T001 Record the measurement before (direct script, probe 6 PASS / 7 FAIL) in specs/406-regedt-hkcr-both-halves/fix-log.md

## Phase 2: Foundational (pure rule)

- [X] T002 Add `SAL_HKCR_DELETE_BOTH` (appended), make `SalRegHkcrDeleteHalf(TRUE, TRUE)` return it, add `SalRegValueSame` and update the header comment in src/common/salregkeyid.h
- [X] T003 Update `TestRegHkcrHalf390` (both = BOTH) and add `TestRegHkcrBoth406` (value comparison: equal, other type, other size, other byte, NULL with size 0, empty vs absent) in src/saltests/saltests.cpp, registered in the test list
- [X] T004 Negative control: with the old "both = VIEW" rule the new checks fail (recorded in fix-log.md)

## Phase 3: User Story 1 + 2 - both halves removed, a hidden machine value never deleted (P1)

**Goal**: a Move of a both-halves key deletes the machine's half (after the "copied" check) and then the user's half by their real paths; every failure in the existing box.
**Independent Test**: probe rows BOTHMOVE, BOTHSKIP, BOTHSHADOW.

- [X] T005 [US1] Add `HkcrMachineHalfCopied` (class names and values of both halves, fails closed) in src/plugins/regedt/fs5.cpp
- [X] T006 [US1] Give `SafeDeleteHkcrHalf` a `checkCopied` parameter (check -> `ERROR_NOT_SUPPORTED` when not copied, read error shown, Retry checks again) in src/plugins/regedt/fs5.cpp
- [X] T007 [US1] In `CopyOrMoveKeyRec`, `SAL_HKCR_DELETE_BOTH` = machine half (checked), then user half; update the 390 comments in src/plugins/regedt/fs5.cpp
- [X] T008 [US1] Build (`.\build.cmd`), saltests, probe specs/406-regedt-hkcr-both-halves/probe/hkcr406_probe.ps1 English and Czech -> all PASS

## Phase 4: User Story 3 - nothing else changes (P2)

- [X] T009 [US3] Run the probes of 390, 292, 294, 296, 297 on the new build; results into specs/406-regedt-hkcr-both-halves/probe/

## Phase 5: Polish

- [X] T010 `python tools/check_encoding.py --strict` -> TOTAL: 0; fix-log.md complete (before / after, commands)
- [ ] T011 Release checklist line for the elevated Move (owed to a person), closing report, FEATURE-HISTORY, CHANGELOG (SKILL.md step 8)

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008 -> T009 -> T010 -> T011. US1 and US2
share one code path (the end of `CopyOrMoveKeyRec`), so they are one phase. No parallel tasks: two
files depend on the header.

## Implementation strategy

MVP = Phase 3 (the item). Phase 4 guards the callers; Phase 5 closes the item.
