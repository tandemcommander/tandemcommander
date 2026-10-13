# Tasks: Registry Editor - wide inserts (feature 129)

**Input**: `specs/129-regedt-wide-inserts/` - spec.md, plan.md, research.md, quickstart.md
**Tests**: requested (unit checks and an independent GUI probe).

## Phase 1: Setup

- [x] T001 Write `probe/wide_probe.ps1` (fixture keys with accented names and an ASCII pair; rows OPENKEY, VIEWA, VIEW, VIEWSEQ, CREATE, SELF)

## Phase 2: Foundational (measure first)

- [x] T002 Run the probe on the build before the change and on 0.1.9 -> `probe/wide_result_before_v019.txt` (4 FAIL)
- [x] T003 Start `fix-log.md`
- [x] T004 [P] `src/common/salwideinserts.h`: `SalWideInsertsUsed`, `SalWideInsertsCount`, `SalWideInsertsExpandTo`, `SalWideInsertsExpandAlloc`
- [x] T005 [P] `src/saltests/saltests.cpp`: `TestWideInserts129`
- [x] T006 `src/plugins/regedt/regedt.h`, `regedt.cpp`, `precomp.h`: `FormatWideU8` (template or id)

## Phase 3: User Story 1 - a question about a key names the key (P1)

- [x] T007 [US1] `src/plugins/regedt/fs5.cpp`: the create-target question through `FormatWideU8`; no text -> not asked, nothing created
- [x] T008 [US1] `src/plugins/regedt/fs5.cpp`: the "can't copy / move a key to itself" message; no text -> the copy fails
- [x] T009 [US1] `src/plugins/regedt/fs5.cpp`: the key's name in the "class name differs" question

## Phase 4: User Story 2 - an error names the whole key (P2)

- [x] T010 [US2] `src/plugins/regedt/regedt.cpp`: `ErrorHelper` sends a template with `%ls` to `ErrorHelperWide` (template by id as UTF-8, wide inserts, `FormatMessageW`); the wrappers pass the id

## Phase 5: User Story 3 - a viewed value has its own copy (P2)

- [x] T011 [US3] `src/plugins/regedt/fs3.cpp` `ViewFile`: the unique cache name composed as UTF-8 on the heap, freed on both exits

## Phase 6: Tests, gates, records

- [x] T012 Builds (Debug, Release), saltests, `tools/check_encoding.py`
- [x] T013 Probe on the fixed build, Czech and English -> `probe/wide_result_czech.txt`, `probe/wide_result_english.txt`
- [x] T014 Regression: the probes of 124 and 127 (the same plug-in) on the fixed build
- [x] T015 Independent review (refute-first)
- [x] T016 Records: `fix-log.md`, FEATURE-HISTORY, CHANGELOG, NEXT-WORK
- [x] T017 Commit on `129-regedt-wide-inserts`, nothing pushed

## Dependencies

T004 -> T006 -> T007-T011; T005 with T004; T012-T015 after the code.
