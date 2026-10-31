# Tasks: A damaged CloneCD .ccd never makes the ISO plug-in write or read outside its tables

**Input**: Design documents from `specs/352-uniso-ccd-session-bounds/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: the spec requires `saltests` checks of the rule (FR-007, SC-004) and the probe (SC-001..003).

## Phase 1: Setup

- [ ] T001 Start `specs/352-uniso-ccd-session-bounds/fix-log.md` with the measurement at 2f260c23 (probe `probe/result_before_debug.txt`, 8 / 10) and the decisions of research.md

## Phase 2: Foundational (the pure rule)

- [ ] T002 Add `SalIsoCcdReadInt`, `CSalIsoCcdFields`, `SalIsoCcdSessionIndex`, `SalIsoCcdSplitSection`, `SalIsoCcdLayoutTrusted` to `src/common/salisotrack.h` (header-only, no CRT; feature-352 comment block)
- [ ] T003 Add `TestIsoCcdBounds_352` to `src/saltests/saltests.cpp` and call it from the test list (decimal / hex / sign / blanks / trailing text / no number / empty / NULL / 32-bit overflow; fields once / twice / not parsed / missing; session 0, 1, sections, sections + 1, 200, 257, negative; split rows; layout agreement)

## Phase 3: User Story 1 - a damaged .ccd is refused, the image kept (P1)

**Independent test**: probe rows R-S0, R-S200, R-S257, R-MODEX, R-DUP.

- [ ] T004 [US1] In `src/plugins/uniso/img.cpp`: `processTrackSection`, `processEntrySection`, `processSessionSection` read their rows with `SalIsoCcdReadInt` and `CSalIsoCcdFields` (each needed row once and parsed, else the section is refused); `CCDEntry::Session` becomes `int`
- [ ] T005 [US1] In `src/plugins/uniso/img.cpp`: `CCD::Refused`, set by `processCCDFile` where it reports `IDS_CCD_BAD_FORMAT`, and by `ReadSessionCCD` for an empty table and for an entry whose session `SalIsoCcdSessionIndex` rejects (checked for all entries before anything is built); at the end of `ReadSessionCCD` a refused `.ccd` marks `ListingLeftOut` incomplete (a missing `.ccd` does not)

## Phase 4: User Story 2 - sections and splits that disagree (P1)

**Independent test**: probe rows R-ABS, R-SPLIT.

- [ ] T006 [US2] In `CISOImage::ReadSessionCCD` (`src/plugins/uniso/img.cpp`): the sector-format loop runs over the split list (`Session.Count`), the extents loop takes a split's row by `SalIsoCcdSplitSection` (none -> 0), the entry loop indexes by `SalIsoCcdSessionIndex`; `SalIsoCcdLayoutTrusted` false -> `ListingLeftOut.SetIncomplete()` with a `TRACE_I`

## Phase 5: User Story 3 - valid images unchanged (P1)

- [ ] T007 [US3] Build (`.\build.cmd`), run `saltests`, run `probe/iso352_probe.ps1` on the hidden desktop -> 18 / 0 (`probe/result_after_debug.txt`); run 351's probe (10 / 0) and 334's probe (as recorded) -> `probe/regress_351.txt`, `probe/regress_334.txt`
- [ ] T008 [US3] Negative controls: a mutant of the rule (session range without the upper bound) fails `saltests`; record in fix-log.md

## Phase 6: Polish

- [ ] T009 `python tools/check_encoding.py --strict` -> TOTAL: 0; clang-format only the changed lines
- [ ] T010 Complete `fix-log.md` (before / after, commands, results)

## Dependencies

T001 -> T002 -> T003; T002 -> T004 -> T005 -> T006 -> T007 -> T008 -> T009 -> T010. US1 and US2 touch the same function: sequential.

## Implementation strategy

One small change set; MVP = US1 + US2 together (the same reader), US3 is the regression gate.
