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
- Duplicate mode: first recorded here as "not driven, covered by saltests" - review 1 showed that
  claim was too strong (saltests checks only the sign rule, not `CompareDuplicatesFunc`) and that
  the options dialog can be answered; the probe now has the `dup` row (see *Review*).
- Translations: no UI string, menu or dialog changed - no `.slt` refresh needed.

## Review

### Review 1 (refute-first agent, no MUST)

Re-ran build, saltests (282,601 / 0), encoding guard, both probes (12 / 0, 9 / 0); enumerated the
callers (`LVN_COLUMNCLICK`, `CM_FIND_NAME/PATH/TIME/SIZE` and the list keys, `OnHideDuplicateNames`,
the Registry Editor's `LVN_COLUMNCLICK`); compiled copies of the three comparators against the real
header: strict weak orders in both directions on 26 random items, 0 problems (its negative control
with `SalFindSortDirected` instead of `SalFindSortGroupedDirected`: 1,650 problems); drove *Find
duplicates* on the hidden desktop with a scratch probe, 8 / 8.

- SHOULD 1 - the duplicate-mode claim was weaker than the fix-log said; removing
  `SalFindSortDirected` from `CompareDuplicatesFunc` failed no check. **Fixed**: the reviewer's
  scratch probe became the `dup` row of `find_sort_probe.ps1` (fixture `%TEMP%\tcfsort\dup`).
  Negative control: that call replaced by `return res;`, rebuilt, `-Only dup` ->
  `probe/result_negative_dup.txt` FAIL (step 2 keeps `x@s1,...`), source restored and rebuilt.
- SHOULD 2 - no Path row in either probe. **Fixed**: `click-path` (core: Path up, down - folders
  first, names reversed - and View > Path up again) and `PATH-1` / `PATH-2` (Registry Editor: the
  exact reverse, values before keys, as its Path never grouped keys).
- NOTE help text - **fixed**: `help/src/hh/salamand/basicwork_find.htm`, `finddlg_main.htm` say
  that sorting by the same column again reverses the order, the arrow, folders first.
- NOTE an Append refused by an invalid regular expression cleared the arrow of a list that kept
  its sorted order - **fixed**: `StartSearch` resets at once except for an Append, and again just
  before the search starts (after the checks that may refuse it).
- NOTE CHANGELOG / FEATURE-HISTORY - done at closing (step 8).
- NOTE first Name click after a search may only add the arrow; Date then Time keeps the order -
  by the spec's rules, no change.
- NOTE a held Ctrl+F3..F6 now flips the order on each auto-repeat - accepted (each press is a
  request; the panel's Ctrl+F3 behaves the same).

After the fixes: `.\build.cmd` BUILD SUCCEEDED; saltests 282,601 / 0; encoding guard TOTAL 0;
`find_sort_probe.ps1` 16 / 0 (`result_after.txt`, rows + click-path + dup);
`regedt_sort_probe.ps1` 11 / 0 (`regedt_result_after.txt`).

### Review 2 (refute-first agent, 1 MUST)

Re-ran saltests (282,601 / 0), encoding guard, both probes (16 / 0, 11 / 0); enumerated the callers
again (including the View menu enabling and the three resets); checked review 1's fixes.

- **MUST 1 - no sort arrow in the dark theme** (FR-004, SC-002, the new help sentence). The dark
  header items are painted by the program - the Find list's own `NM_CUSTOMDRAW` (feature 044) and
  `ThemeListViewHeaderSubclassProc` (feature 049, also used by the plug-ins' dialogs through
  `ThemeApplyToDialog`) - which return `CDRF_SKIPDEFAULT` after the background and the label, so
  Windows never drew the arrow the format bits asked for. The probes read only the bits. The
  reviewer's pixel row (PrintWindow of the header, a hash) showed one picture for none / up / down.
  **Fixed**: one painter `ThemePaintDarkHeaderItem` (`src/themes.cpp`, declared in `themes.h`)
  replaces the two copies; it draws the arrow as Windows does in the light theme - a chevron at the
  top centre, in the label colour - with the geometry rule `SalSortArrowChevron`
  (`src/common/salsortarrow.h`, saltests 12 checks: centred, apex up / down, at least k = 3, from the
  item's top, refused when too narrow or too low). Probe rows `pix-light` / `pix-dark` in
  `find_sort_probe.ps1` (from the reviewer's scratch row) and the `PIX` row and `-Dark` switch of
  `regedt_sort_probe.ps1`. Before (the build of 7bd0f8bb): `probe/result_pix_before.txt` - pix-dark
  FAIL, `97F0A18457397AAE` three times; after: `probe/result_pix_after.txt` / `result_after.txt`
  PASS (three hashes), the PNGs in `probe/pix/` show the chevron (`pix_dark_1up.png`,
  `pix_dark_2down.png`, `regedt_dark_NAME-2.png`). Probe trap: PowerShell passes `$null` to a C#
  `string` as `""` - `Bitmap.Save("")` threw ("the path has an invalid form"); the helpers test
  `IsNullOrEmpty`.
- NOTE 1 - sorting while the search still runs: new results were appended under an arrow claiming
  an order the list no longer had, and the next click reversed. **Fixed**: `UpdateListViewItems`
  (core and Registry Editor) forgets the sort when the list grows (`count > FoundVisibleCount`) - the
  next request sorts ascending, as before 407. By reading only (a search slow enough to sort during
  it is not driven); the probes' rows that sort after a finished search are unchanged (22 / 0).
- NOTE 2 - existing, outside 407: an Intersect / Subtract refused by an invalid regular expression
  (or a thread that did not start) had already moved the results to the refine array and then
  destroyed them - the result list was emptied (files untouched). Severity 3, met on the way:
  **fixed** (stop-rules rule 11): `CFoundFilesListView::RestoreDataFromRefine` gives them back
  (out of memory: dropped as before, never owned twice), the list keeps its order and its arrow;
  `StartSearch` resets the sort at once only for Find / Find duplicates (the commands that empty the
  list), Intersect / Subtract / Append only when their search really starts. Probe row `refused`:
  before (the build without the restore) `probe/result_refused_before.txt` FAIL - the list empty after
  the refused Intersect; after: PASS - Intersect, Subtract and Append refused, the six items, the
  order and the arrow kept.

After the fixes: `.\build.cmd` BUILD SUCCEEDED; saltests 282,613 / 0; encoding guard TOTAL 0;
`find_sort_probe.ps1` 22 / 0 (`result_after.txt`); `regedt_sort_probe.ps1` 12 / 0 light
(`regedt_result_after.txt`) and 12 / 0 dark (`regedt_result_after_dark.txt`); regression: 311's
probe in full 26 / 0 (`regress_311.txt`), 257's 9 / 0 (`regress_257.txt`).
