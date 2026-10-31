# Tasks: A UDF image with a VAT that is not found no longer crashes

**Input**: Design documents from `specs/358-uniso-udf-vat-missing/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: requested by the spec (FR-007, SC-003: `saltests` checks; SC-001/SC-002: probe rows).

## Phase 1: Setup

- [X] T001 Probe and image builder in place: `specs/358-uniso-udf-vat-missing/probe/iso358_probe.ps1`, `specs/358-uniso-udf-vat-missing/probe/vatimg.py`, before-result `specs/358-uniso-udf-vat-missing/probe/result_before.txt` (measured at 249e35f0: 14 / 8)

## Phase 2: Foundational (the pure rules)

- [X] T002 Create header-only `src/common/salisoudfvat.h` (UTF-8 BOM, English comments) with `SalIsoUdfVatTranslates(lbNum, entries, hasTable)` (table present and `lbNum < entries`) and `SalIsoUdfVat200Entries(infoLen, headerLen, tableLen, entries&)` (false when `headerLen > infoLen` or `infoLen > tableLen`; else `entries = (infoLen - headerLen) / 4`)
- [X] T003 Add `TestIsoUdfVat_358` to `src/saltests/saltests.cpp` (include the header beside `salisotrack.h`, call it after `TestIsoPlainLayouts_357`): no table -> never; entries 0; lbNum entries-1 / entries / entries+1; 0xFFFFFFFF; huge entries; VAT 2.00 header longer than the length, length past the table, exact fit, odd remainders

## Phase 3: User Story 1 + 2 - no crash when the VAT is not found (P1)

**Goal**: Unpack (Alt+F9) and Enter on a VAT image whose VAT is not found show the missing-table box, the program keeps running, nothing extracted, the image kept.
**Independent Test**: probe rows R-VCDR100, R-VCLAIM16, R-VCLAIM100Z, L-VCDR100.

- [X] T004 [US1] `src/plugins/uniso/udf.cpp` `CUDF::ReadSupportingTables`: after the VAT search of a `mapVirtual` partition, `vatRet != ERR_OK` (`ERR_CONTINUE`: show `IDS_UDF_MISSING_VAT` as today; `ERR_TERMINATE`: the message was shown by the callee) returns FALSE; remove the dead `ret = TRUE` assignment logic accordingly
- [X] T005 [US1] `src/plugins/uniso/udf.cpp` `CUDF::LogSector` case `mapVirtual`: translate only when `SalIsoUdfVatTranslates(lbNum, PartitionMapping.Entries, PartitionMapping.Translation != NULL)`; include `../../common/salisoudfvat.h`
- [X] T006 [US1] `src/plugins/uniso/udf.cpp` `CUDF::CUDF`: set `PartitionMapping.Entries = 0`, `PartitionMapping.Length = 0`
- [X] T007 [US1] `src/plugins/uniso/udf.cpp` `CUDF::CheckForVAT` VAT 2.00 branch: entry count via `SalIsoUdfVat200Entries(fe.InformationLength, l_hd, vatLen, entries)`; false -> `delete[] vat`, `ERR_CONTINUE`; also refuse a table shorter than 2 bytes before `GET_WORD(vat, 0)`
- [X] T008 [US1] Build (`build.cmd`), run `saltests`, run the probe after the fix -> all rows PASS; record in `specs/358-uniso-udf-vat-missing/fix-log.md`

## Phase 4: User Story 3 - readable VAT images unchanged (P2)

**Independent Test**: probe rows C-VCLAIM, C-MKCDR, C-MKCDRC, C-MKDVDR, C-MKBDR, C-MKHD, L-MKCDR; probe 356.

- [X] T009 [US3] Run `specs/356-uniso-udf-rest/probe/iso356_probe.ps1` on the fixed build -> 56 / 0; record in `specs/358-uniso-udf-vat-missing/fix-log.md`
- [X] T010 [US3] Negative control: `SalIsoUdfVatTranslates` mutated to `<=` (temporarily, in a copy of the check) -> saltests fails; record and restore `src/common/salisoudfvat.h`

## Phase 5: Polish

- [X] T011 `python tools/check_encoding.py --strict` -> TOTAL: 0
- [X] T012 Inbox item for the VAT reader's unbounded copy of allocation descriptors (`ReadVAT` / `ReadAllocDesc`, research R3) if confirmed by reading - `measure:358`
- [X] T013 fix-log, FEATURE-HISTORY entry, CHANGELOG entry under `## [Unreleased]`, closing report (`specs/358-uniso-udf-vat-missing/`)

## Dependencies

T001 -> T002 -> T003 -> T004..T007 (same file, sequential) -> T008 -> T009, T010 -> T011..T013.
US1 and US2 share one code change (the listing path is the same); US3 checks it does not regress.

## Parallel opportunities

T009 and T010 can run in parallel (probe vs. saltests mutant in a copy); T012 in parallel with the probe runs.

## Implementation strategy

MVP = Phase 2 + Phase 3 (the crash gone). Phase 4 proves no regression; Phase 5 closes the item.
