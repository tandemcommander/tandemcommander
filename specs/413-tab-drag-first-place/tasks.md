# Tasks: Panel tabs - a drag reaches the first place; the dark strip looks as high as the default one

**Input**: `specs/413-tab-drag-first-place/` (spec.md, plan.md, research.md, data-model.md, contracts/saltabs-413.md, quickstart.md)
**Tests**: requested by the spec (FR-003, SC-001..003): saltests checks and probe rows.

## Phase 1: Setup

- [ ] T001 Start `specs/413-tab-drag-first-place/fix-log.md` with the measurement of `probe/result_before.txt` (rows, colours, DPI) and the decisions of research.md

## Phase 2: Foundational

- [ ] T002 Read the FEATURE-HISTORY entries 404 and 405 (`specs/FEATURE-HISTORY.md`) and Grep every caller of `SalTabDragSlot` and of `TabPaint.CapBk` (`src/tabwnd.cpp`); record the callers in `fix-log.md`

## Phase 3: User Story 1 - Drag a tab to the first place (P1)

**Independent test**: `tabs413_probe` FIRST and SCROLLED rows; saltests `TestTabStrip413`.

- [ ] T003 [US1] Change the moving-left branch of `SalTabDragSlot` to a ceiling division in `src/common/saltabs.cpp` and its comment in `src/common/saltabs.h` (contract `contracts/saltabs-413.md`)
- [ ] T004 [US1] Add `TestTabStrip413` drag checks to `src/saltests/saltests.cpp`: the clamped left 0 for every `from`, the exact multiples while moving left, the right end, a scrolled run (count = visible count, `from` = last), and keep all 404 checks unchanged; a negative control: the checks fail on the old rule
- [ ] T005 [US1] Correct the 405 trap sentence in `src/tabwnd.cpp` comments if any refers to the old slot 1 (none expected; record)

## Phase 4: User Story 2 - The dark tab strip looks like the default one (P2)

**Independent test**: `tabs413_probe` THEME rows; saltests fill checks.

- [ ] T006 [US2] Add `SALTAB_ACTIVE_MIN_CONTRAST` and `SalTabActiveFill` to `src/common/saltabs.h` / `src/common/saltabs.cpp`
- [ ] T007 [US2] Use `SalTabActiveFill(capBk, capFg, Strip.StripBk, ThemeSysColor(COLOR_BTNFACE), HighContrast)` for `TabPaint.CapBk` in `CTabWindow::Paint` (`src/tabwnd.cpp`)
- [ ] T008 [US2] Add fill checks to `TestTabStrip413` in `src/saltests/saltests.cpp`: default active / inactive unchanged, dark active unchanged, dark inactive -> 454545, High Contrast unchanged, a colour that cannot reach 24 -> the halfway mix, a colour close only to the face
- [ ] T009 [US2] Make `tabs404_probe` LOOK-DARK INACTIVE compare with `evidence/variantF_dark_inactive_413.png` in `specs/404-panel-tabs-rounded-look/probe/tabs404_probe.ps1`; create the baseline from the 413 capture after checking that every pixel differing from `variantF_dark_inactive.png` lies inside the active tab's rectangle (record the count in `fix-log.md`)

## Phase 5: Polish & cross-cutting

- [ ] T010 Build (`.\build.cmd`), `saltests`, encoding guard (`python tools/check_encoding.py --strict`)
- [ ] T011 Run `tabs413_probe` after (`probe/result_after.txt`), `tabs404_probe` and `tabs405_probe` (results into `specs/413-tab-drag-first-place/probe/`)
- [ ] T012 [P] Manual: the drag paragraph of `help/src/hh/salamand/windows_tabstrip.htm` says a tab dragged to either end becomes the first / last (of the visible tabs when not all fit)
- [ ] T013 `fix-log.md`: after measurements, checks, the release-checklist lines (a real mouse drag to the first place; both themes side by side at another DPI)

## Dependencies

T001 -> T002 -> (US1: T003 -> T004 -> T005) and (US2: T006 -> T007 -> T008 -> T009 after the build of T010) -> T010 -> T011 -> T013; T012 any time.
US1 and US2 are independent (different functions); both touch `saltests.cpp` (sequential).

## Implementation strategy

MVP = US1 (the drag). US2 next; one build and one probe run cover both.
