# Tasks: ISO plug-in - a UDF file identifier that does not fit the folder buffer is refused

**Input**: `specs/363-uniso-udf-fid-bound/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: `saltests` checks are required by the spec (FR-006, stop-rules §2.5); the probe is the acceptance test.

## Phase 1: Setup

- [X] T001 Start `specs/363-uniso-udf-fid-bound/fix-log.md` with the measurement before the fix (`probe/result_before.txt`: PASS 12, FAIL 8 at 443ee778, the commands, the caller enumeration of research R4)

## Phase 2: Foundational (the rule)

- [X] T002 Add `SalIsoUdfFidLength(held, pos, lFI, lIU, len)` to `src/common/salisoudfentry.h` (true with the padded length when `pos <= held` and the padded identifier lies in `[pos, held)`, 64-bit, each part subtracted from what is left so nothing wraps; false with `len` 0), with a comment naming feature 363 and the measured harm
- [X] T003 Add `TestIsoUdfFid_363` to `src/saltests/saltests.cpp` (values at the bound, genisoimage's shapes, the probe's damaged identifiers, wrap values, a grid model of the walk: accepted -> in the buffer and next position at most one sector in after the step; every identifier of at most 2048 bytes at a position of at most 2048 accepted with the old length) and call it from the test list

## Phase 3: User Story 1 + 2 - a damaged identifier is refused at unpack and at listing (P1)

**Goal**: an identifier past the buffer takes the invalid-tag path; nothing is read past the buffer.
**Independent Test**: probe rows R-AIU, R-TIU, R-SIU, R-AIU4K, R-AFI, L-AIU, L-AIU4K, L-AFI.

- [X] T004 [US1] In `src/plugins/uniso/udf.h` / `src/plugins/uniso/udf.cpp`: `CUDF::ReadFileIdentifier(Uint8* sector, unsigned int held, ...)` decides with `SalIsoUdfFidLength(held, 0, fi, iu, len)` and returns 0 without decoding the name when refused; `CUDF::ScanDir` passes `sizeof(directory) - p` and on 0 takes the existing `Error(IDS_UDF_INVALID_TAG_ID); return ERR_CONTINUE;` - one change serves US1 (unpack) and US2 (listing)
- [X] T005 [US1] Build (`.\build.cmd`) and run `saltests` -> `0 failed`
- [X] T006 [US1] Run `probe/iso363_probe.ps1` on the hidden desktop -> `probe/result_after.txt`, every row PASS, registry identical

## Phase 4: User Story 3 - intact images unchanged (P2)

**Independent Test**: control rows L-UD, C-UD of the same run; probes 330, 361, 362.

- [X] T007 [US3] Re-run `specs/330-iso-unreadable-folder/probe/iso330_probe.ps1` -> `probe/regress_330.txt`, 30 / 0
- [X] T008 [US3] Re-run `specs/361-uniso-udf-entry-bound/probe/iso361_probe.ps1` -> `probe/regress_361.txt`, 24 / 0
- [X] T009 [US3] Re-run `specs/362-uniso-udf-folder-no-descs/probe/iso362_probe.ps1` -> `probe/regress_362.txt`, its recorded result

## Phase 5: Polish

- [X] T010 Negative control: the rule without the bound (always true) makes `TestIsoUdfFid_363` fail; record the count in `specs/363-uniso-udf-fid-bound/fix-log.md`, restore
- [X] T011 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [X] T012 Record after-measurements, regressions and checks in `specs/363-uniso-udf-fid-bound/fix-log.md`

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008 -> T009 -> T010 -> T011 -> T012. US1 and US2 share the
single change T004.

## Parallel opportunities

None in practice: probes run one at a time on the hidden desktop; T002 / T003 / T004 build on one another.

## Implementation strategy

MVP = T002 - T006 (the whole fix); T007 - T012 confirm no regression and record.
