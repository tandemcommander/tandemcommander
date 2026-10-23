# Tasks: Markdown Viewer - choose the page width in View, up to the full window

**Input**: `specs/314-mdview-page-width/` (plan.md, spec.md, research.md, data-model.md, contracts/page-width.md, quickstart.md)
**Tests**: the generator harness assertions and the hidden-desktop probe are requested by the spec (SC-001..SC-004).

## Phase 1: Setup

- [X] T001 Start `specs/314-mdview-page-width/fix-log.md` with the measurement at da0a455a (generator 38/0, CSS 46rem, unused `.full`, scheme change opens at the top, no manual page)

## Phase 2: Foundational (the pure rule)

- [X] T002 Add `MdPageWidth`, `MdPageWidthFromStored` and the `pageWidth` parameters of `MdRenderHtml` / `MdBuildSourceHtml` in `src/plugins/mdview/htmlgen.h` (contract page-width.md)
- [X] T003 Implement the article tag per level and the `.wide` / `.wider` / `.full` CSS rules in `src/plugins/mdview/htmlgen.cpp`; Normal keeps the article tag byte-identical; the `table` / `pre` / `img` rules (`max-width:100%`, `overflow-x:auto`) stay unchanged so they follow the column (FR-003)
- [X] T004 Add assertions to `tests/mdview_htmlgen_test/test_main.cpp`: Normal tag exact and no width class, each level's class and CSS rule, out-of-range level -> Normal, `MdPageWidthFromStored` 0-3 kept / 4, 7, 0xFFFFFFFF -> 0, View Source carries the class; run `tests/mdview_htmlgen_test/build_and_run.cmd`

## Phase 3: User Story 1 - widen the column of an open document (P1)

**Independent test**: View > Page Width lists four radio items; each choice is checked and the page is rebuilt with the level.

- [X] T005 [US1] Add `CM_VIEW_WIDTH_FIRST` (220..223) and `g_pageWidth` declaration in `src/plugins/mdview/mdview.h`
- [X] T006 [US1] Add string ids 2027, 2028, 2029, 2016, 2017 in `src/plugins/mdview/mdview.rh2` and the English texts in `src/plugins/mdview/lang/lang.rc2`
- [X] T007 [US1] In `src/plugins/mdview/viewer.h` / `viewer.cpp`: `PageWidth` member (from `g_pageWidth` in the constructor), `HWidthMenu`, the submenu after Color Scheme in `BuildMenu`, the radio check in `RefreshSchemeChecks`, `SelectPageWidth` (no-op when unchanged; sets both; `Regenerate()`), dispatch of 220..223, `RebuildHtml` passes the level to both generators

## Phase 4: User Story 2 - the width is remembered (P2)

- [X] T008 [US2] `CONFIG_PAGEWIDTH` "PageWidth", `g_pageWidth` definition, load through `MdPageWidthFromStored`, save beside `ZoomPercent` in `src/plugins/mdview/mdview.cpp`

## Phase 5: User Story 3 - nothing changes by default (P1)

- [X] T009 [US3] Confirm by T004 that the Normal page differs from the page of HEAD only by the added CSS rules (dump a sample at HEAD and after with `build_and_run.cmd dump`, diff), record in fix-log.md

## Phase 6: Probe and polish

- [X] T010 Write `specs/314-mdview-page-width/probe/pw314_probe.ps1` (style of `specs/262-codeview-code-tables/probe/cvtab262_probe.ps1` / `specs/241-pack-long-nested-folder/probe/pack241_probe.ps1`, registry backup/restore via `specs/098-long-path-overruns/probe/fix_probe_lib.ps1`): rows MENU, CHOOSE per level, WIDTH per level (PrintWindow capture; NOT DRIVEN if blank), SAVED, RESTART, UNKNOWN (stored 7 -> Normal)
- [X] T011 Build `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED; encoding guard `python tools/check_encoding.py --strict` -> TOTAL 0
- [X] T012 Run the probe before (on the HEAD build if available, else record the menu has no Page Width) and after; run `specs/081-mdview-shared-webhost/probe/mdview_probe.ps1 -Scenario smoke` on the hidden desktop; record results in fix-log.md
- [X] T013 [P] Update `src/plugins/mdview/IMPLEMENTATION_NOTES.md` (levels instead of the unwired toggle)
- [X] T014 [P] CHANGELOG entry under `0.1.11 — unreleased` in `CHANGELOG.md`
- [X] T015 Record the `.slt` refresh as owed (rule 084; `build.cmd full` result) and the person checks in fix-log.md

## Dependencies

T001 -> T002 -> T003 -> T004; T005, T006 -> T007; T008 after T002; T009 after T004; T010-T012 after T007/T008; T013, T014 any time after T007.

## Parallel examples

T013 and T014 touch different files and can be done together; T005 and T006 too.

## Implementation strategy

MVP = Phases 2-3 (levels visible and applied); then persistence (Phase 4), the default check (Phase 5), probe and records (Phase 6).
