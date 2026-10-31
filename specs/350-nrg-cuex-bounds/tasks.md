# Tasks: An NRG image's CUEX chunk gives only the tracks it holds

**Input**: Design documents from `specs/350-nrg-cuex-bounds/` (plan.md, spec.md, research.md,
data-model.md, quickstart.md)
**Tests**: the project's rules require `saltests` checks for a pure rule and a probe for a GUI-reachable
defect (CLAUDE.md *Working method*) - included.

## Phase 1: Setup

- [X] T001 Record the before-measurement (done at cadc65bb) in specs/350-nrg-cuex-bounds/fix-log.md and keep specs/350-nrg-cuex-bounds/probe/result_before.txt

## Phase 2: Foundational (blocking)

- [X] T002 Add `SalNrgCuexEntryCount(size)` (0 under 16 bytes, else `(size - 16) / 16`) with its comment to src/common/salnrgcdtext.h (header comment's list extended for feature 350)
- [X] T003 Add `TestNrgCuex350` to src/saltests/saltests.cpp (sizes 0, 1, 8, 15, 16, 31, 32, 47, 48, 52, 0xFFFFFFF0, 0xFFFFFFFF against a block-by-block reference; never more than size / 16) and call it from the test list

## Phase 3: User Story 1 - A damaged NRG image opens without exhausting memory (P1)

**Goal**: a CUEX chunk under 16 bytes or past the image's end makes no track from the bytes after it.
**Independent test**: probe rows N-SHORT, N-PAST.

- [X] T004 [US1] In src/plugins/uniso/nrg.cpp `readCUEX`: take the chunk's position and the file size, skip the chunk (seek past it, return FALSE) when `SalNrgChunkFits` fails; entry count from `SalNrgCuexEntryCount(header->Size)`
- [X] T005 [US1] In src/plugins/uniso/nrg.cpp `readCUEX`: the 16-byte header read only when the chunk holds it, every read checked for its full length; a short read makes no track and returns FALSE

## Phase 4: User Story 2 - A CUEX chunk with extra bytes no longer hides the rest (P2)

**Independent test**: probe row N-ODD.

- [X] T006 [US2] In src/plugins/uniso/nrg.cpp `readCUEX`: after the entries, seek to the chunk's end (`chunk start + Size`) so the next header is read where it starts

## Phase 5: User Story 3 - Intact NRG images open as before (P1)

**Independent test**: probe row N-OK; 329's A-OPEN.

- [X] T007 [US3] Build (`.\build.cmd`), run saltests (`build\tandemcommander\Debug_x64\saltests\saltests.exe`) → 0 failed; record the numbers in specs/350-nrg-cuex-bounds/fix-log.md
- [X] T008 [US3] Run specs/350-nrg-cuex-bounds/probe/nrg350_probe.ps1 on the hidden desktop → specs/350-nrg-cuex-bounds/probe/result_after.txt, all rows PASS
- [X] T009 [US3] Run specs/329-uniso-other-readers-refused/probe/iso329_probe.ps1 `-Only A-OPEN` → specs/350-nrg-cuex-bounds/probe/regress_329.txt, PASS

## Phase 6: Polish

- [X] T010 Negative controls: mutate the rule (underflow back; remainder counted as an entry) → TestNrgCuex350 fails; record in specs/350-nrg-cuex-bounds/fix-log.md, then restore
- [X] T011 `python tools/check_encoding.py --strict` → TOTAL: 0; fix-log *Checks* section in specs/350-nrg-cuex-bounds/fix-log.md

## Phase 7: Review 1 (SHOULD 1, NOTE 1)

- [X] T012 [US1] Add `SAL_NRG_MAX_TRACKS` / `SalNrgCuexEntriesPlausible` to src/common/salnrgcdtext.h and skip a CUEX chunk of more than 99 entries in src/plugins/uniso/nrg.cpp `readCUEX`; 5 checks in `TestNrgCuex350` (src/saltests/saltests.cpp)
- [X] T013 [US1] Add kinds zero, shortnz, inside to specs/350-nrg-cuex-bounds/probe/img350.py and rows N-ZERO, N-SHORTNZ, N-INSIDE to specs/350-nrg-cuex-bounds/probe/nrg350_probe.ps1
- [X] T014 Rebuild, saltests, probe → specs/350-nrg-cuex-bounds/probe/result_after_review1.txt; a no-cap mutant fails saltests; record in specs/350-nrg-cuex-bounds/fix-log.md

## Phase 8: Review 2 (MUST 1, SHOULD 1)

- [X] T015 [US1] Replace review 1's 99-entry bound by `SAL_NRG_CUEX_MAX_RECORDS` / `SalNrgCuexSizePlausible` (2 + 99 x 100 records of 8 bytes) in src/common/salnrgcdtext.h and src/plugins/uniso/nrg.cpp; 9 checks in `TestNrgCuex350` (src/saltests/saltests.cpp)
- [X] T016 [US3] Add the real-layout kinds idx2, idx20 to specs/350-nrg-cuex-bounds/probe/img350.py and rows N-IDX2, N-IDX20 to specs/350-nrg-cuex-bounds/probe/nrg350_probe.ps1; run → specs/350-nrg-cuex-bounds/probe/result_after_review2.txt
- [X] T017 Document the 8-byte record layout (src/common/salnrgcdtext.h, spec.md, research.md R5, data-model.md); a 99-entry mutant fails saltests; record in specs/350-nrg-cuex-bounds/fix-log.md

## Phase 9: Review 3 (SHOULD 1, NOTES 1-2)

- [X] T018 [US1] Add `SAL_NRG_CUEX_MAX_IMAGE_ENTRIES` / `SalNrgCuexTotalPlausible` to src/common/salnrgcdtext.h and skip a CUEX chunk past it in src/plugins/uniso/nrg.cpp `readCUEX`; 8 checks in `TestNrgCuex350` (src/saltests/saltests.cpp)
- [X] T019 [US1] Kind `many` in specs/350-nrg-cuex-bounds/probe/img350.py, row N-MANY in specs/350-nrg-cuex-bounds/probe/nrg350_probe.ps1; run → specs/350-nrg-cuex-bounds/probe/result_after_review3.txt; a loose-total mutant fails saltests
- [X] T020 Inbox item `iso-plug-in-an-nrg-etnf-chunk-claiming-a-huge-size` (review 3 NOTE 1); NOTE 2 added to `iso-plug-in-nrg-cuex-index-records-are-paired-into-wrong` (backlog/items/)

## Dependencies

T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008/T009 → T010 → T011. All code tasks touch
`nrg.cpp` or the header in sequence; T008 and T009 both use the hidden desktop and run one after the
other.

## Implementation strategy

US1 is the MVP (the item's main point); US2 is the same function's end-of-chunk discipline; US3 is
the regression guard. One build covers all three.
