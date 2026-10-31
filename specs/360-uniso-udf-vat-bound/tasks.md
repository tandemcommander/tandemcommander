# Tasks: ISO plug-in - a damaged UDF VAT file entry no longer writes past the table buffer

**Input**: Design documents from `specs/360-uniso-udf-vat-bound/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: requested by the item (pure rules with `saltests` checks, a crafted-image probe).

## Phase 1: Setup

- [ ] T001 Start `specs/360-uniso-udf-vat-bound/fix-log.md` with the measurement at ddf0465a (probe `probe/result_before.txt`: 9 RUN rows FAIL) and the enumerated callers (research R1)

## Phase 2: Foundational - the pure rules

- [ ] T002 Add `SalIsoUdfVatTableLength`, `SalIsoUdfVatDescArea`, `SalIsoUdfVatDescSize`, `SalIsoUdfVatDescFits`, `SalIsoUdfVatCopyFits` (64-bit, no wrap, header-only) to `src/common/salisoudfvat.h`
- [ ] T003 Add `TestIsoUdfVat_360` (the measured cases: IL - 4, L_AD 4096, type 5, L_EA 0xFFFFFF00, IL + 2^32; mkudffs' well-formed entries; a grid that simulates the walk and checks it stays inside the sector and the table and always advances) to `src/saltests/saltests.cpp` and call it from the test list

## Phase 3: User Story 1 - a damaged VAT entry does not corrupt memory (P1)

**Goal**: an entry that would write past the table or read past the sector is "not a VAT".
**Independent test**: probe rows R-ILM4, R-NILM4, R-V150ILM4, R-LADBIG, R-ADT5, R-LEAHUGE, R-ILHUGE, L-ILM4, L-ADT5, L-LADBIG PASS.

- [ ] T004 [US1] `CUDF::ReadVAT` in `src/plugins/uniso/udf.cpp`: after the strategy check refuse (ERR_CONTINUE) an information length over 2^32 - 1, an area outside the sector and a reserved descriptor type before allocating; walk the area with the remaining bytes and the table length
- [ ] T005 [US1] `CUDF::ReadAllocDesc` in `src/plugins/uniso/udf.cpp` and its declaration in `src/plugins/uniso/udf.h`: take the area's remaining bytes and the table length; return -1 for a descriptor outside the area or a copy past the table (embedded and extent)
- [ ] T006 [US1] Build (`build.cmd`), `saltests`, encoding guard; record in `fix-log.md`
- [ ] T007 [US1] Run `specs/360-uniso-udf-vat-bound/probe/iso360_probe.ps1` on the hidden desktop → `probe/result_after.txt`; record

## Phase 4: User Story 2 - well-formed VAT images open as before (P2)

**Independent test**: the C-* and L-MKCDR rows of probe 360; probes 358 and 359.

- [ ] T008 [US2] Re-run `specs/358-uniso-udf-vat-missing/probe/iso358_probe.ps1` and `specs/359-uniso-udf-vat-cut/probe/iso359_probe.ps1` on the Debug build → `specs/360-uniso-udf-vat-bound/probe/regress_358.txt`, `regress_359.txt`; record
- [ ] T009 [US2] Negative control: a mutant of the rules (a bound dropped) fails a `saltests` check; record in `fix-log.md`

## Phase 5: Polish

- [ ] T010 Add the Inbox item for the uncovered table tail (research R3) with `bin/backlog.sh new` (source `measure:360`)
- [ ] T011 `fix-log.md` complete (before / after, commands, results); `CHANGELOG.md` entry under `## [Unreleased]`

## Dependencies

T001 → T002 → T003 → T004/T005 → T006 → T007 → T008/T009 → T010 → T011. US2 depends on US1's code (same
functions).

## Parallel opportunities

T008 (probes) and T009 (mutant) are independent once T006 passes; probes run one at a time (they share the
registry key).

## Implementation strategy

MVP = US1 (the memory-safety fix); US2 is its regression proof.
