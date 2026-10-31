---
description: "Task list for feature 359 - a cut UDF VAT image no longer hangs the listing"
---

# Tasks: ISO plug-in - a cut UDF VAT image no longer hangs the listing

**Input**: Design documents from `specs/359-uniso-udf-vat-cut/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: requested by the spec (FR-005, SC-001 - SC-003): `saltests` checks and the hidden-desktop probe.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [ ] T001 Start `specs/359-uniso-udf-vat-cut/fix-log.md` with the measurement before (probe `probe/result_before.txt`: PASS 9 / FAIL 5) and the sites read at HEAD (`src/plugins/uniso/udf.cpp` `CUDF::ReadSupportingTables`)

## Phase 2: Foundational (the pure rule)

- [ ] T002 Add `SalIsoUdfVatFallback(fileSectors, partStart, failed, taken, first, last)` to `src/common/salisoudfvat.h` (research R3)
- [ ] T003 Add `TestIsoUdfVat_359` to `src/saltests/saltests.cpp` and call it from the test list: the cases of the spec (taken, file ending at / before the partition start, `n + 7 >= failed`, `n < 7`, `n >= 7`, failed below 7, 64-bit file counts) and a simulation of the search loop over a grid (file sectors, partition start, claimed length, readable limit) that must end within 21 reads
- [ ] T004 Mutant control: drop the `taken` guard (or compute `n - 7` in 32 bits) in a scratch copy of the header - `TestIsoUdfVat_359` must fail; record in `fix-log.md`

## Phase 3: User Story 1 - a cut raw VAT image does not hang (P1)

**Goal**: L-RAWCUT / R-RAWCUT answer with the read-error box. **Independent test**: probe rows L-RAWCUT, R-RAWCUT.

- [ ] T005 [US1] In `src/plugins/uniso/udf.cpp` `CUDF::ReadSupportingTables` (case `mapVirtual`) replace the inline `nSectors` fallback with `SalIsoUdfVatFallback` and a local `fallbackTaken` flag (include `salisoudfvat.h` is already there - check)
- [ ] T006 [US1] Build (`.\build.cmd`) and run `saltests`

## Phase 4: User Story 2 - 2048-byte cuts end at once (P1)

**Goal**: L-CUT0 read error, L-CUT3 / R-CUT3 missing-VAT box. **Independent test**: probe rows L-CUT0, L-CUT3, R-CUT3.

- [ ] T007 [US2] Run `specs/359-uniso-udf-vat-cut/probe/iso359_probe.ps1` (after) on the hidden desktop -> every row PASS; result in `probe/result_after.txt`

## Phase 5: User Story 3 - whole VAT images as before (P2)

- [ ] T008 [US3] Re-run `specs/358-uniso-udf-vat-missing/probe/iso358_probe.ps1` on the build -> 40 / 0; result in `specs/359-uniso-udf-vat-cut/probe/regress_358.txt`

## Phase 6: Polish

- [ ] T009 `python tools/check_encoding.py --strict` -> TOTAL: 0
- [ ] T010 Inbox item (measure:359) for counting a raw dump's sectors in 2048 bytes (row L-RAWFULL)
- [ ] T011 `fix-log.md`: after measurements, commands, results

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008 -> T009 - T011. Stories share one function, so no
parallel work.

## Implementation Strategy

MVP = Phase 2 + US1 (the hang). US2 and US3 are verification of the same change.
