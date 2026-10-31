# Tasks: ISO plug-in - a UDF folder entry without descriptors is unreadable, not empty

**Input**: `specs/362-uniso-udf-folder-no-descs/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: `saltests` checks are required by the spec (FR-006, stop-rules §2.5); the probe is the acceptance test.

## Phase 1: Setup

- [X] T001 Start `specs/362-uniso-udf-folder-no-descs/fix-log.md` with the measurement before the fix (probe `probe/result_before.txt`: PASS 15, FAIL 7 at 5d74e338, the commands, the caller enumeration of research R1)

## Phase 2: Foundational (the rule)

- [X] T002 Add `SalIsoUdfFolderEntryWalkable(int stored)` to `src/common/salisoudfentry.h` (true for `stored > 0` or `-1`; false for 0 and any other negative value), with a comment naming feature 362 and why (a folder always holds its parent identifier)
- [X] T003 Add `TestIsoUdfFolderEntry_362` to `src/saltests/saltests.cpp` (the rule's values 1, 2, 32, -1 true; 0, -2, -3 false; a grid model of the reader's result over L_EA / L_AD / type 0 - 7 built on `SalIsoUdfEntryDescs` checking walkable == accepted and L_AD > 0) and call it from the test list

## Phase 3: User Story 1 + 2 - a damaged sub-folder / root folder is unreadable (P1)

**Goal**: L_AD 0 folder entries (sub-folder, root; short or embedded) take the existing unreadable-folder path.
**Independent Test**: probe rows R-ALAD0, R-AEMB0, R-ZLAD0, R-ROOTLAD0, R-ROOTEMB0, L-ROOTLAD0, L-ROOTEMB0.

- [X] T004 [US1] In `src/plugins/uniso/udf.cpp`, `CUDF::MapICB(CAD, CICBTag*, CAD*)`: replace the test `n == UDF_FE_REFUSED` with `!SalIsoUdfFolderEntryWalkable(n)` → return 0; update its comment (361 refusal + 362 no descriptors) - one change serves US1 (ScanDir) and US2 (ListDirectory)
- [X] T005 [US1] Build (`.\build.cmd`) and run `saltests` → `0 failed`
- [X] T006 [US1] Run `probe/iso362_probe.ps1` on the hidden desktop → `probe/result_after.txt`, every row PASS, registry identical

## Phase 4: User Story 3 - real empty folders and intact images unchanged (P2)

**Independent Test**: control rows L-UE, C-UD, C-UE, C-MKCDR of the same run; probes 330 and 361.

- [X] T007 [P] [US3] Re-run `specs/330-iso-unreadable-folder/probe/iso330_probe.ps1` → `probe/regress_330.txt`, its recorded result
- [X] T008 [P] [US3] Re-run `specs/361-uniso-udf-entry-bound/probe/iso361_probe.ps1` → `probe/regress_361.txt`, 24 / 0

## Phase 5: Polish

- [X] T009 `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`
- [X] T010 Record after-measurements, regressions and checks in `specs/362-uniso-udf-folder-no-descs/fix-log.md`

## Phase 6: Review 1 (SHOULD 1 - a first extent of length 0)

- [X] T011 [US1] Extend the rule to `SalIsoUdfFolderEntryWalkable(int stored, unsigned long long firstLen)` in `src/common/salisoudfentry.h` and call it in `src/plugins/uniso/udf.cpp` `MapICB` with `file->Length` (a refused entry is not read); extend `TestIsoUdfFolderEntry_362` in `src/saltests/saltests.cpp` with first-extent lengths
- [X] T012 [US1] Add kinds `alen0` / `rootlen0` to `probe/img362.py` and rows L-ROOTLEN0, R-ALEN0, R-ROOTLEN0 to `probe/iso362_probe.ps1`; measure them on the first-fix build (`probe/result_before_review1.txt`) and on the final build (`probe/result_after_review1.txt`)
- [X] T013 [US3] Re-run probes 330 and 361 (`probe/regress_330.txt`, `probe/regress_361.txt`) and `saltests`

## Phase 7: Review 2 (SHOULD 1 - a first extent shorter than an identifier)

- [X] T014 [US1] Threshold `SAL_ISO_UDF_MIN_FID` (38) in `src/common/salisoudfentry.h`; `TestIsoUdfFolderEntry_362` in `src/saltests/saltests.cpp` with lengths 20, 37, 38, 40
- [X] T015 [US1] Kinds `alen20` / `rootlen20` in `probe/img362.py`, rows L-ROOTLEN20, R-ALEN20, R-ROOTLEN20 in `probe/iso362_probe.ps1`; before on the review-1 build (`probe/result_before_review2.txt`), after (`probe/result_after_review2.txt`)
- [X] T016 [US3] Regressions 330, 361 and 356 (`probe/regress_330.txt`, `probe/regress_361.txt`, `probe/regress_356.txt`)

## Dependencies

T001 → T002 → T003 → T004 → T005 → T006 → (T007 ∥ T008) → T009 → T010. US1 and US2 share the single change T004.

## Parallel opportunities

T007 and T008 touch different probes (but probes run one at a time on the hidden desktop - run sequentially).

## Implementation strategy

MVP = T002 - T006 (the whole fix); T007 - T010 confirm no regression.
