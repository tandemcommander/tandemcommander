# Tasks: Registry Editor Find - a regexp searches the whole code-page text

**Input**: Design documents from `specs/278-regedt-find-regexp-cp/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/text-to-code-page.md, quickstart.md

**Tests**: requested by the item (FR-004: saltests with the code page as a parameter, a negative
control); feature 257's probe re-run as a regression control.

## Phase 1: Setup (the before state)

- [X] T001 Build the unchanged tree (PowerShell `.\build.cmd`) and run feature 257's probe `specs/257-regedt-find-words-hex/probe/find_words_hex_probe.ps1` on the hidden desktop logged by `tools/run_on_hidden_desktop.ps1 -Log specs/278-regedt-find-regexp-cp/probe/result_before.txt`; record rows in `specs/278-regedt-find-regexp-cp/fix-log.md`

## Phase 2: Foundational (the pure rule)

- [X] T002 Add `SalRegFindTextToCodePage(text, units, codePage, out, outSize)` per `contracts/text-to-code-page.md`, with its header comment, to `src/common/salregfind.h`

## Phase 3: User Story 1 - A regexp finds text at the end of a non-ASCII value (Priority: P1)

**Goal**: the regexp searches the whole code-page form of every text and name.

**Independent Test**: saltests `TestRegFindTextToCodePage278` - 65001 `čččč bar` = 12 bytes ending `bar`; 932; 1250; a too small space -1; the old unit sizing loses `bar` (negative control).

- [X] T003 [US1] Add `TestRegFindTextToCodePage278` (65001, 932, 1250, too small space, empty / NULL text, lone surrogate count = conversion, negative control of the old sizing) and call it from the test runner in `src/saltests/saltests.cpp`
- [X] T004 [US1] In `CFindThread::Test`, regexp branch, count with `SalRegFindTextToCodePage(..., CP_ACP, NULL, 0)`, reserve the count, convert, return FALSE when the count is -1 or the conversion differs, and set `len` to the converted count, in `src/plugins/regedt/finddlg.cpp`

## Phase 4: Polish & verification

- [X] T005 Build (PowerShell `.\build.cmd`) → `BUILD SUCCEEDED`; run `saltests.exe` → `0 failed`; record counts in `specs/278-regedt-find-regexp-cp/fix-log.md`
- [X] T006 Negative control: temporarily make the rule size by units (or break the check), confirm saltests fails, restore; record in `specs/278-regedt-find-regexp-cp/fix-log.md`
- [X] T007 Bash `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`
- [X] T008 Re-run feature 257's probe on the new build logged by `tools/run_on_hidden_desktop.ps1 -Log specs/278-regedt-find-regexp-cp/probe/result_after.txt` → 9 PASS / 0 FAIL; record in `specs/278-regedt-find-regexp-cp/fix-log.md`
- [X] T009 Record the GUI check under a UTF-8 ANSI code page as owed to a person (quickstart step 4) in `specs/278-regedt-find-regexp-cp/fix-log.md`

## Dependencies

T001 → T002 → T003, T004 → T005 → T006 → T007, T008 → T009. T003 and T004 touch different files
and can be written in parallel once T002 exists.

## Implementation Strategy

One story (MVP = the whole feature): the rule, its checks, the one call site, then the checks of
the run and the regression probe.
