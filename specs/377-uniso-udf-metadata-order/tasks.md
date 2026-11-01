# Tasks: A UDF 2.50 image whose volume descriptor precedes its partition descriptor lists and unpacks

**Input**: `specs/377-uniso-udf-metadata-order/` (plan.md, spec.md, research.md, data-model.md, quickstart.md)

## Phase 1: Setup

- [X] T001 Start the running log with the step-3 measurement (iso356 N-U250 before, layout dump) in specs/377-uniso-udf-metadata-order/fix-log.md

## Phase 2: Foundational (probe before the fix)

- [X] T002 Write the image helper (modes `swap`: sectors 34/35 exchanged with tag locations and checksums fixed; `metafar`: metadata file location past the image) in specs/377-uniso-udf-metadata-order/probe/img377.py
- [X] T003 Write the probe (rows C-U250, C-U250SUB, C-U250SWAP, C-U201SUB, C-PLAIN, R-U250FAR; style of iso356_probe.ps1, registry backup/restore, fixture under %TEMP%) in specs/377-uniso-udf-metadata-order/probe/iso377_probe.ps1
- [X] T004 Run the probe on the build before the fix on the hidden desktop → specs/377-uniso-udf-metadata-order/probe/result_before.txt (C-U250, C-U250SUB expected FAIL; C-U250SWAP expected PASS - proves the order is the cause)

## Phase 3: User Story 1 - Open and unpack a UDF 2.50 image written by Windows (P1)

**Goal**: the IMAPI2FS UDF 2.50 image lists and unpacks completely.
**Independent test**: probe rows C-U250, C-U250SUB PASS.

- [X] T005 [US1] Add `MetadataFileLocation` to `CPartitionMap` in src/plugins/uniso/udf.h
- [X] T006 [US1] In `CUDF::ReadPartitionMap` record the metadata file location only (no read) in src/plugins/uniso/udf.cpp
- [X] T007 [US1] In `CUDF::ReadSupportingTables` case `mapMetadata` read and parse the metadata file entry with the moved code (same error box, same 361 refusal) in src/plugins/uniso/udf.cpp
- [X] T008 [US1] Build (`.\build.cmd`) and run the probe → specs/377-uniso-udf-metadata-order/probe/result_after.txt (every row PASS, FR-002, FR-004 via R-U250FAR)

## Phase 4: User Story 2 - Every other UDF image behaves as before (P2)

**Goal**: no regression for PD-first, VAT, hybrid and damaged images.
**Independent test**: regression probes give their recorded results.

- [ ] T009 [US2] Run iso356_probe.ps1 (N-U250 now extracts - expected deviation from its old expectation), iso358_probe.ps1, iso361_probe.ps1 on the new build → specs/377-uniso-udf-metadata-order/probe/regress_356.txt, regress_358.txt, regress_361.txt; explain every changed row in fix-log.md
- [X] T010 [US2] Run saltests and `python tools/check_encoding.py --strict`; record in specs/377-uniso-udf-metadata-order/fix-log.md

## Phase 5: Polish

- [ ] T011 Independent refute-first review; record in specs/377-uniso-udf-metadata-order/fix-log.md (section Review)
- [ ] T012 Closing: FEATURE-HISTORY entry, CHANGELOG `[Unreleased]` entry, closing-report.md in specs/377-uniso-udf-metadata-order/

## Dependencies

T001 → T002 → T003 → T004 → T005..T007 → T008 → T009, T010 → T011 → T012. US2 depends on US1's code.
No UI strings: no `.slt` refresh.

## Parallel opportunities

T005 and T002 touch different files; T009's three probes run one after another (they share the registry key).

## Implementation strategy

MVP = US1 (T005-T008); US2 is verification only.
