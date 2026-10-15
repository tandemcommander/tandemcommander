# Fix log: 209 - "Include subdirectories" lists a renamed folder's own contents

Found by the review of 207: the Renamer's `ReloadSourceFiles` (`src/plugins/renamer/rendlg.cpp`)
expands every folder item with "Include subdirectories" as `LoadSubdir(Root, item->Name)`. After
a rename the list shows the renamed items, and a renamed folder may lie elsewhere.

## Measured (before)

Probe `probe/ren_subdir_probe.ps1` (199's driver; the Renamer on a folder `x` holding `f.txt` and
`g.txt`, after the rename "Include subdirectories" ticked - `BM_CLICK` on 102 - and the preview's
rows counted; nothing more renamed), the build at 208:
- **full-sub** (full-path mode, `x` -> `<fixture>\tgt\drivers`; `probe/result_before.txt`):
  **"Unable to read directory. (5)"** - the Renamer empties its folder after a full-path run, and
  it read `drivers\*.*` relative to the current folder (System32): another folder's files could be
  offered for renaming;
- **rel-sub** (relative-path mode, `x` -> `sub\x`; the build without the fix,
  `probe/result_before_rel.txt`): **"Unable to read directory. (3)"** - it read `Root\x`; another
  folder `x` there would have been listed;
- name-sub (the control, file-name mode `x` -> `y`): 2 rows.
(The first runs of the probe failed on the probe itself: typing the folder into Change Directory
entered it, a closure did not see the count, the checkbox is not a direct child - all fixed.)

## Work

`rendlg.cpp` `ReloadSourceFiles`: a folder item is expanded from the folder where it IS - the
parent of its full name (a drive root "C:" made "C:\") - not from `Root`; a parent that does not
fit the buffer is refused as `LoadSubdir` refuses a long path (`IDS_TOOLONGPATH`).

Build: BUILD SUCCEEDED.

## Measured (after)

`probe/result_after.txt` 8 / 0: full-sub, rel-sub, sel-sub (added after the review: the panel's
selection with no rename - the common route, unchanged) and name-sub - 2 rows each (`f.txt`,
`g.txt`), no box. Regressions: 199's probe 6 / 0, 206's 10 / 0, 207's 8 / 0, 208's 12 / 0.

## Review

Refute-first review: accept - `LoadSubdir` takes its path only as a working buffer and gives each
item its absolute location; relative names come from `StripRoot` at display and expand time; the
original selection gets exactly the same full names as before (`C:\` and `\\srv\share\` forms
included); `Name` always lies inside `FullName`; UNC and `\\?\` parents list correctly; the
relative-path mode cannot be chosen once a full-path run emptied `Root`, and a relative rename
cannot leave `Root`; nothing else reads `Root` + `Name`. Taken: the defect was wider - after a
full-path run also the items that failed in it and the items after Undo have absolute names read
against the current folder; the fix covers them (by reading - those routes are not driven); the
control row sel-sub added. NITs recorded: `strcpy(pathBuf, Root)` is a dead store now; the refusal
for a full name without a folder says "too long" (unreachable); within one relative-path run a
renamed item whose parent folder is moved later keeps a stale full name (the list may show other
files than expected; a rename cannot be misdirected - real paths).
