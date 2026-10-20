# Closing report - 266-close-stray-box
Backlog item: plugin-close-forced-unload-and-stray-box - Plug-in closing: forced Disk Map unload in a shell command, stray comparator box
Outcome: closed

## What changed

- File Comparator (`src/plugins/filecomp`): the main window's `WM_DESTROY` marks both file views
  `BeginClose()` first; the hex view's `WM_USER_HANDLEFILEERROR` returns at once when the mark is
  set - a file error pending when the window closes shows no box and no "close the comparison?"
  question. `CFileMapping::Destroy` resets `FileSize` to 0.
- Disk Map (`src/plugins/diskmap`): no behaviour change. A forced unload during a shell command
  still terminates the map's thread (the core's force semantics: `FreeLibrary` follows a forced
  `Release` whatever it returns; an unbounded wait freezes the main window; cancelling the shell's
  window reverses 143 FR-004). Documented at `KillAll` in `CPluginInterface::Release`, including
  the review's finding that a confirmed shell operation in progress is cut off too. The
  alternative is a decision item for the maintainer.
- `CHANGELOG.md` (0.1.11 - unreleased): entry for feature 266.

## Measurements (before / after, commands)

- Before (at `5eb288af`, code reading): `KillAll(TRUE)` on the force path; the hex view's error
  handler unguarded in the `WM_DESTROY` worker-wait pump; `Destroy` kept `FileSize`
  (`fix-log.md`, *Before*).
- Stray box: NOT DRIVEN - the pump runs only while a worker runs at close time and the error must
  be posted by the view's own paint in that window (research R2). Proven by code reading and the
  review.
- After: 143 probe `-Only E4,E5,E6` (hidden desktop) - PASS 7, FAIL 0, NOT DRIVEN 0, registry
  restored identical (`probe/result_143_E4-E6.txt`; E5 unchanged by decision: clean exit, file
  kept, Debug leak reports). 147 probe `-Only K1` - PASS 2, FAIL 0, registry restored identical
  (`probe/result_147_K1.txt`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd` (Debug x64): BUILD SUCCEEDED (also after the review fixes).
- `saltests.exe`: 24716 checks, 0 failed.
- Probes: as above (9 rows PASS, 0 FAIL).

## Reviews (findings and what was done)

One refute-first review, no MUST. SHOULD-1 (the forced termination also cuts off a confirmed
shell operation in progress - `InvokeCommand` without `CMIC_MASK_ASYNCOK`): the comment and the
decision item now say so. SHOULD-2 (a hex recompare can paint against the released sibling
mapping - pre-existing, not the close): Inbox item; comment and research reworded. NOTE-3/4
recorded (a view created from inside the closing wait lacks the mark; no run proves US1), NOTE-5
texts completed, NOTE-6 duplicate probe file removed. Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

Nothing to try by hand (the stray-box timing cannot be produced by a person either). The
maintainer owes a decision: `forced-disk-map-unload-in-a-shell-command-cancel-the-shell` (A keep the
termination - recommended / B cancel the shell's window, then wait).

## New Inbox items (slug - title)

- forced-disk-map-unload-in-a-shell-command-cancel-the-shell - Forced Disk Map unload in a shell command: cancel the shell window or terminate
- file-comparator-hex-recompare-error-box-from-the-released - File Comparator hex recompare: error box from the released sibling view
