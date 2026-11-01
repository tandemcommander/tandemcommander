# Tasks: A UDF volume whose partition maps do not fit its descriptor does not open

**Input**: Design documents from `specs/378-uniso-udf-partition-maps/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

## Phase 1: Setup

- [ ] T001 Record the measurement at HEAD (frozen build, probe rows, seeds) in specs/378-uniso-udf-partition-maps/fix-log.md

## Phase 2: Foundational (the pure rule)

- [ ] T002 Create header-only rule `SalIsoUdfPartitionMapMinLen` / `SalIsoUdfLvdMapsFit` in src/common/salisoudfmaps.h (UTF-8 BOM, SPDX header, English comments, research R1 / R2)
- [ ] T003 Add `TestIsoUdfMaps_378` to src/saltests/saltests.cpp: the IMAPI2FS shapes accepted (1 type 1 map; type 1 + metadata map), count 0, table larger than the sector with maps inside; refused: count past the maps (zero bytes), length 0 / 1, map past the table, map past the sector, table 4, type 2 shorter than 44, 268 maps + count 300, held < 440; a grid over count / table length / fill bytes checking that an accepted walk ends inside the area; include the header and call the test from main

## Phase 3: User Story 1 - A damaged partition map table is refused (P1)

**Goal**: the descriptor's maps are read only inside the sector and the table; otherwise the UDF volume does not open.
**Independent Test**: probe rows R-COUNT, R-LEN0, R-TABLE, R-RUN, R-MANY, R-BCOUNT.

- [ ] T004 [US1] Make `CUDF::ReadLVD` return `BOOL` and call `SalIsoUdfLvdMapsFit(sector, SECTOR_SIZE, count)` before any `ReadPartitionMap` in src/plugins/uniso/udf.cpp (include `../../common/salisoudfmaps.h`) and change its declaration in src/plugins/uniso/udf.h
- [ ] T005 [US1] In `CUDF::Open` (src/plugins/uniso/udf.cpp) on a refused descriptor: `Error(IDS_ERROR_LISTING_IMAGE, quiet, block)` and `return FALSE`
- [ ] T006 [US1] Build (`.\build.cmd`), run saltests, run `iso378_probe.ps1 -Label after` on the hidden desktop into specs/378-uniso-udf-partition-maps/probe/result_after.txt; record in fix-log.md

## Phase 4: User Story 2 - Well-formed images behave as before (P2)

**Goal**: valid images unchanged. **Independent Test**: rows C-U201, C-U250, C-B201; regression probes.

- [ ] T007 [US2] Run the regression probes specs/356-uniso-udf-rest/probe/iso356_probe.ps1, specs/358-*/probe/iso358_probe.ps1, specs/361-*/probe/iso361_probe.ps1, specs/377-uniso-udf-metadata-order/probe/iso377_probe.ps1 on the new build into specs/378-uniso-udf-partition-maps/probe/regress_*.txt; compare with their recorded totals in fix-log.md

## Phase 5: Polish

- [ ] T008 `python tools/check_encoding.py --strict` -> TOTAL 0; record checks in specs/378-uniso-udf-partition-maps/fix-log.md
- [ ] T009 Add the Inbox item for the IMAPI2FS bridge image kept by the rest rule (measure:378) via bin/backlog.sh

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008; T009 independent.
US2 depends on US1's build. No parallel work worth splitting (one header, one source file).

## Implementation Strategy

MVP = Phase 2 + US1 (the refusal); US2 is verification only.
