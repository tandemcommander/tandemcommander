# Fix log: 231 - selections restored by name in a case-sensitive folder

Backlog (230's review): `CFilesWindow::IsCaseSensitive()` returned FALSE for every disk panel, so the
name lists that restore a selection - Reselect, Store / Restore Selection, panel tabs, Hide
Selected Names - took "a.txt" and "A.txt" of a case-sensitive folder (fsutil setCaseSensitiveInfo,
WSL) for one name.

## Measured (before)

Probe `probe/resel231_probe.ps1` (a case-sensitive folder holding A.txt, a.txt, z.txt; the first
file selected with Insert; the result read through Change Attributes Hidden on the selection).
The build at 230 (`probe/result_before.txt`): **3 FAIL**:
- RESEL (Change Attributes with no change - the selection stored and cleared -, Reselect): **both
  twins selected** - the next command (F8, F6) would act on the file nobody selected;
- GLOBAL (Store Selection, Unselect All, Restore Selection): both selected;
- HIDE (Hide Selected Names): **both hidden** - the twin left the panel;
- CONTROL (a normal folder): as expected.

## Work

- `fileswnd.h` / `fileswn1.cpp`: a member `DiskDirCaseSensitive`, set in `ReadDirectory`
  (`fileswn3.cpp`) with `SalDirIsCaseSensitive(GetPath())` (feature 230) at every disk listing;
- `fileswn0.cpp` `IsCaseSensitive()`: for a disk panel it returns that member;
- `fileswn1.cpp` `RestoreGlobalSelection`: the stored (process-wide) or clipboard list is compared
  as this panel's folder compares names (`SetCaseSensitive` + `Sort` before matching). Changed: a
  clipboard list holding "readme.txt" no longer selects "README.txt" in a case-sensitive folder.

Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

## Measured (after)

`probe/result_after.txt` **8 / 0**: only the selected file is reselected / restored / hidden. The
negative control above is the final probe (with the HIDE row) on the build without 231.

## Review

Refute-first review: no MUST. Checked: the refresh merge's `caseSensitive` flag decides nothing
(its "equal" branch is byte-identical already - see S1 below); focus after a refresh becomes
exact in case-sensitive folders (better); `CNames` sorts and searches with the same rule; the
lists are cleared on a path change; the value is set before every disk listing. Cost: one open +
query per disk listing (no new kind of hang - `SetCurrentDirectory` and `FindFirstFile` touch the
folder first); a timed check on an SMB share is owed. NIT taken: a double sort removed. Recorded in
NEXT-WORK: **feature 004's tie-break in `CmpNameExtIgnCase` (`sort.cpp:262`) makes "Readme.txt" and
"README.txt" unequal - Compare Directories marks such a pair different in ordinary folders**; the
refresh merge walks twins in another order than the list is sorted (a selected A.txt beside a.txt
lost on refresh); remembered folder sizes are case-insensitive; the viewer's next / previous file,
the User Menu's compare names and Ctrl+X greying in the other panel take the first
case-insensitive twin.
