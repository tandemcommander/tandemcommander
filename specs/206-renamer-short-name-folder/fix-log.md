# Fix log: 206 - The Renamer's new folders: no stack overrun, never into another folder by its short name

Backlog (left by 199's second review): the Renamer's `CheckAndCreateDirectory`
(`src/plugins/renamer/rendlg3.cpp`, the "adjust the case" step of a new name with folder parts)
renames a folder whose SHORT name is a folder part of the new name (`LONGDI~1\x.txt`) to that
short name.

## Measured (before)

Probe `probe/ren_dir83_probe.ps1` (199's driver; the Renamer in relative-path mode - command 608 -
so that a new name may hold folders; short names are made on C:), the build at 205:
- ren-dir83 (a folder `longdirname`, new name `LONGDI~1\x.txt`; `probe/result_before.txt`): **the
  backlog premise does not hold on NTFS** - the folder keeps its name (renaming it to its own short
  name is a no-op) and `x.txt` goes INTO `longdirname`, through the short name. (FAT not measured:
  there the rename may drop the long name.)
- **ren-dir83-long** (the same with a folder of a 230-letter name typed by its short name
  `LLLLLL~1`; `probe/result_before_long.txt`): **"Run-Time Check Failure #2 - Stack around the
  variable 'old' was corrupted"** - the step copies the found long name into `char old[MAX_PATH]`
  behind the path: a stack overrun (Release: a crash or a corrupted stack).
- **ren-dir83-same** (added after the first review: an `x.txt` already in `longdirname`; the build
  without the fix, `probe/result_before_same.txt`): **"Confirm File Overwrite"** for the typed path,
  and Yes **replaced `longdirname\x.txt`** (its content `PRECIOUS-X` lost); ren-dir83-held (a file
  in `longdirname` held open): "Unable to modify case of the directory name: (5)" and the file went
  into `longdirname` all the same.
- ren-case (the control: a folder `Sub`, new name `SUB\x.txt`): the folder becomes `SUB`, `x.txt`
  in it - the step's purpose.

## Work

`src/plugins/renamer/rendlg3.cpp`, `rendlg2.cpp`, `utils.h`:
- the case is adjusted only when the typed component and the found name are one name by the file
  system's rule (`SalNameOrderEqualCI`, 092) spelled otherwise; the old name is on the heap at its
  real size, freed on every way out;
- in the relative-path mode, below the Renamer's folder (`PathBelowRoot`; not while undoing - its
  paths are the sources' old ones), a folder component proven to be only ANOTHER folder's short name
  (`SplPathIsOnlyShortNameOfOther`, 205) is a folder of its own: `CheckAndCreateDirectory` creates
  it, and the create goes through the core's `SalCreateDirectoryEx` (the other entry moved aside and
  back, 203) instead of `CreateDirectoryU8`; `BuildScript` does not take such a target for an
  existing file (`FolderPartIsShortNameOfOther`) - as the leaf (199) and an archive's folder (204).

Build: BUILD SUCCEEDED.

## Measured (after)

`probe/result_after.txt` 10 / 0: ren-dir83 - a folder `LONGDI~1` of its own holds `x.txt`,
`longdirname` holds only `keep.txt`; ren-dir83-same - no question, `longdirname\x.txt` keeps
`PRECIOUS-X`, the own `LONGDI~1\x.txt` holds the moved file; ren-dir83-held - "Unable to create
directory: (5)", nothing moved, `x.txt` where it was; ren-dir83-long - no failure, an own
`LLLLLL~1` holds `x.txt`; ren-case - `SUB` as before. Regressions: 199's probe 6 / 0, 196's 8 / 0.

## Review

First refute-first review: the heap fix correct (sized from the found name - case pairs can differ
in UTF-8 length; freed on all three exits; a failed conversion now skips the step instead of
renaming `prefix\`); the Undo of a rename no longer tries to rename an 8.3 ancestor of the
original path. Taken: the short-name policy (it contradicted 199 / 204 and left 204's defect in
the Renamer - measured above). Recorded as **feature 207** (CRITICAL, before 206): `MoveFile`'s
`char dir[MAX_PATH]` + `strcpy(targetName)` overruns on Undo of a selected item whose path is
>= 260 bytes of UTF-8 (90 CJK letters: 98 UTF-16 units, an ordinary path), and
`rendlg2.cpp` ~567 the same with "Remove source path"; `LoadSelection` does not refuse such items
as `LoadSubdir` does. NITs recorded: a file `sub` found for a typed folder `SUB` is renamed before
the move fails (Undo restores it); `*end = '\\'` after the last component overwrites the
terminator (unused); `editor.cpp` ~423 takes a "buffer too small" `GetShortPathNameW` result;
`preview.cpp` ~267 `lstrcpyn(..., MAX_PATH)` can cut a character (display only); `rendlg.cpp`
~1147 `GetPanelPath`'s result unchecked.

Second refute-first review (of the policy): accepted - the jump to the creating loop keeps
`start` / `end` consistent; the Undo of such a rename moves the file back out of the own folder
and removes that folder, never `longdirname` (whose short name became LONGDI~2 - for good, 203's
nature); a second file of the batch to `LONGDI~1\y.txt` lands in the own folder (it has no
alternate name); two spellings are now two folders also for the duplicate / depending-name checks
(before, `LONGDI~1\x.txt` could resolve to ANOTHER rename's source and offer it for overwriting);
`SalCreateDirectoryEx` reports the clash's reason through `FileError`. Taken: (1) `PathBelowRoot`
read up to the root's length of a shorter path (a heap over-read with a full-path new name) - now
checked first; (2) in the full-path mode the guard depended on what the panel showed (and Root is
emptied after a full-path run) - **decision: the rule holds in the relative-path mode only**; a full
path is the user's own, a typed short name keeps resolving (as 204's typed target; the overwrite
question there names the typed path). Re-measured 10 / 0, 199's 6 / 0. NITs recorded: Undo not
driven by the probe; a file A to `LONGDI~1\a.txt` and a folder `longdirname` renamed to `LONGDI~1`
in one batch - the second fails "directory exists" (nothing lost); a server that resolves short
names without reporting them keeps the old handling (the overwrite question is asked); the case
step looks the alias up twice; the held-folder message does not name the other folder (as 203).
