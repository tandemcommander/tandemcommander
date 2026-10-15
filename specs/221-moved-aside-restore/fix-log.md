# Fix log: 221 - an entry moved aside for an 8.3 name clash is moved back, or the user is told

Backlog (left by 203, `specs/NEXT-WORK.md`): "the other entry can be left under `salNNN` with only
a trace when both restores fail (Quick Rename, the worker's move, the create paths)".

## Read (not driven)

When a rename, a move or a create hits another entry's 8.3 short name, that entry is moved aside
to `salNNN`, the operation done, and the entry moved back. A failed move-back (another process -
a scanner, an indexer - holding the entry for a moment; or Windows having made the long name
itself) was a trace only: the user's file stayed renamed to `salNNN`, nothing said. Not driven:
the failure is a race (held between two moves of the same operation).

## Work

- `src/common/salfileio.cpp` / `.h` `SalMoveFileBack`: the move back tried for about a second
  (10 x 100 ms while the error is a sharing / lock violation or access denied); the last error kept;
- every move-back uses it: Quick Rename (`fileswn5.cpp`), the worker's move (`worker.cpp`
  `DoMoveFile`), the create paths (`SalCreateFileEx`, `SalCreateDirectoryEx` in `worker.cpp`,
  `SafeFileCreate` in `safefile.cpp`);
- Quick Rename and (review) the worker's move say when the entry stays under the temporary name:
  "Path: "...\salNNN"\nError: reason" (the existing `IDS_PATHERRORFORMAT`, title "Error Renaming
  File"; the worker through its progress dialog's error box, `WM_USER_DIALOG` 5); (review) after
  the operation was undone the reported reason is the move-back's, not "already exists".

Build: BUILD SUCCEEDED. Regression (the successful move-aside routes): 201's probe 6 / 0, 203's
probe 14 / 0 (`probe/regress_*.txt`).

## Review

Refute-first review: acceptable, no MUST. The wait (up to about 2 s, only on the failure path) is
acceptable - the worker already retries sharing violations; access denied is not permanent there
(the move aside just succeeded with the same rights; read-only is handled by `SalMoveFile`); the
last error is kept through every layer; the Quick Rename message shows exactly when the entry
stays aside, in UTF-8, the path never cut. Taken: the worker's report, the reason after an undo.
Kept: when the operation itself failed too, Quick Rename shows two boxes (the entry left aside,
then the operation's error); the box names `salNNN`, not the entry's own name (the existing string
has one path). Recorded in `specs/NEXT-WORK.md`: the create paths have no window - they still only
trace (an out parameter would be needed); PictView's and the Renamer's move-back (they do report)
have no retry (`SalMoveFile` through the plug-in interface - a local loop each).
