# Tasks: Renamer regular expressions work on whole letters of UTF-8 names

**Input**: Design documents from `specs/254-renamer-regex-letters/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/salu8letter.md

**Tests**: saltests checks for the shared rules (FR-013, the item's *Approach*) and the
hidden-desktop probe `probe/ren_regex_probe.ps1` (measured before at 3ea24ab5).

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [X] T001 Record the before measurement (probe 19 rows, 17 FAIL) and the design decisions in specs/254-renamer-regex-letters/fix-log.md

## Phase 2: Foundational (blocking)

- [X] T002 Create src/common/salu8letter.h: `SalU8UnitLen`, `SalU8UnitBack`, `SalU8IsUnitBoundary` (R1, WTF-8 surrogates as one unit), `SalU8LetterTypes` (GetStringTypeW + icu.dll `u_charType` loaded from System32, R2), `SalU8IsWordValue`, and the plain whole-word helpers `SalU8IsAlnumAt` / `SalU8IsAlnumBefore` moved from src/common/salu8fold.h with the new classification
- [X] T003 Add `SalU8FoldCodePoint` (same-length lower case + final sigma -> sigma) to src/common/salu8fold.h, use it in `SalU8FoldSameLength`, remove the moved whole-word helpers, update the header comment
- [X] T004 Add saltests checks for salu8letter.h (unit length / back / boundary over ASCII, 2-4 byte letters, invalid bytes, truncated sequences, WTF-8 surrogates; back == forward segmentation on mixed text; types of Cyrillic, CJK, U+0301, U+093E, U+20000, U+1F4C1, invalid; word values; whole-word helpers) and for the sigma fold in src/saltests/saltests.cpp (include salu8letter.h; keep 210's checks passing)

## Phase 3: User Story 1 - an expression never splits a letter (P1)

**Goal**: `.`, classes, `\w \d \s`, POSIX classes and quantifiers consume whole letters.
**Independent test**: probe rows dot, w-cyr, class, negclass, range, quant, posix, mark, nonbmp, ci-class, empty.

- [X] T005 [US1] regexp.h / regexp.cpp: unit helpers on CRegExp (`UnitLen`, boundary) and `ANY` / `ANYDOT` consuming one unit in `RegMatch`, `RegRepeat` (count units), `RegMatchSimple` (return the unit length) in src/plugins/renamer/regexp.cpp and src/plugins/renamer/regexp.h
- [X] T006 [US1] Class builder: variable-length ANYOF operand (bitmap + NEG + tests + ranges, data-model.md); bracket parsing by units (literal letters as code points, ranges per R3, `\w` etc. and POSIX classes as tests, bitmap bits >= 128 only from explicit `\x` bytes); `\w`-style atoms outside brackets through the same builder; `ClassMatch` used by `RegMatch`, `RegRepeat`, `RegMatchSimple` in src/plugins/renamer/regexp.cpp
- [X] T007 [US1] Literal runs: back off the last unit before `*+?`; a one-unit literal is SIMPLE; fixed width counted in units; EXACTLY matches only up to a unit boundary; `RegRepeat` / `RegMatchSimple` repeat a multi-byte EXACTLY in src/plugins/renamer/regexp.cpp
- [X] T008 [US1] STAR / PLUS back off one unit at a time; UGSTAR / UGPLUS advance by the matched unit; `RegExec` starts only at unit boundaries (RegStart candidates checked, general loop by units) in src/plugins/renamer/regexp.cpp
- [X] T009 [US1] `CRenamer::RESubst`: after an empty match skip one whole unit (`SalU8UnitLen`) in src/plugins/renamer/crenamer.cpp

## Phase 4: User Story 2 - word boundaries and look-behind judge letters (P1)

**Goal**: `\b`, `\B`, look-behind and plain whole words by letters.
**Independent test**: probe rows wordb, lookb, ww-mark.

- [X] T010 [US2] WORDB / NOTWORDB by the unit before and at the position (ASCII by the engine's `IsWord`, others `SalU8IsWordValue`) in src/plugins/renamer/regexp.cpp
- [X] T011 [US2] PLOOKB / NLOOKB step back the width in units (fail at the start of the name) in src/plugins/renamer/regexp.cpp
- [X] T012 [US2] Plain whole words: crenamer.cpp includes salu8letter.h (the moved `SalU8IsAlnumAt` / `SalU8IsAlnumBefore`) in src/plugins/renamer/crenamer.cpp

## Phase 5: User Story 3 - case-insensitive escapes and final sigma (P2)

**Goal**: `\x` escapes forming one letter are one folded letter; sigma folding.
**Independent test**: probe rows esc, sigma, bm-sigma.

- [X] T013 [US3] `\x` escapes grouped into one unit (outside and inside brackets); case-insensitive: folded with `SalU8FoldCodePoint` in src/plugins/renamer/regexp.cpp
- [X] T014 [US3] Final sigma via T003 (no extra code in the Renamer; the pattern and the name are folded by `SalU8FoldSameLength`) - verify crenamer.cpp needs no change in src/plugins/renamer/crenamer.cpp

## Phase 6: User Story 4 - histories (P3)

- [X] T015 [US4] `HistoryComboBox`: `SalNameOrderEqualCI(history[j], -1, text, -1)` instead of `SG->StrICmp` in src/plugins/renamer/dialogs.cpp (include ../../common/salnameorder.h)

## Phase 7: Polish & verification

- [X] T016 Encoding guard `python tools/check_encoding.py --strict` -> TOTAL: 0; build `.\build.cmd` -> BUILD SUCCEEDED; saltests -> 0 failed
- [X] T017 Run probe/ren_regex_probe.ps1 after the fix (all rows PASS) -> specs/254-renamer-regex-letters/probe/result_after.txt
- [X] T018 Regression probes: 210 ren_search_probe.ps1, 196, 199, 206, 207, 208, 209 -> specs/254-renamer-regex-letters/probe/regress_*.txt
- [X] T019 Record after-measurements, checks and limits in specs/254-renamer-regex-letters/fix-log.md

## Dependencies

- T002 -> T003 -> T004 (header first); T005-T013 depend on T002/T003; T005 before T006-T008 (helpers);
  T009, T012, T015 independent of the engine tasks (different files) once T002 exists.
- All implementation tasks before T016-T019.

## Parallel opportunities

- T009, T012, T015 [different files] can be done alongside the engine tasks T005-T013.

## Implementation strategy

MVP = Phase 2 + US1 (the refusals). US2 contains the wrong-name defect and ships with it; US3 and
US4 complete the item. One build and one probe run at the end of the engine work, then fixes.
