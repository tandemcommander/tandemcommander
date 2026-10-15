# Fix log: 197 - deleting a junction in a very deep folder deletes only the link

Found while reading the backlog item "a junction / symlink in a folder of 260+ bytes is not
recognised by *Go to Shortcut Target*" (182's review): the same function decides, in the delete
script, whether a reparse directory is removed as a link or emptied like a folder.

## Measured (before)

Probe `probe/deepjunc_probe.ps1` (Recycle Bin off - `Use Recycle Bin` 0 - unless said; a junction
`J` made with `mklink /J` in the `\\?\` form, its target a folder `tN` holding `precious.txt`; F8,
every box answered Yes), the fix stashed and built (`probe/result_before.txt`, 9 / 3):
- SHALLOW (41 characters) and DEEP (283): "delete junction J?" - only the link removed - PASS;
- **DEEP2 (874 characters): "Are you sure you want to delete directory "J"?" and the target's
  `precious.txt` deleted** - the junction was emptied like a folder;
- **DEEPTREE (F8 on a deep folder that holds the junction): the target's file deleted** - the
  recursion met the junction the same way;
- DEEP2-RB (the Recycle Bin on): "Cannot finish operation because of too long name." - nothing
  deleted (the shell's route refuses);
- FOCUS (*Go to Shortcut Target* on a deep junction): "Cannot get link target."

Cause: `fileswn6.cpp` `BuildScriptDir` took a reparse directory for a link (`ocDeleteDirLink`, the
link removed) only when `GetReparsePointDestination` succeeded; that function converted the path
into `WCHAR[3 * MAX_PATH]` and failed past it - so the delete descended into the junction and
deleted what it points at. Paths of 260-780 characters worked (the program is long-path aware).

## Work

- `src/salamdr2.cpp` `GetReparsePointDestination`: the path of any length (from MAX_PATH units on
  in the `\\?\` form). New `GetReparsePointTag` (the tag through a handle opened on the link
  itself, any length) and `DeleteAsDirLink`: a reparse directory is deleted as a link when it is a
  mount point / junction / symbolic link, when its tag is any other name surrogate, **or when the
  tag cannot be read** (fail closed - the link's delete refuses a tag it does not know); only a
  readable tag that is not a link (a cloud placeholder, 062 C3) makes it a plain directory.
- `src/common/salreparse.h` (new, header-only): `SalDeleteAsDirLinkDecision`, the rule above;
  saltests `TestDeleteAsDirLink197` (9 checks).
- `src/fileswn6.cpp` `BuildScriptDir`: the delete decides by `DeleteAsDirLink`.
- `src/fileswn8.cpp`: the delete question checks the link on the whole path (a folder over
  MAX_PATH + 200 bytes was cut there - the question said "directory").
- `src/fileswn0.cpp` `FocusShortcutTarget`: no MAX_PATH guard; the target on the heap (the
  original backlog item).

Build: BUILD SUCCEEDED; saltests 22,370 / 0; `check_encoding.py` TOTAL 0.

## Measured (after)

`probe/result_after.txt` 12 / 0: DEEP2 and DEEPTREE remove the link only (the question says
"junction"), the target's file kept; DEEP2-RB refused as before (safe); FOCUS goes to the target.
Regressions: 103's `samefile_probe -Expect103` 46 / 0, 099's `linkmove_probe` 24 / 0. After the
review's changes the same: 12 / 0, 46 / 0, 24 / 0.

## Review

Refute-first review: sound - no delete route left that descends through a link at any depth:
`BuildScriptDir` decides at every level of the tree and `fileswn6.cpp` ~1953 is the only place;
Move and the move into an archive decide by the attribute (the content copied, the link removed);
the Recycle Bin and the Find window's delete go through the shell (no traversal; a long folder is
refused); the worker has no recursion of its own and its link delete re-reads the tag. Short paths
take the unchanged route; long ones the `\\?\` form (trailing space / dot kept, `.` / `..` folded
as Win32 does); every failure resolves to "the link only, or refuse". Taken: SHOULD-FIX 1 - the
link's names were copied into `WCHAR[1000]` (a longer target opened a cut path): on the heap,
whole; SHOULD-FIX 2 - a destination whose UTF-8 form did not fit fell back to the code page
(code-page bytes to UTF-8 consumers): refused now; NIT 1 - plain statements in `fileswn8.cpp`; NIT
3 - the declarations after the old function's comment; NIT 4 - the rule as a header with saltests.
Recorded (NIT 2): for a surrogate or unreadable tag the question says "directory" while only the
link removal is attempted - wrong in the safe direction. Recorded in NEXT-WORK (older, outside the
delete): Change Attributes and Change Case with subfolders descend into every junction (the
target's files change, nothing is lost); `_RemoveTemporaryDir` has no reparse check (no route
creates a junction there); not driven: a deep directory symbolic link, the delete by Recycle Bin
masks, a cloud placeholder past 780 characters; a race between building the script and running
it (a folder replaced by a junction meanwhile) - as before.
