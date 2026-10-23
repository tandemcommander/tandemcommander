# Tasks: Pack refuses an archive name the file system would not keep as typed

**Input**: Design documents from `specs/318-pack-name-trailing-dot/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: the item asks for "a probe row per case, before FAIL / after PASS"; the pure rule gets
saltests checks (project rule). Probe and unit tasks are included.

## Phase 1: Setup

- [X] T001 Start `specs/318-pack-name-trailing-dot/fix-log.md` with the measurement at efb9b0ad (the scratch probe command, 12 FAIL / 30 PASS, which names were not openable through a plain path) and the decisions of research.md R1-R4

## Phase 2: Foundational

- [X] T002 Put the measurement probe into `specs/318-pack-name-trailing-dot/probe/pack318_probe.ps1` (unchanged rows: 13 refusal rows incl. space-dots, 8 control rows) and its before-result into `specs/318-pack-name-trailing-dot/probe/result_before.txt` (the negative control: the 12 new refusal rows FAIL, space-dots and the controls PASS)

## Phase 3: User Story 1 - A trailing dot or space is refused (Priority: P1) MVP

**Goal**: OK on a name whose last part ends with `.` or ` ` shows "The path specified is invalid."
and the dialog again; nothing written.
**Independent Test**: probe rows trail-dot, trail-dots, trail-space, trail-dot-space, abs-trail-dot PASS.

- [X] T003 [US1] In `src/common/salpackname.h` replace `SalPackNameIsOnlyDotsAndSpaces` with `SalPackNameIsNotKeptAsTyped(const char* fullName)`: the last part (after the last `\`) not empty and ending with `.` or ` `, or a reserved device name (research R2); header comment updated for feature 318
- [X] T004 [US1] In `src/saltests/saltests.cpp` replace `TestPackName317` with `TestPackName318`: 317's checks carried over (the `\t..` case now TRUE, research R3) plus trailing dot / dots / space / dot-space, absolute and relative, device names (CON, prn, Aux, NUL, COM0, COM1, LPT9, superscript 1/2/3, with extension, with two extensions, with spaces before the dot, alone) and near misses (CONSOLE.zip, con bla.zip, COM10.zip, LPT.zip, COM.zip, ` CON.zip`, `report.v1.zip`, `.cfg.zip`, a device name only in a folder part, a superscript four `C2 B4`, a trailing tab); update the call in the test list
- [X] T005 [US1] In `src/fileswn7.cpp` `CFilesWindow::Pack` call `SalPackNameIsNotKeptAsTyped(fileBuf)` instead of `SalPackNameIsOnlyDotsAndSpaces(fileBuf)` (same error path `IDS_PATHISINVALID`), comment extended for feature 318
- [X] T006 [US1] Build Debug x64 (`.\build.cmd`) - `BUILD SUCCEEDED`; `saltests.exe` - `0 failed`

## Phase 4: User Story 2 - A reserved device name is refused (Priority: P2)

**Goal**: `CON.zip`, `con`, `NUL .zip`, `COM1.zip`, `lpt9.tar.zip`, `COM<sup1>.zip`, `<src>\prn.zip` refused.
**Independent Test**: the dev-* and abs-dev probe rows PASS (same rule as T003).

- [X] T007 [US2] Run the probe on the new build into `specs/318-pack-name-trailing-dot/probe/result_after.txt` - every row PASS, registry restored and identical

## Phase 5: User Story 3 - Everything else unchanged (Priority: P3)

**Independent Test**: control rows PASS before and after; 317's probe unchanged.

- [X] T008 [US3] Run 317's probe `specs/317-pack-name-space/probe/pack317_probe.ps1` on the new build into `specs/318-pack-name-trailing-dot/probe/regress_317.txt` - 28 PASS / 0 FAIL

## Phase 6: Polish

- [X] T009 [P] `python tools/check_encoding.py --strict` - `TOTAL: 0 finding(s)`
- [X] T010 [P] clang-format check of the changed lines in `src/common/salpackname.h`, `src/saltests/saltests.cpp`, `src/fileswn7.cpp`
- [X] T011 Record before / after, the commands and their results in `specs/318-pack-name-trailing-dot/fix-log.md`; record out-of-scope findings and whether they go to the Inbox

## Phase 7: Review fix (review of 318, SHOULD 1 / NOTE 2)

- [X] T012 Probe rows slash-dev, slash-dev-sub, trail-dot-plain, exist-aux, exist-trail-dot in `specs/318-pack-name-trailing-dot/probe/pack318_probe.ps1`; run on the first-fix build into `probe/result_fix1.txt` (the control: 4 FAIL)
- [X] T013 `src/common/salpackname.h`: the last part starts after the last `\` or `/`; `src/fileswn7.cpp`: refuse only when `!FileExists(fileBuf)`; `src/saltests/saltests.cpp`: 5 checks for `/`
- [X] T014 Build, saltests, the whole probe into `probe/result_after.txt`, 317's probe into `probe/regress_317.txt`, the encoding guard and clang-format again

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008 -> T009, T010 -> T011. US2 and US3
are verified by the same change as US1 (one rule, one call site).

## Parallel Execution

T009 and T010 can run together; the probes (T007, T008) run one after the other (they share the
registry key).

## Implementation Strategy

MVP = US1 (T003-T005); the device-name part of the same rule serves US2; US3 is verification.
