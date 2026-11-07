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

## Decisions (spec Clarifications)

Folders first in both directions, each group reversed (panel); every user route toggles; first
request ascending (panel options *newer on top* / *folders by name* not applied); Hide duplicate
names sorts by path ascending without toggling; a new search forgets the sort; duplicate mode's
allowed columns toggle with the whole duplicates key reversed; an empty list changes nothing.
