# Tasks: Registry Editor Find - whole-word regexp, empty regexp, letters in quoted hex

**Input**: Design documents from `specs/257-regedt-find-words-hex/`
**Prerequisites**: plan.md, spec.md, research.md, contracts/hex-pattern.md, quickstart.md

**Tests**: requested by the spec (FR-006, SC-001, SC-002): saltests checks and the hidden-desktop probe.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [X] T001 Record the before measurement (probe 7 / 2, code reading, callers) in specs/257-regedt-find-words-hex/fix-log.md and keep specs/257-regedt-find-words-hex/probe/result_before.txt

## Phase 2: Foundational

- [X] T002 Create the header-only rules file src/common/salregfind.h (UTF-8 BOM, SPDX header, feature 257 comment block, needs <windows.h>) and include it from src/plugins/regedt/precomp.h and src/saltests/saltests.cpp

## Phase 3: User Story 1 - Whole-word regexp on every line (P1)

**Goal**: a whole-word regexp match is judged by its own line.
**Independent Test**: probe row WW-LINE2; saltests whole-word checks.

- [X] T003 [US1] Add `SalRegFindWholeWordInLine(const char* line, int lineLen, int pos, int matchLen)` to src/common/salregfind.h (matchLen > 0, boundaries isspace on unsigned char or the line's start / end)
- [X] T004 [US1] Call it in `CFindThread::Test` regexp branch with `start` and `end - start` in src/plugins/regedt/finddlg.cpp
- [X] T005 [P] [US1] Add saltests checks `TestRegFindWholeWord257` in src/saltests/saltests.cpp (a match on the second line of "abcdefgh\0foo bar" judged true, "a bcdef\0xxbar" judged false, start / end of line, matchLen 0 false)

## Phase 4: User Story 2 - Empty regexp finds everything (P2)

**Goal**: an empty regexp behaves as the empty plain pattern.
**Independent Test**: probe rows EMPTY-RX, EMPTY-RX-WW.

- [X] T006 [US2] In `CFindDialog::StartSearch` regexp branch, give an empty converted pattern the length 0 in src/plugins/regedt/finddlg2.cpp

## Phase 5: User Story 3 - Quoted hex letters are their code-page bytes (P2)

**Goal**: `'...'` text becomes all its code-page bytes; the length check counts the same bytes.
**Independent Test**: saltests hex checks under 65001 / 932 / 1250; probe rows HEX-CP, HEX-CP-BYTES.

- [X] T007 [US3] Add `SalHexPatternToBytes(const WCHAR* text, UINT codePage, BOOL strict, char* out, int outSize, int* outLen)` returning SALHEXPAT_OK / _BAD / _TOOLONG to src/common/salregfind.h per contracts/hex-pattern.md
- [X] T008 [US3] Make `ConvertHexToString` (lenient, `len = -1` unless OK) and `ValidateHexString` (strict, count only) wrappers with `CP_ACP` in src/plugins/regedt/utils.cpp (remove the local `IsXdigit` if unused)
- [X] T009 [P] [US3] Add saltests checks `TestHexPattern257` in src/saltests/saltests.cpp: 65001 `'<C-caron>AB'` = C4 8D 41 42, `01 '<C-caron>AB' 02`, a surrogate pair = 4 bytes, 932 `'<a hiragana>'` = 82 A0, 1250 = E8 (unchanged), `"ab"` UTF-16, unclosed quote, strict lone digit BAD / lenient 01, count mode, exact fit OK, one byte short TOOLONG, empty quotes 0 bytes

## Phase 6: Polish & Verification

- [X] T010 Encoding guard `python tools/check_encoding.py --strict` → TOTAL: 0
- [X] T011 Build `.\build.cmd` → BUILD SUCCEEDED; saltests → 0 failed
- [X] T012 Probe after on the hidden desktop → 9 PASS / 0 FAIL, result in specs/257-regedt-find-words-hex/probe/result_after.txt; negative control: the saltests hex checks fail against the old per-unit conversion (recorded in fix-log.md)
- [X] T013 Update specs/257-regedt-find-words-hex/fix-log.md with the after measurement and the checks
- [X] T014 Format the changed sources with clang-format (src/common/salregfind.h, src/plugins/regedt/finddlg.cpp, finddlg2.cpp, utils.cpp, src/saltests/saltests.cpp)
- [X] T015 Add the user-visible entry (symptom in bold, feature 257, limits) to CHANGELOG.md under the `— unreleased` heading (at closing, SKILL step 8.5)

## Dependencies

T001 → T002 → (US1: T003 → T004, T005) · (US2: T006) · (US3: T007 → T008, T009) → T010–T013.
T014 before the final build; T015 at closing.
US1, US2, US3 are independent of each other after T002.

## Parallel examples

- T005 and T009 (saltests) can be written alongside T004 / T008 (different files).

## Implementation Strategy

MVP = US1 (the P1 wrong results); US2 and US3 follow in the same build; one probe run verifies all.
