# Closing report - 407-find-sort-toggle
Backlog item: nefunkcni-prepinani-razeni-vysledku-hledani - Find: clicking a result column again does not reverse the sort order
Outcome: closed

## What changed

- **Find's result list remembers its sort** (`CFoundFilesListView::SortState`, rules in
  `src/common/salfindsort.h`): a request on the same column reverses the order, another column
  starts ascending. Every route behaves alike - a header click, View > Name / Path / Date / Size and
  Ctrl+F3 / F4 / F5 / F6; *Hide duplicate names* sorts by path ascending and never toggles. Folders
  stay before files in both directions, each group reversed with its tie-break columns (the
  panel's rule). Duplicate mode keeps its allowed columns (the View menu now uses the same rule) and
  reverses its whole key, so each duplicate group stays together. The second, identical
  `QuickSort` of the normal mode is gone.
- **The header shows the sort arrow** (`HDF_SORTUP` / `HDF_SORTDOWN`, `UpdateSortArrows`). A new
  search clears it, and so do results that arrive after a sort.
- **The dark theme paints the arrow**: the program paints dark header items itself (features 044 /
  049). One shared painter `ThemePaintDarkHeaderItem` (`src/themes.cpp`) replaces the two copies
  and draws Windows' chevron in the label colour (`src/common/salsortarrow.h`). It is used by every
  dark list header, but only the two Find windows set the sort bits.
- **Found on the way (rule 11):**
  - The Registry Editor's Find window had the same defect. It now toggles, shows the arrow and
    resets at a new search; keys stay before values where its order groups them.
  - A refused Intersect / Subtract (an invalid regular expression) emptied the result list
    (upstream). `RestoreDataFromRefine` now gives the results back, with their order and arrow.
  - Feature 257's probe no longer drove: its Ctrl+Shift+G hot key no longer reaches the plug-in. It
    now uses Ctrl+Shift+J, as 391's probe does.
- Help: `basicwork_find.htm` and `finddlg_main.htm` describe the reversal, the arrow and the
  folder rule.

CHANGELOG entry (the tree has no `## [Unreleased]` section - for the maintainer to add with the
next release's section):

```text
- **Find: a second click on a result column did not reverse the sort order** (feature 407,
  GitHub #23). The Find window's results sorted every request ascending, so clicking the same
  column header again, View > Date or Ctrl+F5 seemed to do nothing, and no column showed how the
  list was sorted. Now the same column again reverses the order and another column starts
  ascending; the sorted column shows the sort arrow (also in the dark theme); directories stay
  before files in both directions, as in the panels; a new search forgets the sort. The Registry
  Editor's Find window sorts the same way. An Intersect or Subtract refused because of an invalid
  regular expression no longer empties the result list.
```

## Measurements (before / after, commands)

- Probe `probe/find_sort_probe.ps1` (hidden desktop, `tools\run_on_hidden_desktop.ps1`, Debug x64).
  - Before, at 1549e06a: 6 / 6 RUN rows FAIL (`result_before.txt`). The second sort keeps the order
    and there is never an arrow.
  - After: 22 / 0 (`result_after.txt`). The rows: menu-time, click-date, click-other, click-size,
    new-search, attr, click-path, dup, refused, pix-light, pix-dark.
  - Recorded before-runs of the added rows:
    - `result_pix_before.txt` - pix-dark FAIL, one picture for none / up / down;
    - `result_refused_before.txt` - the list is empty after the refused Intersect;
    - `result_negative_dup.txt` - the duplicates direction removed, dup FAIL.
- Probe `probe/regedt_sort_probe.ps1`.
  - Before (`main`'s three Find files put back): 6 FAIL (`regedt_result_before.txt`).
  - After: 12 / 0 in the light theme (`regedt_result_after.txt`) and 12 / 0 in the dark theme
    (`regedt_result_after_dark.txt`).
- Pictures: `probe/pix/` (dark chevron up and down, Registry Editor dark).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED`. No UI strings, menus or dialogs changed, so no `.slt`
  refresh was needed and `build.cmd full` was not required.
- saltests 282,544 -> 282,613 checks, 0 failed (`TestFindSort407`). The negative control (the
  toggle off) failed 7 checks.
- Regression probes: 311's in full 26 / 0 (`regress_311.txt`); 257's 9 / 0 (`regress_257.txt`).

## Reviews (findings and what was done)

- Review 1: no MUST; 2 SHOULD fixed (the duplicate-mode row, Path rows); NOTEs fixed (help text, the
  arrow of a refused Append).
- Review 2: 1 MUST - no sort arrow in the dark theme - fixed (shared painter + chevron + pixel
  probe rows). NOTE 1 fixed (the arrow is dropped when results arrive after a sort). NOTE 2
  (pre-existing: a refused refine emptied the list) fixed.
- Review 3: no MUST, no SHOULD. NOTE 1 fixed (the reset only after the search thread starts); NOTE 4
  fixed (the probe prints the box it answered); NOTE 2 (a refused refine loses the selection) and
  NOTE 3 (sorting during a running search, by reading only) accepted.

## Owed to a person (the lines added to the release checklist)

- One line added to `manual-checks-owed-before-the-next-release`: with a real mouse and keyboard,
  in the Default and Dark theme, Date clicked twice and Ctrl+F5 twice reverse the order and flip
  the arrow; Find again clears it; the Registry Editor's Find toggles too.
- Answer and close GitHub issue #23 - the draft is in `specs/407-find-sort-toggle/reply.md`.
- Add the CHANGELOG entry above with the next release's section.

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

1. The Registry Editor's Find window had the same defect (severity 4) - fixed, probe 6 FAIL -> 12 / 0.
2. A refused Intersect / Subtract emptied the result list (severity 3, upstream) - fixed, probe row
   `refused`.
3. The duplicated `QuickSort` (severity 1) - removed.
4. Feature 257's probe did not drive any more (severity 1, test tool) - now uses Ctrl+Shift+J, 9 / 0.

## New Inbox items (slug - title)

None.
