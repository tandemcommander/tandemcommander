# Tasks: Registry Editor - Move of a key and the "class name differs" question

**Input**: `specs/287-regedt-move-class-name/` (spec.md, plan.md, research.md, data-model.md,
contracts/probe-rows.md, quickstart.md)
**Tests**: the spec asks for a hidden-desktop probe (FR-006) - it is the test of both stories.

## Phase 1: Setup

- [ ] T001 Start the running log `specs/287-regedt-move-class-name/fix-log.md` with the measurement at 243174e4 (fs3.cpp size fixed by 131; the class-name check queries the source key twice; Move not driven)

## Phase 2: Foundational (the probe, blocking both stories)

- [ ] T002 Write `specs/287-regedt-move-class-name/probe/move287_probe.ps1` in the style of `specs/129-regedt-wide-inserts/probe/wide_probe.ps1` (helpers of `specs/098-long-path-overruns/probe/fix_probe_lib.ps1`, registry backup / restore / SHA-256, `-Expect fixed|before`, `-Lang`, `-Only`, `-OutFile`): fixture of `data-model.md` with class names set by P/Invoke `RegCreateKeyExW`, class names read by `RegQueryInfoKeyW`; the rows of `contracts/probe-rows.md`
- [ ] T003 Run the probe on the build before the fix (Czech, `-Expect before`) through `tools/run_on_hidden_desktop.ps1`; result into `specs/287-regedt-move-class-name/probe/move287_before_czech.txt`; record in fix-log (the CLASSCOPY / CLASSMOVE / CLASSYES rows must FAIL, the others PASS)

## Phase 3: User Story 1 - warned before a key's class name is lost (P1)

**Goal**: the question appears when the target's class name differs; Cancel copies and deletes nothing.
**Independent test**: probe rows CLASSCOPY, CLASSMOVE, CLASSYES, CLASSSAME, CLASSNEW.

- [ ] T004 [US1] In `CopyOrMoveKey` of `src/plugins/regedt/fs5.cpp` read the target's class name with `SafeQueryInfoKey(targetHKey, targetRoot, target, targetClassName, ...)` and a comment naming feature 287
- [ ] T005 [US1] Build (`.\build.cmd`), run the probe rows CLASS* in Czech and English; results in `specs/287-regedt-move-class-name/probe/`

## Phase 4: User Story 2 - Move of a key with a Czech name (P2)

**Goal**: Move of a Czech-named key and the move-into-itself message are driven.
**Independent test**: probe rows MOVE, MOVESELF.

- [ ] T006 [US2] Run the probe rows MOVE and MOVESELF in Czech and English (part of the full runs of T007)

## Phase 5: Polish

- [ ] T007 Full probe runs on the fixed build: `-Lang czech` and `-Lang english` -> `move287_after_czech.txt`, `move287_after_english.txt`, every row PASS
- [ ] T008 Regression: `specs/129-regedt-wide-inserts/probe/wide_probe.ps1` on the fixed build (PASS 19, FAIL 0)
- [ ] T009 `python tools/check_encoding.py --strict` (TOTAL: 0) and `saltests` (0 failed) as controls; record all numbers in fix-log
- [ ] T010 `CHANGELOG.md`: an entry at the top of the `— unreleased` section (bold symptom, feature 287, the limits) - or, without such a section, the text in `closing-report.md`

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006/T007 -> T008 -> T009. The negative control (T003)
must run before the fix (T004). US2 does not depend on US1's code, only on the probe.

## Implementation strategy

MVP = US1 (the only code change). US2 is a probe-only story.
