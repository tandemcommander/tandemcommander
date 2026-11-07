# Fix log - 407-find-sort-toggle

Backlog item `nefunkcni-prepinani-razeni-vysledku-hledani` (GitHub #23): Find - clicking a result
column again does not reverse the sort order.

## Measurement before (HEAD 1549e06a, Debug x64 build of HEAD)

- Sites: `LVN_COLUMNCLICK` -> `CFoundFilesListView::SortItems(subItem)` (`src/finddlg1.cpp`);
  `SortItems` always ascending, no state, `QuickSort` twice in the normal mode; `CompareFunc` puts
  folders first; no `HDF_SORTUP` / `HDF_SORTDOWN` anywhere in the core.
- Callers enumerated (Grep `SortItems(`): `LVN_COLUMNCLICK` (columns 0-4), `CM_FIND_NAME` / `PATH` /
  `TIME` / `SIZE` (View menu; the list's Ctrl+F3 / F4 / F5 / F6 post them), `OnHideDuplicateNames`
  (`finddlg2.cpp`, sorts by path to drop adjacent duplicates). The View menu items are disabled by
  the same duplicate-mode rule as `SortItems`'s guard (`CML_FIND_VIEW`).
- Reachable: Ctrl+F, Find, click a column header (default configuration).
- Probe `probe/find_sort_probe.ps1` (new; hidden desktop, 311's driver + 127's list-cell reader +
  an `HDM_GETITEMW` format reader). Fixture: folders dB (2008), dA (2014); files fC.txt (2006, 4 B),
  fA.txt (2010, 1 B), fD.txt (2012, 3 B), fB.txt (2016, 2 B) - name, date and size orders differ.
  First version of the fixture had name order = date order (could not prove step 1 sorted
  anything); renamed before the recorded run. Result `probe/result_before.txt`: 6 RUN rows FAIL,
  6 END rows PASS:
  - View > Date x3 -> `dB,dA,fC,fA,fD,fB` three times, no arrow (`------`);
  - Date header clicked twice -> the same; Size header twice -> ascending twice;
  - Find again after the sort -> no arrow (none ever); Attributes click -> nothing.
  - The reporter's "starts at 2015": the 2006 file comes after the 2008 and 2014 folders.
- The header click route is really driven by the probe: the first Size click re-sorted the list.

## speckit-analyze (one run, no CRITICAL / HIGH)

- C1 MEDIUM, accepted: duplicate mode (US3, FR-007) is covered by `saltests` (column rule, reversed
  duplicates key) and reading only - the probe does not drive *Find duplicates* (its options dialog).
- C2 LOW, accepted: the group shading (`SetDifferentByGroup`) is unchanged code called after the sort.
- D1 LOW: T012 / T013 overlap - harmless.

## Decisions (spec Clarifications)

Folders first in both directions, each group reversed (panel); every user route toggles; first
request ascending (panel options *newer on top* / *folders by name* not applied); Hide duplicate
names sorts by path ascending without toggling; a new search forgets the sort; duplicate mode's
allowed columns toggle with the whole duplicates key reversed; an empty list changes nothing.

## Implementation

- `src/common/salfindsort.h` (new, header-only): `CSalFindSortState`, `SalFindSortColumnAllowed`,
  `SalFindSortNext`, `SalFindSortNextKey` (the old tie-break chain), `SalFindSortOrder` (folders
  first in both directions, the rest negated when descending), `SalFindSortDirected`,
  `SalFindSortGroupedDirected` (Registry Editor), `SalFindSortHeaderFormat`.
- `src/find.h`, `src/finddlg1.cpp`: `CFoundFilesListView::SortState`; `SortItems(sortBy, toggle =
  TRUE)` - the allowed-column rule, nothing on an empty list, `SalFindSortNext`, one `QuickSort`
  (the second identical one removed), the direction into `CompareFunc` and
  `CompareDuplicatesFunc`; `UpdateSortArrows` (`HDM_GETITEMW` / `HDM_SETITEMW`, `HDI_FORMAT` only);
  `ResetSort` in `CFindDialog::StartSearch`; the View menu enabling uses the same rule
  (`FindSortColumnAllowed`).
- `src/finddlg2.cpp` `OnHideDuplicateNames`: `SortItems(SAL_FIND_COL_PATH, FALSE)`.
- `src/saltests/saltests.cpp`: `TestFindSort407` - the transitions, the allowed columns, the
  tie-break chains, the folder rule, the probe's fixture sorted all ways, every pair of 8 items x
  5 columns: ascending equals the comparison of 1549e06a (`OldCompare407`, copied), descending is
  its exact negation inside a group, folders first otherwise; the header bits.

## Findings fixed on the way (stop-rules rule 11)

1. **Registry Editor's Find window - the same defect** (severity 4, plug-in `regedt`, shipped `on`):
   `LVN_COLUMNCLICK` -> `SortItems` always ascending, no state, no arrow. Fixed the same way
   (`src/plugins/regedt/finddlg.h`, `finddlg.cpp`, `finddlg2.cpp`, `precomp.h`): `SortState`, the
   toggle, the arrows, `ResetSort` in `StartSearch`; its comparison groups keys before values for
   every column but Path - `SalFindSortGroupedDirected` keeps that grouping in the descending order
   and reverses everything else. The Data column stays unsortable (its old guard). New probe
   `probe/regedt_sort_probe.ps1`. Before = the feature's build with `main`'s three Find files put
   back (`git checkout main -- ...`, rebuilt, probe run, files restored and compared byte-exact with
   the saved diff): `probe/regedt_result_before.txt` 6 FAIL / 3 PASS (the second click keeps the
   order, no arrow). After: `probe/regedt_result_after.txt` 9 / 0.
   - The probe's own traps: the Data column takes the rest of the width, so the Size header was out
     of view and its click did nothing - the probe narrows Data to 60 px (LVM_SETCOLUMNWIDTH) after
     the first search; an expected order `$null` became `''` in a `[string]` parameter.
2. **Double `QuickSort`** in the normal mode (severity 1, wasted time only): removed.
3. **Feature 257's probe no longer drove** (severity 1, test tool): its Ctrl+Shift+G hot key for the
   Registry Editor's Find opened no window (0 of 8 rows driven at this HEAD, also before any change
   of this feature); probe 391 had already moved to Ctrl+Shift+J. 257's probe switched to J:
   `probe/regress_257.txt` 9 / 0.

## Checks

- Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Build: `.\build.cmd` -> `BUILD SUCCEEDED` (warnings only in the untouched `regedt\fs2.cpp`).
- saltests: 282,544 (HEAD, per 406's record) -> 282,601 checks, 0 failed.
- Negative control (T011): `SalFindSortNext` with `s.Descending = false` -> `saltests: 282595 checks,
  7 failed` (the toggle checks; build at that point had 282,595 checks), then restored and rebuilt
  -> 0 failed.
- clang-format (VS 2022 LLVM): the new lines match; the remaining differences of the touched files
  are on old lines.
- Probes (hidden desktop, Debug x64):
  - `find_sort_probe.ps1`: before 6 FAIL (`result_before.txt`) -> after 12 / 0 (`result_after.txt`).
  - `regedt_sort_probe.ps1`: before 6 FAIL -> after 9 / 0.
  - Regression: 311's `grep, grep-ctl, view-copy, view-copy-ctl` 8 / 0 (`regress_311.txt`); 257's
    9 / 0 (`regress_257.txt`).
  - Every run: registry restored and identical (SHA-256 B90B4B77...), fixture removed.
- Not driven by a probe: duplicate mode (*Find duplicates* opens an options dialog) - covered by
  `saltests` (allowed columns, reversed duplicates key) and by reading (C1 of the analysis).
- Translations: no UI string, menu or dialog changed - no `.slt` refresh needed.
