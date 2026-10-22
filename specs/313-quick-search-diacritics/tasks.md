# Tasks: Quick search ignores diacritics

**Input**: design documents in `specs/313-quick-search-diacritics/` (plan, research, data-model,
contracts/salquickfilter-fold.md, quickstart)
**Tests**: requested by the item (saltests cases, probe rows) - included.

## Phase 1: Setup

- [ ] T001 Confirm the baseline records exist: `specs/313-quick-search-diacritics/probe/result_before.txt`, `result_off_before.txt`, `result_perf_before.txt` (measured at 9b79bd82) and note them in `specs/313-quick-search-diacritics/fix-log.md`

## Phase 2: Foundational (blocks all stories)

- [ ] T002 In `src/common/salquickfilter.h` change the "does not fit" result of `SalQFDetail::CharKey` / `CharKeySystem` from 0 to -1 and let 0 mean an empty key; add the cache marker `0xFE` (empty key) to `CCharKeyCache` (research R3)
- [ ] T003 In `src/common/salquickfilter.h` `SalQFBuildKey`: treat `n < 0` as overflow (grow), `n == 0` as a character without units (research R3/R4)
- [ ] T004 In `src/common/salquickfilter.h` `SalQFBuildMaskKeys`: do not store a segment whose key is empty (free it; build `LastNoDot` only for a stored segment) (research R3, contract F5)

## Phase 3: User Story 1 + 2 - accents ignored in both directions (P1)

**Goal**: `zlut`/`žlut` find `žluťoučký` and `zlutý`; `cesky`, `ubersicht`, `reka` (NFD) find their names.
**Independent test**: probe rows D01-D04, D07; saltests F1/F3/F4.

- [ ] T005 [US1] In `src/common/salquickfilter.h` `CharKeySystem`: after NFD and lower case, drop the units of the blocks U+0300-036F, U+1AB0-1AFF, U+1DC0-1DFF, U+20D0-20FF, U+FE20-FE2F (a helper `SalQFDetail::IsFoldedMark`)
- [ ] T006 [US1] Update the header comment of `src/common/salquickfilter.h` (keys: marks of those blocks dropped, the table; the 244 sentence about "ss" = "sharp s" belonging to the old rule only)
- [ ] T007 [US1] In `src/saltests/saltests.cpp` `TestQuickFilter244`: adjust the cases the folding changes (`x`+`ú`/`u` now SUBSTRING 1..3; `xu`+U+0301/`u` end 4; the `strasse` exception removed) and restructure M3 per research R5 (exact for pairs without foldable characters, superset property otherwise)
- [ ] T008 [US1] In `src/saltests/saltests.cpp` add the 313 block: F1 (Czech/German examples, NFC and NFD names, masks with and without marks), F3 (`が`/`か`, a Hebrew point, a Devanagari virama kept), F4 (offsets of NFD matches include the marks)

## Phase 4: User Story 3 - letters without a decomposition (P2)

**Goal**: `lodz` finds `Łódź`, `strasse` finds `Straße`, and the other table letters.
**Independent test**: probe rows D05, D06; saltests F2.

- [ ] T009 [US3] In `src/common/salquickfilter.h` `CharKeySystem`: replace the table letters `ł Ł ø Ø đ Đ ß ẞ æ Æ œ Œ ı` by `l o d ss ae oe i` (a helper `SalQFDetail::FoldLetter`)
- [ ] T010 [US3] In `src/saltests/saltests.cpp` add F2 cases: each table letter in a name against the ASCII text and the reverse; `ð`, `þ`, `ħ` not folded; a typed `s` does not end inside `ß`

## Phase 5: User Story 4 - nothing else changes (P1)

**Independent test**: saltests M1 0 differences; probe D09/D10 off; 244 probe; timing.

- [ ] T011 [US4] In `src/saltests/saltests.cpp` add F5 (lone mark at a name's start, a mask of marks only, `a/` + mark + `/c`), F6 (lone surrogate name and mask, invalid bytes), F8 (cache = uncached computation for every BMP code point, twice)
- [ ] T012 [US4] Build (`.\build.cmd`) and run `saltests.exe`; record the counts in `specs/313-quick-search-diacritics/fix-log.md`
- [ ] T013 [US4] Run `probe/qs313_probe.ps1 -Expect after` and `-Expect off -FilterOption 0` on the hidden desktop; compare D10 with `result_off_before.txt`; record in `fix-log.md`
- [ ] T014 [US4] Run the 244 probe (`specs/244-quick-search-substring-filter/probe/qs244_probe.ps1`) `-Expect new` and `-Expect old -FilterOption 0` on the new Debug build; record in `fix-log.md`
- [ ] T015 [US4] Rebuild the scratch Release tree (`OPENSAL_BUILD_DIR` = `%TEMP%\tc313rel`) and run the 244 probe `-Perf -Only P` into `specs/313-quick-search-diacritics/probe/result_perf_after.txt`; compare with the baseline in `fix-log.md`

## Phase 6: Polish

- [ ] T016 [P] In `help/src/hh/salamand/basicwork_qsearch.htm` say that accents are ignored (example `zlut` finds `žluťoučký`, `strasse` finds `Straße`) and that the search with the option cleared does not ignore them
- [ ] T017 [P] Add the 0.1.11 — unreleased entry to `CHANGELOG.md` (bold symptom, feature 313, limits: other scripts' marks kept, option-off rule unchanged)
- [ ] T018 Run `python tools/check_encoding.py --strict` (TOTAL: 0) and update `specs/313-quick-search-diacritics/fix-log.md`

## Dependencies

- T002-T004 before T005/T009; T005 and T009 touch the same function (sequential).
- T007/T008/T010/T011 after T005/T009 (same test file, sequential).
- T012 after all code; T013-T015 after T012; T016/T017 independent of the code.

## Parallel examples

- T016 and T017 (different files) can run alongside T012-T015.

## Implementation strategy

MVP = Phases 2-3 (marks dropped, symmetric); Phase 4 adds the table; Phase 5 proves no regression
and timing; Phase 6 documents.
