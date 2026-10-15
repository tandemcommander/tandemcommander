# Fix log: 203 - Copying or unpacking to another file's short name never overwrites it

Found by the review of 201: the create paths have the fallback 201 closed in Rename and Move - a
new file or folder whose name is only the short (8.3) name of another entry moves that entry
aside, and when that fails (held open) they report "it exists", which the callers take for the
target itself.

## Measured (before)

Probe `probe/create_clash_probe.ps1` (158's driver; short names are made on C:), run with
`-Expect103` so that the boxes count. The build at 202 (`probe/result_before.txt`, 6 / 2):
- cp-free / dir-free (the controls): F5 of `LONGFI~1.TXT` (a folder `LONGDI~1`) next to
  `longfilename.txt` (`longdirname`): the copy lands as its own entry, the other one kept;
- **cp-held** (`longfilename.txt` held open, share read+write, no delete): **"Confirm File
  Overwrite"** for the other file; Yes failed only on the handle ("Error Deleting File (32)");
- **dir-held** (a file inside `longdirname` held open, so it cannot be renamed): **no question at
  all - the copied folder was merged INTO `longdirname`** (`a.txt` written there).

The ZIP rows, measured after the core fix and before the `SafeFileCreate` one
(`probe/result_before_zip.txt`, 4 / 2):
- zip-free (the control): the member `LONGFI~1.TXT` lands as its own file;
- **zip-held**: "Confirm File Overwrite" for the other file, and Yes **replaced its content with the
  member's** (`PRECIOUS-4` lost - the open handle shared writing);
- **zip-dir** (a member `LONGDI~1/a.txt` next to the folder `longdirname`, nothing held): the file
  unpacked into `longdirname` - the folder part of the path resolves through the short name. This
  is not the fallback of this feature (no move aside is tried for a path's folders, in the core's
  `CheckAndCreateDirectory` nor in `SafeFileCreate`) - feature 204.

## Work

- `src/common/salshortname.h` `SalShortNameClashError` (saltests, 7 checks), used by
  `src/worker.cpp` and `src/safefile.cpp`: after a DOS-name-only clash whose work-around did not
  help, `SalCreateFileEx` and `SalCreateDirectoryEx` report the step's own error (moving aside, the
  create, the restore), never "it exists" (nor success - both mapped to "access denied"); the
  restore of the other entry is retried also when the create failed.
- `src/safefile.cpp` `SafeFileCreate` (archive plug-ins): the same clash at any length (heap
  buffers; the MAX_PATH guard sent a long path's clash to the overwrite question); a failed
  work-around shows the create error (Retry / Skip / Skip all / Cancel, `SILENT_SKIP_FILE_CREATE`),
  never the overwrite question for the other file.

Build: BUILD SUCCEEDED.

## Measured (after)

`probe/result_after.txt` 12 / 0: cp-held - "Error Opening File (32)"; dir-held - "Error Creating
Directory (5)", nothing written into `longdirname`; zip-held - "Error Creating File (32)",
`longfilename.txt` keeps its content; the controls as before. Regressions (the core part): 201's
probe 6 / 0, 158's 10 / 0, 103's 46 / 0 (8 not driven, as before).

## Review

Refute-first review: sound for what it changes, no regression - F5's `CREATE_ERROR` takes only the
two "exists" codes for an overwrite (32 / 5 go to the Retry / Skip box, Retry back to the create);
the write-only retry and the encryption-not-supported route unchanged; `DoCreateDir`'s Skip leaves
the whole subtree out; F7 and Edit New (`fileswn5.cpp` ~1605, which offered editing the other
file) show the error; `SafeFileCreate`'s `continue` re-checks from the start and never loops
without a Retry, no handle open, the heap buffers freed on every way out; the restore retry can
only put `salNNN` back (`SalMoveFile` never replaces); the clash test cannot misfire on a FAT name
whose short name differs only by case. Taken: the mapping duplicated inline without a test - now
`salshortname.h` with saltests checks (22,377), re-measured 12 / 0. **SHOULD-FIX recorded as feature
205** (the fix does not reach them): the FTP plug-in turns the new error back into "exists" by its
own `SalGetFileAttributes` re-check (`operats5.cpp` ~1056-1074, ~1317-1338) - a downloaded folder
merged into the other folder (the default "join"), the other file offered for overwrite / resume;
the SFTP plug-in (on by default) has no work-around at all (`operats.cpp` ~532-560, ~840-848) -
nothing needs to be held. NITs recorded: the error text does not say the name is another entry's
short name; a folder clash in `SafeFileCreate` now falls under `SILENT_SKIP_FILE_CREATE` instead of
`SILENT_SKIP_FILE_NAMEUSED`; `SalCreateDirectoryEx`'s low-memory case traces "name too long"; both
restores failing leaves the other entry under `salNNN` with a trace only (recorded before).
