# Fix log: 173 - the viewer's Copy to File replaces an existing file in one step

Backlog: NEXT-WORK item 5c (found by 172's review): the viewer's Copy to File overwrote an
existing file by deleting it and then moving the temporary file in - a failed move left the
user's file gone and the new content in an unnamed `sal*.tmp` (rule 105 broken).

## Measured (before)

Probe `probe/copy_replace_probe.ps1` (hidden desktop, ACP 1250), the build at 168
(`Debug_x64_pre169`; this code is older than 172): `probe/result_before.txt`.

- **The loss itself could not be produced here.** The probe held the target open with
  `FILE_SHARE_DELETE` (row HELD) so that the delete is only "pending" and the move onto the name
  fails - but Windows 11 deletes with POSIX semantics on NTFS: the name goes at once and the move
  succeeds. The classic semantics (the name stays until the last handle closes) are those of FAT /
  exFAT and SMB shares; none is available on this machine (`\\localhost\C$` is refused, no FAT
  volume). A negative control that does not fail - recorded as such.
- **What did differ (row PLAIN, step KEPT):** delete-then-move makes a new file - the target lost
  its Hidden attribute (and would lose its ACL, short name, streams); its creation time survived
  only by NTFS name tunnelling. Old build: KEPT FAIL.
- LOCKED (the target open without `FILE_SHARE_DELETE`): the old file stays, the error 32 is shown,
  no temporary file left - on both builds. RO: the common dialog itself refuses a read-only target
  ("Copy To File" box) - the read-only branch is not reachable from the dialog. SELF (the viewed
  file onto itself): replaced on both.

## Work

- `src/viewer3.cpp` CM_COPYTOFILE: the temporary file is flushed before it is closed; then
  `SalReplaceWithTempW` (target existed, the user agreed, a read-only one too): done; failed with
  the target kept - the temporary file deleted, the error shown; target gone and the new content
  only in the temporary file - kept and named: new string `IDS_VIEWERCOPYKEPTTEMP` (12164, "The
  file "%s" could not be replaced.\nError: %s\n\nThe new content is kept in the file "%s".").
- Translations: `build_langs.cmd --export-templates --module salamand`, `translate.merge
  --templates <repo build>`: 1 gap per language, 8 languages, validation failures 0 (after the
  review's rewording: 1,776 DeepL characters); de, fr, es drifted to the informal register (and
  the French quotation marks) - pinned in `translations/ui-overrides.json`. The merge also re-laid out about 20 controls per language (the
  layout drift of 166's `widen` change) - left out: only the new entry and its `.origin` line are
  committed (`keep_string_only.py` of the session). `build.cmd full`: BUILD SUCCEEDED, 189
  language modules.

## Review

Independent refute-first review (read-only): nothing CRITICAL; the wide conversion (`\\?\` forms
accepted by `ReplaceFileW` / `MoveFileExW`), the self-overwrite (the viewer opens the file per read,
share read/write - the replace succeeds, as delete+move did), `clearReadOnly`, the notification, the
cursor, the format's argument order in all 8 languages checked.
- SHOULD-FIX, taken: the results of `FlushFileBuffers` and `CloseHandle` were ignored - a delayed
  write error (network, removable drive) would let an incomplete temporary file replace the target;
  now a write error (message, temporary file deleted, target untouched), as PictView and SFTP do.
- SHOULD-FIX, taken: the message for a kept temporary file read as if the target were intact; now
  "The file "%s" was removed, but the new content could not be put in its place. ... The new
  content is in the file "%s". Rename that file to restore it." - translated again.
- NIT, taken: the French quotation marks (« %s » as the rest of the file).
- Accepted: `srrFailedBothGone` (a third party removed both files) shows only the error; a
  read-only target that a race lets past the dialog loses its read-only flag (as before).
- Recorded in NEXT-WORK: Files > Convert (`worker.cpp`, 5f) and Quick Rename onto an existing file
  (`fileswn5.cpp`, 5g) still delete before they move.

## Measured (after)

The same probe: `probe/result_after.txt` - every row PASS, KEPT included (the file keeps Hidden
and its creation time); registry identical. Not driven: the "kept in the temporary file" message
(needs a target that disappears between the replace and the move - not producible here).
