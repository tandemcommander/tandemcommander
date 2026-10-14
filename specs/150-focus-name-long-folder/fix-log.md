# Fix log: 150 - FocusNameInPanel keeps a long folder whole

Backlog: `specs/NEXT-WORK.md` 5a (149's review).

## Before (`probe/result_pre150.txt`, `Debug_x64` at `08f0b2f6`)

Probe `probe/focus_long_folder_probe.ps1` (infrastructure of the 149 probe), row F1: a list line for
`deep\<3 x 180 characters>\target.bin` (the folder has 589 bytes), Verify, Home on the list, Focus:
**"Error Changing Directory"** with the path cut at byte 459; the panel stayed in the list's folder.

## Work

- `src/zip.cpp` `CSalamanderGeneral::FocusNameInPanel`: whole `CSalHeapString` copies of the path and
  the name instead of `lstrcpyn` into `MAX_PATH + 200`; a name of `SAL_FIND_NAME_U8` bytes or more is
  refused (TRACE) - the handler copies it into `NextFocusName[SAL_FIND_NAME_U8]` and the old cut had
  kept it short (found by reading before the review).

## After

- Debug build clean; `saltests` 21,842 / 0; `check_encoding.py` TOTAL 0.
- `probe/result.txt`: F1 **PASS** - the panel at the whole 589-byte folder, no box.
- 149 probe 2 / 0.

## Review (refute-first agent, 2026-10-14; second round on the routes below)

The fix holds. The same cut found elsewhere and fixed here (all "Focus cuts a path"):

- MEDIUM: `CMainWindow::PostFocusNameInPanel` (`mainwnd4.cpp`) - the Focus button of the core's
  "name is too long" boxes (they appear exactly for long paths; since 141 also for a long mask
  result): static buffers of the panel's limits (`SAL_MAX_PATH_UTF8`, `SAL_FIND_NAME_U8`, the
  message is posted), refused when either does not fit.
- PictView: `Focus_Path` 3 x MAX_PATH (was MAX_PATH and cut), refused with its existing
  `IDS_TOOLONGNAME` beyond; `CMD_INTERNAL_FOCUS`'s copy as large.
- The Plugins and Shares dialogs' Focus: whole `CSalHeapString` copies (`lstrcpyn` into
  `MAX_PATH`; the Plugins dialog's source is `MAX_PATH` itself - no change in practice).
- Recorded (`specs/NEXT-WORK.md`): the Plugins dialog builds the plug-in's path with
  `GetModuleFileName` (A) and an unbounded `strcat` into `MAX_PATH` (`dialogs5.cpp`, older).

## Final

- `saltests` 21,842 / 0; `check_encoding.py` TOTAL 0; 150 probe 2 / 0; 149 probe 2 / 0; PictView
  120 probe 20 / 0 / 2. The other Focus routes by reading (no probe drives a too-long box's
  Focus, PictView's Focus of a long picture path, or the Shares dialog).
