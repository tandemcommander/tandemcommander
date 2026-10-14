# Fix log: 163 - a long name stays selected after a dialog; small identity leftovers

Backlog: `specs/NEXT-WORK.md` item 14 (queue 104, entry 2): "`UnselectItemWithName` (linguistic
comparison + byte-length guard), `CFindIgnore::Contains` relative kind, Undelete's `ViewFile`
disk-cache key dropping a long name" - "no loss scenario known".

## Measured first: a worse defect next to the first item

`UnselectItemWithName` is called after a command that selected the focused item for its time
(nothing selected: `SelectFocusedItemAndGetName`). Its comparison rarely matters - the exact name
still exists when it runs - but the name it compares was copied into `char[MAX_PATH]` by ten
callers and **cut** there (`fileswn0.cpp`, "len > nameMax"). A UTF-8 name of 260 bytes or more
(130 letters with a caron; a name may have 765) never matched: the item **stayed selected**.

`probe/temp_selection_probe.ps1` (hidden desktop, English UI): a folder with `a.dat` and a name
under test; the name focused, the command's dialog opened and cancelled, the focus moved to
`a.dat` (Home, Down), Delete (F8) - the question must name `a.dat` alone.

| Build | QREN / ATTR / CASE - LONG (284 bytes) | - SHORT (control) |
|-------|------------------------------------|-------------------|
| before (at 162) | FAIL: "Are you sure you want to delete file "čččč..."?" | PASS ("a.dat") |
| after | PASS ("a.dat") | PASS |

Before 9 / 3, after 12 / 0 (`probe/result_before.txt`, `result_after.txt`); the controls pass on
both - the probe is sensitive to the cut alone. Before the confirmation was set, the first runs
deleted without asking (the maintainer's "Use Recycle Bin For *.txt" sent the fixtures to the
Recycle Bin, the core then does not ask): the long-named file went, `a.dat` (then `a.txt`) stayed
- the defect does delete the wrong file. The nine fixture files the probe put in the Recycle Bin
(original location `%TEMP%\tc163\...`) were removed from it, nothing else; the probe now uses
`*.dat`, switches the Recycle Bin off and the confirmation on (registry restored at the end).

The fold itself, modelled (`CharLowerA` per byte on code page 1250, as `str.cpp` builds
`LowerCase`): U+010C/U+010D, U+00DA/U+00FA, U+0160/U+0161, U+017D/U+017E fold to DIFFERENT bytes
(missed), U+0125/U+0139 and U+011A/U+010A to the SAME bytes (another name). Find's ignore list
used that fold (`StrIStr`) for its relative kind: an entry "Účty" did not ignore "účty".

## Work

- `fileswnd.h`, `fileswn0.cpp`: `SelectFocusedItemAndGetName(CSalHeapString&)` - the whole name on
  the heap; low memory: the item is not selected at all (an item without its name would never be
  unselected - review). The ten callers (`fileswn5.cpp` ChangeAttr x1, RenameFile x2, plug-in
  Quick Rename; `fileswn7.cpp` Pack; `mainwnd3.cpp` Change Case, Email, Convert) keep a
  `CSalHeapString temporarySelected` and pass `.Text()`.
- `UnselectItemWithName`: `SalNameEqualOrdinalCI` (092), the exact name (length + bytes) first.
- `src/common/salfindignore.h` `SalFindIgnoreRelativeMatch`: the item ("\Name\", as Prepare makes
  it) at each backslash of the path by `SalPathHasPrefixOrdinalCI`, the matched length measured on
  the path (as the full kind); `find.cpp` uses it. saltests `TestFindIgnore163` (14 checks).
- `plugins/undelete/fs2.cpp` `ViewFile`: the disk-cache key in one `CSalHeapString::Printf` (it was
  `strcat` without bound and a `SalPathAppend` at an offset that ignored the pointer prefix, with
  a MAX_PATH bound - a long folder's name was dropped from the key); a key the disk cache cannot
  take gets its own message (`IDS_VIEWFILETOOLONGNAME`).

Build: BUILD SUCCEEDED; saltests 21,876 / 0; `check_encoding.py` TOTAL 0; clang-format on the
touched lines.

## Review

Independent refute-first review (read-only): nothing CRITICAL.
- SHOULD-FIX, taken: a failed `Copy` still selected the item with an empty name - the defect's
  state; now it is not selected.
- SHOULD-FIX, taken: the first version sized the Undelete key for a 765-byte name; FAT long names
  hold up to 819 UTF-16 units (114, `library/fat.h`) - such a key was refused silently. Now on the
  heap.
- Confirmed: lifetimes (Pack's backward `goto`s, RenameFile's retry re-uses the object - `Free`
  first), every early return still unselects, the CI fallback cannot unselect an item the user
  chose (nothing was selected; the dialogs are modal), Find equivalent for ASCII, the only caller
  passes a path ending in a backslash, the saltests byte sequences and expectations.
- NIT, accepted: `SalPathHasPrefixOrdinalCI` converts the rest of the path at every backslash
  (quadratic per directory, negligible). NIT: `saltests.cpp` LF / no BOM as at HEAD.

## Regression

On the build with the change (before the review fixes, which touch only the low-memory branch and
the Undelete key): 158 cs_overwrite 10 / 0 (Quick Rename), 103 samefile 46 / 0 / 8 NOT DRIVEN (as
before), 121 batch 30 / 0 (Find, FTP rows). On the final build: this probe 12 / 0, saltests
21,876 / 0, `check_encoding.py` TOTAL 0. The Recycle Bin holds no fixture of any of these runs.

## Owed to a person

None (the rows are driven).
