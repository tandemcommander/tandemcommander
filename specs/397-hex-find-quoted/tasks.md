# Tasks: Hex mode in Find keeps quoted letters outside the code page

**Input**: `specs/397-hex-find-quoted/` (spec.md, plan.md, research.md, data-model.md, contracts/hex-field-tidy.md, quickstart.md)
**Tests**: requested by the spec (FR-007, SC-001..SC-003): saltests checks and the probe.

## Phase 1: Setup

- [X] T001 Start `specs/397-hex-find-quoted/fix-log.md` with the before measurement (`probe/result_before.txt`, 3 FAIL / 5 PASS) and the decisions of research.md

## Phase 2: Foundational (the pure rule)

- [X] T002 Create `src/common/salhexfield.h` (UTF-8 BOM, SPDX header, feature comment) with `SalHexFieldTidyW` per `contracts/hex-field-tidy.md`: the loop of `DoHexValidation` on `wchar_t`, the caret in UTF-16 units, inserts only while length < maxLen and capacity allows, the surrogate guard (rule 5)
- [X] T003 Add `TestHexFieldTidy397` to `src/saltests/saltests.cpp` (include `salhexfield.h`, call it from `main`): fixed cases (`41424` → `41 42 4` caret 7; leading spaces; `"a"41` / `41"a"` spaces around quotes; double spaces; the limit stops insertions; CJK inside quotes kept, caret after them; a typed letter inside quotes; a surrogate pair outside quotes not split; NULL / zero capacity refused), and a brute-force comparison with a verbatim `char` copy of the old loop over every ASCII text of length 0..6 from the alphabet `{' ', '"', '4', 'a'}` with every caret position - same text, same caret

## Phase 3: User Story 1 + 2 - the field keeps the letters (P1)

**Goal**: Find's Containing field and the viewer's Find field keep quoted letters while typing and search them.
**Independent test**: probe rows `grep-type`, `grep-mid`, `view-type`.

- [X] T004 [US1] Rewrite `DoHexValidation` in `src/viewer.cpp`: `GetWindowTextLengthW`, a heap `wchar_t` buffer of `max(len, textLen - 1) + 1`, `GetWindowTextW`, `SalHexFieldTidyW(buf, cap, &start, &end, textLen - 1)`, `SetWindowTextW`, `CB_SETEDITSEL`; include `common/salhexfield.h`; `LOW_MEMORY` trace and return on allocation failure as before
- [X] T005 [US1] Enumerate the callers of `DoHexValidation` / `ConvertHexToString` (Grep) and confirm in `fix-log.md` that none needs a change (`src/finddlg1.cpp`, `src/viewer.cpp`, `src/viewer.h`)
- [X] T006 [US2] Confirm the viewer's dialog path (`CFindSetDialog::DialogProc` `IDC_FINDTEXT`) uses the same function - covered by T004; record in `fix-log.md`

## Phase 4: User Story 3 - tidying kept (P2)

- [X] T007 [US3] Build (`.\build.cmd`) and run saltests; the brute-force check of T003 proves ASCII behaviour unchanged; negative control: the rule with the surrogate guard removed / a code-page simulation makes the corresponding checks fail - record in `fix-log.md`

## Phase 5: Polish

- [X] T008 Run `specs/397-hex-find-quoted/probe/hex397_probe.ps1` on the hidden desktop → `probe/result_after.txt` (4 rows PASS)
- [X] T009 Run `specs/311-find-containing-cut/probe/grep311_probe.ps1` → `probe/regress_311.txt` (26 PASS / 0 FAIL)
- [X] T010 `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`
- [X] T011 Record the HistoryComboBox error-selection finding (research R6) as an Inbox item (`measure:397`) after checking it at HEAD
- [X] T012 Complete `fix-log.md` (before / after, commands, results)

## Dependencies

T001 → T002 → T003 → T004 → T005/T006 → T007 → T008/T009/T010 → T011 → T012. US1 and US2 share T004 (one function).

## Parallel opportunities

T005 and T006 (reading only); T009 and T010.

## Implementation strategy

MVP = T002–T004 (the rule and its use); everything else verifies.
