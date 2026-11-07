# Tasks: Find - a second sort by the same result column reverses the order

**Input**: `specs/407-find-sort-toggle/` (plan.md, spec.md, research.md, data-model.md, quickstart.md)
**Tests**: required by the spec (FR-009 `saltests`, SC-001 probe).

## Phase 1: Setup

- [ ] T001 Confirm the probe `specs/407-find-sort-toggle/probe/find_sort_probe.ps1` runs from the feature folder (default `-Repo` = the repository root) and keep `probe/result_before.txt` as the before record

## Phase 2: Foundational (the pure rules)

- [ ] T002 Create `src/common/salfindsort.h` (UTF-8 BOM, SPDX header): `CSalFindSortState`, `SAL_FIND_SORT_NONE`, the column numbers, `SAL_FIND_HDF_SORTUP` / `SAL_FIND_HDF_SORTDOWN`, `SalFindSortColumnAllowed`, `SalFindSortNext`, `SalFindSortNextKey` (the tie-break chain of `CompareFunc`), `SalFindSortOrder` (folders first, then the direction), `SalFindSortDirected`, `SalFindSortHeaderFormat` (data-model.md transitions)
- [ ] T003 Add `TestFindSort407` to `src/saltests/saltests.cpp` (include + call): every transition of data-model.md, the allowed-column table for normal / duplicate (name+size / not) modes, the tie-break chains for sortBy 0..4 equal to the old loop, folders first in both directions, the exact reverse within a group, the header format bits (other bits kept, only one column marked, none for SAL_FIND_SORT_NONE)

## Phase 3: User Story 1 - reverse with a second click (P1)

**Independent test**: probe rows `menu-time`, `click-date`, `click-other`, `click-size`.

- [ ] T004 [US1] In `src/find.h` (`CFoundFilesListView`): member `CSalFindSortState SortState`; `SortItems(int sortBy, BOOL toggle = TRUE)`; `CompareFunc` / `QuickSort` / `CompareDuplicatesFunc` / `QuickSortDuplicates` take the direction; declare `ResetSort()` and `UpdateSortArrows()`
- [ ] T005 [US1] In `src/finddlg1.cpp`: the constructor sets `SortState` to none; `SortItems` checks `SalFindSortColumnAllowed`, does nothing on an empty list, computes `SalFindSortNext`, sorts once in the normal mode (the second identical `QuickSort` removed), passes the direction to both sorts; `CompareFunc` rewritten on `SalFindSortNextKey` + `SalFindSortOrder` (same order as before for ascending); `CompareDuplicatesFunc` result through `SalFindSortDirected`
- [ ] T006 [US1] In `src/finddlg2.cpp` `OnHideDuplicateNames`: `SortItems(1, FALSE)` (never toggles)

## Phase 4: User Story 2 - the arrow (P2)

**Independent test**: arrow columns of every probe row; row `new-search`.

- [ ] T007 [US2] In `src/finddlg1.cpp`: `UpdateSortArrows()` sets each header item's format with `HDM_GETITEMW` / `HDM_SETITEMW` (`HDI_FORMAT` only) through `SalFindSortHeaderFormat`; called at the end of a sort; `ResetSort()` clears the state and the arrows
- [ ] T008 [US2] In `src/finddlg1.cpp` `CFindDialog::StartSearch`: call `FoundFilesListView->ResetSort()` next to `ListView_SetItemCount(..., 0)`

## Phase 5: User Story 3 - duplicate search keeps its rules (P3)

**Independent test**: `saltests` allowed-column and duplicates-direction checks (T003).

- [ ] T009 [US3] Verify the View menu enabling (`CML_FIND_VIEW`) and `SortItems` use the same rule: replace the duplicated condition in `CML_FIND_VIEW` with `SalFindSortColumnAllowed` in `src/finddlg1.cpp`

## Phase 6: Polish

- [ ] T010 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; `.\build.cmd` -> `BUILD SUCCEEDED`; `saltests` -> 0 failed
- [ ] T011 Negative control: `SalFindSortNext` with the toggle disabled makes `TestFindSort407` fail (record count), then restore
- [ ] T012 Probe after: `probe/result_after.txt` all PASS; record in `fix-log.md`
- [ ] T013 Update the probe header text if rows changed; record the before / after in `specs/407-find-sort-toggle/fix-log.md`

## Dependencies

T002 -> T003, T005; T004 -> T005 -> T006, T007 -> T008; T009 after T002; T010-T013 last.
US1 is the MVP; US2 and US3 build on the state of US1.

## Parallel opportunities

T003 and T004 can be written in parallel (different files) once T002 exists.
