# Tasks: A multi-session image opened through another plain layout is kept after a partial unpack

**Input**: `specs/357-uniso-other-layouts/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: requested by the spec (FR-004 unit checks; SC-001 / SC-002 probe rows).

## Phase 1: Setup

- [ ] T001 Start `specs/357-uniso-other-layouts/fix-log.md` with the measurement before (probe `probe/result_before.txt`: 44 / 16, commands, seeds, the layout table of spec.md)

## Phase 2: Foundational

- [ ] T002 Add the enum `SalIsoPlainLayout` and `SalIsoPlainRawRuleApplies(bool rawStart, bool ccdMissing, int layout)` to `src/common/salisotrack.h` (data-model.md), after 355's `SalIsoRawRestDecision`
- [ ] T003 Add `TestIsoPlainLayouts_357` to `src/saltests/saltests.cpp` (every layout with and without a raw start, with and without a missing `.ccd`, unknown values) and call it after `TestIsoUdfRest_356`

## Phase 3: User Story 1 - a two-session image in another layout is kept (P1)

**Independent test**: probe rows R-*-TWO, R-ECDC/NRG-REST17, -ZERO513, -SHORT keep the image.

- [ ] T004 [US1] In `CISOImage::Open`'s plain branch (`src/plugins/uniso/isoimage.cpp`) record the layout of the check that opened the file in `plainLayout` and change the condition of 355's block from `rawStart && !CcdMissing` to `SalIsoPlainRawRuleApplies(rawStart != FALSE, CcdMissing != FALSE, plainLayout)`; update its comment (feature 357)
- [ ] T005 [US1] `.\build.cmd`, `saltests` 0 failed; run `probe/iso357_probe.ps1` -> `probe/result_after.txt`, all R rows PASS

## Phase 4: User Story 2 - a one-session image still unpacks and is deleted (P2)

**Independent test**: probe rows C-* delete the image.

- [ ] T006 [US2] Check the C rows of `probe/result_after.txt` (14 rows deleted, no window); mutant check: the rule returning false for every non-raw layout gives the before result (record in fix-log)
- [ ] T007 [US2] Regressions: probes of 353, 354, 355, 356 (`specs/35N-*/probe/iso35N_probe.ps1`) -> `probe/regress_35N.txt`, results as recorded by those features

## Phase 5: Polish

- [ ] T008 `python tools/check_encoding.py --strict` -> TOTAL: 0; clang-format only on the changed lines
- [ ] T009 Record after / mutant / regressions in `specs/357-uniso-other-layouts/fix-log.md`

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008 -> T009. No parallel work (one header, one source, one test file; probes share the registry key and must not run at once).

## Implementation strategy

MVP = US1 (T002-T005); US2 is verified by the same probe run and the regressions.
