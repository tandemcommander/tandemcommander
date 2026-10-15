# Fix log: 234 - a User Menu command runs in its item's folder (also from the Find window)

Backlog (226's review): a User Menu command without an Initial Directory ran in the process-wide
current folder. The panel route sets it to the panel's folder first (wide since 226); the Find
window's route (`finddlg1.cpp` ~2788, its own thread) sets none - a relative `$(Name)` command ran in
the program's resting folder (System32) or, racing the main thread's `SetCurrentDirectory` calls, in
a panel's folder.

## Measured / driven

Probe `probe/um234_probe.ps1`: the Find window's User Menu is a popup menu loop (`menu.Track`) the
probe could not drive (FINDABS, the control with an absolute name, did not run either) - the Find
rows are **NOT DRIVEN** (a step owed to a person). PANELREL (the panel route) passes before and after;
226's probe 28 / 0 and 229's 34 / 0 after the change (`probe/regress_226.txt`, `regress_229.txt`).

## Work (`src/mainwnd4.cpp`, by reading)

- Direct route (ShellExecuteEx): `lpDirectory` = the Initial Directory, else the item's folder.
- Batch route: cmd.exe starts in the first item's folder (only without an Initial Directory, which
  the batch file's own `cd /d` line enters - a %VAR% typed there stays cmd's to expand); a later item
  in another folder gets its own `@cd /d "<folder>" || exit /b 1` line ('%' doubled); an item folder
  without a drive letter (UNC) that differs is refused - the command would run in the previous item's
  folder.
- The "same command for all items" rule runs the command again for an item in another folder (a
  command without variables, e.g. `git status`, on a Find selection from three folders).
- Panel batches stay byte for byte as before (every item's folder is the panel's).

Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

## Review

1. Refute-first review: **MUST, taken - a batch with Find items from several folders ran items 2..n
   in the first item's folder** (worse than before: a user folder, duplicates by design); the
   per-item `cd` lines. Recorded (NEXT-WORK): a UNC folder in the batch route (cmd falls back to the
   Windows folder; a UNC Initial Directory writes no `cd`); `$(ListOfSelectedNames)` from several
   folders runs once in the first one; a missing folder's message names the command, not the folder;
   a `.lnk` command's own "Start in" vs `lpDirectory`.
2. Second review: **MUST, taken - a UNC item folder got no `cd` line** and ran in the previous item's
   folder: refused now. SHOULD taken: cmd's start folder only without an Initial Directory (a stale
   first item no longer stops a command that would `cd` elsewhere); the "same command" rule per
   folder. NIT taken: a folder whose escaped form does not fit is refused, not skipped.
