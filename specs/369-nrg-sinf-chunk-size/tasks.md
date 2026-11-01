# Tasks: NRG SINF chunks read by their size

**Input**: Design documents from `specs/369-nrg-sinf-chunk-size/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

Tests: the spec asks for `saltests` checks (FR-006, SC-003) and the probe (SC-001).

## Phase 1: Setup

- [X] T001 Measure the defect at HEAD with `specs/369-nrg-sinf-chunk-size/probe/iso369_probe.ps1` + `img369.py` (result_before.txt, 6 / 4) and record it in `specs/369-nrg-sinf-chunk-size/fix-log.md`

## Phase 2: Foundational

- [X] T002 Add `SAL_NRG_SINF_SIZE` and `SalNrgSinfUsable(pos, size, fileSize)` (exactly 4 bytes, within the image via `SalNrgChunkFits`) with a feature-369 note in the top comment of `src/common/salnrgcdtext.h`
- [X] T003 Add `TestNrgSinf369` (sizes 0, 2, 3, 4, 5, 8, 0xFFFFFFFF; at the file's end; past it; huge pos) and call it in `src/saltests/saltests.cpp`

## Phase 3: User Story 1 - A damaged NRG session table does not lose the rest of the image (P1)

**Independent test**: `iso369_probe` all rows PASS.

- [X] T004 [US1] `readSINF` in `src/plugins/uniso/nrg.cpp`: take the count only when `SalNrgSinfUsable` holds and the 4 bytes are read whole; otherwise no count, `TRACE_I`, `iso->ListingLeftOut.SetIncomplete()`
- [X] T005 [US1] `ReadNRGRoot` in `src/plugins/uniso/nrg.cpp`: remember the position after each chunk header and, after every known reader, seek to `start + header.Size` (return FALSE when the seek fails, as for unknown chunks)
- [X] T006 [US1] Build (`.\build.cmd`), run `saltests`, run `iso369_probe` -> `probe/result_after.txt`; record in fix-log
- [X] T007 [US1] Mutants: (a) `SalNrgSinfUsable` accepts every size -> saltests fails; (b) no mark in `readSINF` -> S-SINF0 deletes the image; (c) no loop seek with the old `readSINF` behaviour kept is the before result; record in fix-log and restore

## Phase 4: Polish

- [X] T008 [P] Regressions: `iso340_probe` (14 / 0), `nrg350_probe` (20 / 0), `iso365_probe` (22 / 0) -> `probe/regress_*.txt`
- [X] T009 [P] `python tools/check_encoding.py --strict` -> TOTAL: 0; clang-format on the changed ranges
- [X] T010 Check for other readers that read past their chunk (DAOX) by reading; an Inbox item when confirmed (measure:369)

## Dependencies

T001 -> T002 -> T003 -> T004/T005 -> T006 -> T007 -> T008/T009 -> T010. One story; MVP = Phase 3.
