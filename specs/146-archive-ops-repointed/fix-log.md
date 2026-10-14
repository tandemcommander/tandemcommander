# Fix log: 146 - no archive operation through a name that leads elsewhere than when it was listed

Backlog: `specs/NEXT-WORK.md` 2b (found by the review of 145).

## Before (`probe/result_pre146.txt`, `Debug_x64` at `1d78c2fe`)

109 probe, new op `delete` (F8 on x.txt) and case `resubst-delete`: a panel on `T:\arc.zip` (A),
the letter re-pointed to B (a twin), F8 on x.txt, confirmation Yes: **B's x.txt deleted** (B's
archive has no member left); A unchanged. FAIL.

## Work (final form, after the review)

- `CFilesWindowAncestor::ShowsArchiveThatMoved(name)`; `CFilesWindow::RefuseOperationIfArchiveMoved(
  parent, name)` (fileswn1.cpp) - the ACTING panel only: when its archive's name leads elsewhere,
  the existing `IDS_ARCHIVEREFRESHEDIT` note (not when edits are pending: the refresh shows it) and
  `WM_USER_REFRESH_DIR` with a fresh time (the idiom of `OfferArchiveUpdateIfNeeded`), TRUE.
- Called right before the archive is touched: before `PackUncompress` and `PackDelFromArc` in
  `UnpackZIPArchive` (after the questions), before both `PackUnpackOneFile` (F3 / F4 / Enter,
  `fileswn5.cpp`, `fileswn6.cpp` - as a failed unpack: the cache name is released), before packing
  into the target panel's archive in `FilesAction` (with 119's cleanup), in the paste / drop route
  (`fileswna.cpp`) and in `CSalShExtPastedData::DoPasteOperation` (`salshlib.cpp`).

## After

- Debug build clean; `saltests` 21,829 / 0; `check_encoding.py` TOTAL 0.
- `probe/result_case.txt`: `resubst-delete` **PASS** - the note "Archive file "T:\arc.zip" has
  changed. Archive will be reopened in panel.", both archives keep x.txt.

## Review (refute-first agent, 2026-10-14)

No critical finding. Taken over:

- MEDIUM: F3 / F4 / Enter unpacked a member through the moved name with no check - re-point,
  F4, point back, leave: A's member replaced by B's content + the edit (measured with the build
  without the guard: `probe/result_pre146_f4.txt`, case `resubst-f4back`). Guarded.
- MEDIUM: the check ran before the confirmation questions (minutes) - moved right before the
  archive is touched; also no wait before the confirmation on a slow share, and F8 on `..` no
  longer shows the note.
- LOW: both panels were checked - the acting panel only now (a reopened panel was refused
  because the other one was stale, and the wrong one was refreshed).
- LOW: the refresh was a posted `CM_*REFRESH` (which zeroes the stop counters) - now
  `WM_USER_REFRESH_DIR`.
- LOW: the note twice with edits pending - shown only when none are.
- Recorded: a paste of items copied from an archive whose panel left it or was already reopened
  onto the other archive (copy out only, nothing changes); the check falls open where
  `GetFinalPathNameByHandle` is not supported (only the volume serial remains); NIT: the note
  does not say the operation was not done (needs a string).

## Final

- `saltests` 21,829 / 0; `check_encoding.py` TOTAL 0.
- `probe/result_case.txt`: `resubst-delete`, `resubst-f4back` **2 PASS / 0 FAIL** (controls: FAIL).
- `probe/result_109.txt`: the whole 109 probe **25 PASS / 0 FAIL / 0 NOT DRIVEN**.
- Regressions: 108 30 / 0, `-CacheKeyRows` 2 / 0, 112 14 / 0.
