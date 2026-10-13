# Implementation notes: feature 139 - SFTP, nothing replaced without a question

Session 2026-10-13, source changes only. Edited: `src/plugins/sftp/session.cpp`, `session.h`,
`fs.cpp`, `sftputils.cpp`, `sftputils.h`, `operats.cpp`, `test/harness.cpp`. No resource
strings, no project files, no build of the product, no run of the program, no git writes.

## 1. What was checked without a build

| Check | Result |
|---|---|
| Unit harness `src\plugins\sftp\test\build_and_run.cmd` | **152 passed, 0 failed** (111 before; 41 new) |
| Syntax-only compile (`cl /Zs`, writes no object files) of `operats.cpp`, `session.cpp`, `fs.cpp`, `sftputils.cpp` with the project's include paths and defines, **Debug** defines (`_DEBUG`, `MHANDLES_ENABLE`, `_CRTDBG_MAP_ALLOC`, `TRACE_ENABLE`) and **Release** (`NDEBUG`), `/W3`, without the precompiled header | exit 0, no warning, both |
| `tools/check_encoding.py` | `TOTAL: 0 finding(s)` |
| BOM / line endings | unchanged per file (`session.cpp` BOM + CRLF; `session.h`, `fs.cpp`, `sftputils.cpp` CRLF; `operats.cpp`, `sftputils.h`, `test/harness.cpp` were LF in the working copy and still are) |

The script of the syntax check is in the session's scratchpad (`impl139\syntax.cmd`), not in
the repository. `/Zs` runs the whole front end (types, overloads, templates), so "does it
compile" is answered for the four files; **linking was not checked** (see section 6).

## 2. Changes per function

### `session.cpp` / `session.h`

- `Rename(from, to, BOOL replace)` (was two arguments). `replace == TRUE`: as before
  (posix-rename extension, then `SSH_FXP_RENAME` with the OVERWRITE flag). `replace == FALSE`:
  only `libssh2_sftp_rename_ex` with `LIBSSH2_SFTP_RENAME_ATOMIC | LIBSSH2_SFTP_RENAME_NATIVE`
  (no OVERWRITE), never the extension. The long comment is rewritten.
- `OpenWriteNew(path, mode)`: `LIBSSH2_FXF_WRITE | LIBSSH2_FXF_CREAT | LIBSSH2_FXF_EXCL`.
- `CloseHandleChecked(h)`: FALSE + `SetLastErrorFromSftp("close")` when
  `libssh2_sftp_close_handle` returns non-zero; `NULL` handle = TRUE. `CloseHandle` kept.

### `fs.cpp`

- `QuickRename` (mode 2): byte-equal paths -> TRUE, nothing sent. Else `Session.Stat(to, FALSE)`
  (lstat); exists -> `SFTPShowPathError(IDS_ERR_RENAME, file.Name, "a file or directory of that
  name already exists.")`, FALSE. Then `Session.Rename(from, to, FALSE)`.
- new static `QuickRenameOnlyCaseDiffers` (see decision D1).
- `CopyOrMoveFromDiskToFS`: the panel is refreshed also when the upload did not end whole
  (before: only on full success). Return values unchanged.

### `sftputils.cpp` / `.h` (pure, in the harness)

- `SftpTempPath(targetPath, random, buf, bufSize)`: `<dir>/.tcpart-XXXXXXXX`.
- `SftpUploadConfirmed(remoteSizeKnown, remoteSize, bytesSent, localSize)`.
- `SftpLocalDirIsLink(attributes, reparseTag)`: reparse point AND the name-surrogate bit
  (`0x20000000`, what `IsReparseTagNameSurrogate` tests - the harness compares with the macro).

### `operats.cpp`

- `COperationCtx`: `Written` is a list of `{CSalFileIdentity Id; wchar_t* Path}` (was a
  `TDirectArray` of volume + index); new `WrittenLost`, `LinkSkippedShown`; a destructor frees
  the list. `NoteWritten(wpath, id)` returns nothing; `WasWritten(wpath)`: `simEqual` -> TRUE,
  `simUnknown` -> the paths decide (`CompareStringOrdinal`, ignore case), `simDifferent` -> no.
- new `ShowSysError` (a system error text made UTF-8 by `CSFTPMsgText`).
- new `ProbeXferFailAfter` (`#ifdef _DEBUG`): `TC_SFTP_PROBE_XFER_FAIL = "<suffix>;<bytes>"`.
- `DownloadOneFile`: over an existing local file that is not resumed -> temporary file beside
  it (`SalCreateTempNextToW(wlocal, L"tcp", ...)`), flushed, closed, then
  `SalReplaceWithTempW(wlocal, temp, TRUE, FALSE, &err)`; `srrDone` -> ok; `srrLeftAtTemp` ->
  failed, the temp is kept and named in the message; `srrFailedKept` / `srrFailedBothGone` ->
  failed with the system's reason, temp deleted. A failed or stopped download deletes only
  the temporary file. A new local file is written directly and deleted on failure as before.
  `NoteWritten` gets the final file (identity read from the open handle for a direct write,
  by path after a replace). The seam is in the read loop.
- `DownloadDir` split into `DownloadDir` (depth check, one `CDownloadLevel` heap block) and
  `DownloadDirLevel` (the old body, buffers from the block). Logic unchanged.
- new `ConfirmOverwriteRemote`, `UploadTempRandom`.
- `UploadOneFile(ctx, localPath, remotePath, move)` returns `CXferResult`; steps a - i of the
  brief (details and deviations in section 3).
- new `CUploadLevel`, `SkipLocalLinkDir`; `UploadDirRecursive(ctx, localDir, remoteDir, depth,
  move, linkChecked)` (depth check, heap block) + `UploadDirLevel` (the work).
- `DeleteLocalTree` removed.
- `SFTPUploadToFS`: tri-state, no deletion, `err != SALENUM_SUCCESS` (also inside the loop,
  the enumerator sets it per call) -> not ok.
- comment at `SFTP_MAX_RECURSION` rewritten with numbers (3 MB main-thread stack,
  `src/vcxproj/sal_base.props:31`).

## 3. Decisions where the brief left room

- **D1 - Quick Rename, a name that differs only in case.** The brief's rule "exists and is
  not the same item -> refuse" cannot be decided on SFTP v3 (no inode in the attributes). When
  the old and the new name differ only in case (UTF-16 ordinal, ignore case) the pre-check is
  skipped and the server decides - the request sent cannot replace. Case-sensitive server with
  both names: the server refuses (its reason is shown, not our sentence). Case-insensitive
  server: whether the rename works is the server's matter (OpenSSH on a case-insensitive file
  system does it by `link` + `unlink`, which very likely fails with "exists"); **a case-only
  rename may therefore fail there where the posix-rename extension did it before**. Not
  solved; the alternative (the replacing request for case-only names) would replace `A.txt`
  by `a.txt` on a case-sensitive server.
- **D2 - which existing targets are written in place.** The brief: a symbolic link. Done
  wider: everything that is **not known to be a regular file** (link, device, FIFO, socket,
  attributes without permission bits, or type bits all zero) - replacing a FIFO or a device
  node by a file is as wrong as replacing a link. Each such case writes a line to the log.
  Consequence: on a server that reports no type bits the old in-place behaviour stays (after
  the question).
- **D3 - a failed `lstat` of the target counts as "nothing there".** If something is there
  after all, `Rename(temp, target, FALSE)` fails, the temp is removed and the target is
  untouched - fail closed without a second question.
- **D4 - the delete-then-rename fallback** (`operats.cpp:1047`) runs only
  when `IsConnected()` and an `lstat` of the temporary file still finds it. Reason: after a
  rename whose answer was lost the rename may have happened; `Unlink(target)` would then
  remove the NEW file. Not in the brief.
- **D5 - the size check (step f) also applies to in-place writes.** An upload through a link
  to something whose size is not the bytes written (a device) now ends as failed; it
  "succeeded" before.
- **D6 - download: no temporary file can be created beside the target** (a folder where
  existing files may be written but none created): falls back to writing in place, as the
  spec's FR-002 says for "the directory does not allow that", with a log line; on failure the
  file is deleted as before (CF-17). The brief did not say; the alternative was to fail.
- **D7 - `NoteWritten` cannot fail a download.** If even the list node cannot be allocated,
  `WrittenLost` makes `WasWritten` answer TRUE for the rest of the operation (nothing existing
  is overwritten any more) - instead of failing or deleting the complete file.
- **D8 - the path comparison** of the identity fallback is `CompareStringOrdinal(...,
  ignoreCase)` on the wide final path (the rule `SalPathEqualOrdinalCI` implements for UTF-8;
  that function itself is not in a header the plug-in includes). An 8.3 alias or another
  spelling is not caught on a volume without ids.
- **D9 - `FindFirstFileW` failing with `ERROR_FILE_NOT_FOUND` while the path is a directory**
  is an empty folder (a file system that lists no "." entry), not a failure. Every other
  error is a failure with a message.
- **D10 - the local listing is opened before `Mkdir`** on the server, so an unreadable local
  folder creates nothing remotely.
- **D11 - a reparse point whose tag cannot be read** (the `FindFirstFileW` on the folder
  itself fails) is treated as a link: skipped aloud, not entered.
- **D12 - `linkChecked` parameter**: a child folder is tested from the parent's
  `WIN32_FIND_DATAW`, so the self-test (one more `FindFirstFileW`) runs only for top-level
  items.
- **D13 - the link message uses `IDS_SYMLINK_DIR_SKIPPED`** (`lang.rc2:89`, one `%s`): "Skipped
  directory symbolic link "..." (not followed during recursive transfer)." - the word
  "symbolic link" is also shown for a junction.
- **D14 - local listing failures use `IDS_ERR_OPENLOCAL`** ("Cannot open local file "%s"." -
  no place for a reason, and it says "file"); the system error number goes to the log line
  before it.
- **D15 - `DownloadDir` got the heap block too**: its 17 KB per level were 2.2 MB of the
  3 MB stack at 128 levels - it fitted, with little left for the message boxes at the bottom.
- **D16 - the seam** cuts the request length so that exactly `<bytes>` bytes are transferred
  and the next read / write "fails"; `0` fails before the first byte; a shorter file passes.
  The suffix is matched against the target's remote path (not the temporary name); the last
  `;` separates the number, so a suffix may contain `;`. It goes through the ordinary error
  path, so the "Cannot write to / read from the remote file." box is shown.
- **D17 - a zero return of `Write`** is a failure with the write message (`w <= 0`).
- **D18 - "Cancel = skip the rest" and "No" are not failures** of the upload (xrSkipped), as
  in the download: `SFTPUploadToFS` still returns TRUE when only skips happened; in a move the
  skipped sources and their folders stay.

## 4. libssh2 facts verified for the non-replacing rename

- `src/common/dep/libssh2/include/libssh2_sftp.h:58` - `LIBSSH2_SFTP_VERSION 3`;
  `src/common/dep/libssh2/src/sftp.c:961-965` - a higher version offered by the server is
  lowered to it. The library never speaks more than version 3.
- `sftp.c:2891-2893` and `sftp.c:2925-2926` - `sftp_rename` adds the 4-byte flags word to
  `SSH_FXP_RENAME` only when `sftp->version >= 5`. In version 3 the flags argument is **not
  sent at all**: the request cannot ask for an overwrite, whatever is passed. The flags chosen
  for `replace == FALSE` (`ATOMIC | NATIVE`, `libssh2_sftp.h:70-72`) leave out OVERWRITE so
  that the call stays non-replacing even with a library that negotiated version 5.
- `sftp.c:2983-2987` - the server's `FILE_ALREADY_EXISTS` status is reported as an error
  ("File already exists and SSH_FXP_RENAME_OVERWRITE not specified").
- `sftp.c:3021 ff.` - `sftp_posix_rename` sends the `posix-rename@openssh.com` extension;
  this is the request that replaces, and `Rename(..., FALSE)` does not call it.
- `sftp.c:2644-2758` - `sftp_close_handle` frees the handle on every path that returns (other
  than EAGAIN, which the blocking wrapper loops on) and returns non-zero for a status other
  than OK - the base of `CloseHandleChecked`.
- `libssh2_sftp.h:191` - `LIBSSH2_FXF_EXCL`.
- **Not verified in this tree** (the server is not vendored): that OpenSSH's `sftp-server`
  refuses `SSH_FXP_RENAME` onto an existing target. It is the documented behaviour (it uses
  `link` + `unlink`, or `stat` + `rename`) and what the old comment in `Rename` recorded
  ("fails the rename with SSH_FX_FAILURE"); the probe row RENEXIST has to show it.

## 5. Not sure / to look at in the first real build

`/Zs` passed, so these are behaviour, not syntax:

- `operats.cpp:13-15` - `salrandom.h` carries `#pragma comment(lib, "bcrypt.lib")`;
  `sftp.props` links `bcrypt.lib` already. `salsamefile.h` / `salsafereplace.h` are header-only.
  **The link step was not run.**
- `operats.cpp:425` / `527` - `SalCreateTempNextToW` / `SalReplaceWithTempW` get the path made
  by `MakeLocalWidePath` (no `\\?\` prefix, as the direct `CreateFileW` before): a local
  target beyond `MAX_PATH` behaves as it did.
- `operats.cpp:527` - `clearReadOnly` is FALSE: a read-only local file is not replaced
  ("Access is denied", the file intact) - the same outcome as the old `CREATE_ALWAYS`.
  A hidden / system local file IS replaced now (and keeps its attributes); `CREATE_ALWAYS`
  with `FILE_ATTRIBUTE_NORMAL` used to fail on it.
- `operats.cpp` `UploadDirLevel` - in a move, files are deleted from a folder while its
  `FindFirstFileW` enumeration is open (as the removed `DeleteLocalTree` did).
- `session.cpp` `Rename` logs "Rename a -> b" for every call: every upload through a
  temporary file now adds such a line (and, on a server without the extension, the line of
  the refused first attempt) to the session log.
- `fs.cpp:991` `QuickRenameOnlyCaseDiffers` - two `WCHAR[1024]` on the stack; a name
  that does not fit is "another name".

## 6. Not done

- No build, no GUI run, no probe rows (T003, T007), no `fix-log.md`, `CHANGELOG.md`,
  `FEATURE-HISTORY.md`, `NEXT-WORK.md`; `tasks.md` not ticked. No independent review (T008).
- The plan's name `SftpTempName` / `<name>.tcpart-<hex>` is `SftpTempPath` /
  `.tcpart-<hex>` as the brief says (plan.md still has the old form).
- No new strings: the question, the reasons and the log lines are English literals.
- An orphaned `.tcpart-XXXXXXXX` (connection lost before it could be removed, or the kept
  copy of D4's last case) is not cleaned up by a later operation; the removal failure is
  logged.
- A replaced server file keeps its permission bits (`Chmod`, best effort) but **not its owner,
  group, times, ACL or hard links** - the new file is a new inode owned by the account.
- Upload has no resume and no "same file written twice in this operation" guard (two local
  names cannot land on one remote name on a case-sensitive server; on a case-insensitive
  server the second asks the overwrite question).
- The upload's completeness is confirmed by size, not by content (as in 138).
- `DeleteRecursive`, chmod / chown recursion: untouched.

## 7. After the review

The independent review found no critical defect, four medium and some low ones. All were
changed in `src/plugins/sftp/` only; sections 2 - 6 above describe the state BEFORE this
section where the two differ (named below).

Checks after the changes: unit harness **172 passed, 0 failed** (20 new); `cl /Zs` of
`operats.cpp`, `session.cpp`, `fs.cpp`, `sftputils.cpp`, Debug and Release defines, `/W3`:
exit 0, no warning; `tools/check_encoding.py`: `TOTAL: 0`. Still no link, no build, no run.

### What changed

- **Session** (`session.cpp/.h`): `LastSftpStatus` + `GetLastSftpStatus()` - the SSH_FX status
  of the last failed request when the server answered with one, 0 otherwise (timeout,
  transport, not connected); written in `SetLastErrorFromSftp` and `SetLastErrorNotConnected`.
  `StatEx(path, follow, attrs)` returns `sxFound` / `sxNotFound` (NO_SUCH_FILE, NO_SUCH_PATH)
  / `sxError` (sets the error text and the status, notices a dead transport). Plain `Stat` is
  unchanged (it still leaves the error text alone - `UploadDirLevel` relies on that).
- **Pure, in the harness** (`sftputils.cpp/.h`): `SftpStatusIsNotFound`,
  `SftpStatusIsPermission`, `SftpTempOpenFailureNext(connected, status)` (`tonFail` /
  `tonRetryName` / `tonInPlace`), `SftpOwnerDiffers`.
- **M1, Quick Rename** (`fs.cpp`): `StatEx(to)`; `sxError` refuses with the reason (D3 of
  section 3 no longer holds here). Found and the names differ only in case: the directory is
  listed (`Session.ListDir`); an entry byte-equal to the new name = another file -> "already
  exists"; no such entry = the same item on a case-insensitive server -> `Rename(from, to,
  TRUE)`; a failed or stopped listing refuses. **D1 of section 3 is replaced by this**: a
  case-only rename on a case-insensitive server works again, and on a case-sensitive server
  the refusal is ours, not the server's.
- **M1, upload**: `UploadOneFileImpl` starts with `StatEx(remotePath)`; `sxError` fails the
  item with the reason (D3 no longer holds).
- **M2, the fallback to writing in place** is taken only for `tonInPlace`: the session is
  connected and `OpenWriteNew(temp)` was refused with PERMISSION_DENIED, WRITE_PROTECT or
  OP_UNSUPPORTED. FAILURE / FILE_ALREADY_EXISTS: one more try with a new random name. Anything
  else (no status at all = timeout or transport, no space, quota): the item fails, nothing is
  opened under the target's name.
- **M3**: the temporary file of a replaced file is created with `oldAttrs.permissions & 0777`
  (a new file: 0644).
- **M4** (`UploadPlaceTemp`): before the rename of a replacement the temp is `lstat`ed; when
  both report uid/gid and they differ, `Chown(temp, old uid, old gid)` and a second `lstat`
  must show them equal; then `Chmod(temp, old & 07777)` must succeed. If either fails, or the
  rename is refused with a permission status on a live session: the temp is unlinked, one log
  line says why, and the file is sent once more in place (`for (pass ...)` in
  `UploadOneFileImpl`, `inPlace` flag; the write loop is `UploadWriteData`, which rewinds the
  local file). In place = `OpenWrite(target)` for an existing target, `OpenWriteNew(target)`
  for a new one. The delete-then-rename fallback remains only for a rename refused for
  another reason while the temp is still there.
- A temp that cannot be unlinked is named (full path) in the log.
- **L1**: when `Unlink(target)` reports a failure in that fallback, the temp is removed only
  if a fresh `StatEx(target)` says `sxFound`; otherwise it is kept and named in the message
  ("the old file may be gone; the complete new file is left as ...").
- **L2**: `COperationCtx::ConnLostShown`, `TransferSessionLost`, `TransferNoteFailure`.
  `UploadOneFile` / `DownloadOneFile` are now thin wrappers around `...Impl`: not connected ->
  failed at once, one log line, no box if the item that lost the connection showed its error
  (else one "connection lost" box per operation). `UploadDirLevel`, `DownloadDirLevel` and the
  item loops of `SFTPUploadToFS` / `SFTPDownloadFromPanel` stop the same way. Delete, chmod
  and chown are not touched.
- **L3**: `DownloadOneFileImpl` refuses a read-only existing local file before the question
  and before the remote file is opened (`IDS_ERR_DOWNLOAD`, "the local file of that name is
  read-only.").
- **L5**: the comments of `CloseHandleChecked` (both files) say that a timed-out close leaves
  the handle allocated.

### Decisions taken here

- **R1 - a temporary path that does not fit 4,096 bytes fails the item** (`ReportTooLongPath`)
  instead of writing in place as before the review: M2 allows in place only for the three
  statuses. Reachable only for a target whose own path is within 16 bytes of the limit.
- **R2 - a new target written in place whose `OpenWriteNew(target)` is refused with
  OP_UNSUPPORTED** (a server without exclusive create) is opened with `OpenWrite` (create +
  truncate), on a live session only: without it such a server could not take new files at
  all. The `lstat` just before said "no such file".
- **R3 - a rename refused for want of a right retries in place also for a NEW target**, as
  the review text says; `existed` is not required.
- **R4 - the owner is compared only when both sides report uid/gid** (`SftpOwnerDiffers`); an
  `lstat` of the temp that fails or reports none is "not different" and the rename goes on.
- **R5 - a failed `Chown` / `Chmod` on a session that is no longer connected is a plain
  failure**, not a retry in place (nothing more is asked of a dead session).
- **R6 - the "connection lost" box**: shown at most once per operation, and not at all when a
  failed item's own box preceded it. A cancelled item on a dead session also sets the flag
  (no box was shown then - the operation ends by the cancel anyway).
- **R7 - the read-only check (L3) comes before the overwrite / resume question**, so the user
  is not asked about a file that cannot be replaced.
- **R8 - Quick Rename's listing** passes its own stop flag; no wait window is open there, so
  it can only be set by a window of another operation - it then refuses.

### Not sure / to look at

- `operats.cpp` `UploadPlaceTemp`: `CSFTPSession::Chown` reads the attributes through links
  first and then sends SETSTAT with uid and gid; an ordinary account cannot change the owner,
  so with a file owned by someone else (group-writable directory and file) the result is
  always "retry in place" - the intended pre-139 behaviour, at the cost of one upload sent
  twice. A large file is transferred twice in that case; the first pass could be avoided by
  comparing the owner of an empty temp before the data are sent. Not done (the review asked
  for the check before the rename).
- The first `Rename(temp, target, TRUE)` on a server without the posix-rename extension
  still writes its refused attempt into the session log.
- `TransferSessionLost` relies on `IsConnected()`, which is cleared by `NoteTransportError`
  only for socket and timeout codes; a session broken in another way keeps failing item by
  item as before.
- Plain `Stat` (size confirmation, `RemoveMovedFile`) does not record a dead transport; the
  next `StatEx` / open does. (Changed by section 8, point 7.)

## 8. After the second review

Seven medium findings and two low ones, all changed in `src/plugins/sftp/` only. Where this
section and section 7 differ, this one holds (named below).

Checks: unit harness **179 passed, 0 failed** (7 new); `cl /Zs` of `operats.cpp`,
`session.cpp`, `fs.cpp`, `sftputils.cpp`, Debug and Release defines, `/W3`: exit 0, no
warning; `tools/check_encoding.py`: `TOTAL: 0`. No link, no build, no run of this round.

### What changed

1. **The route is decided before any data is sent** (`UploadTempFitsOld`, called right after
   `OpenWriteNew(temp)` succeeded for a replacement): `StatEx` of the empty temp; owner and
   group compared when both report them, `Chown` + a verifying `StatEx` on a mismatch; `Chmod`
   only when `SftpModeDiffers` (new pure helper, harness) says the 12 bits differ. Cannot be
   made equal on a live session: the empty temp is closed and unlinked, one log line, and the
   file goes in place at once - **one transfer** (section 7's "uploaded twice" for a file of
   another owner is gone). After the data there is no chown / chmod step any more.
2. **After the data, "once more in place" has two reasons only** (`UploadPlaceTemp`), both
   with the session connected and `StatEx(target) == sxFound`: the rename was refused with a
   permission status, or the delete-then-rename fallback's `Unlink(target)` was refused.
   Section 7's R3 (retry also for a NEW target) is withdrawn: a new target whose rename is
   refused fails, the temp is removed. The whole fallback now also needs a server status
   (`GetLastSftpStatus() != 0`): no answer = no further request.
   `CSFTPSession::Rename(..., TRUE)`: the plain request is sent only when the posix-rename
   extension is not there (the library's own `LIBSSH2_FX_OP_UNSUPPORTED` return, or the
   server's status); any other failure of the extension is the answer, so
   `GetLastSftpStatus()` shows a PERMISSION_DENIED instead of the plain request's FAILURE.
3. **The second transfer keeps the complete temp** (`UploadSecondPass`) until the in-place
   write is confirmed; only then is it unlinked. Fails or is stopped: the temp stays and one
   box names it ("the old content of the file is gone; the complete new file is left as
   ...") - after a stop too. An `OpenWrite` refused by the server (a status, session alive)
   truncated nothing: temp removed, plain error. An `OpenWrite` without an answer: temp kept,
   "may be gone".
4. **`CheckCancel()` before every open that truncates an existing target**: the first-pass
   in-place open (stopped: failed, nothing touched) and the second pass (stopped: failed, the
   temp of pass 1 removed - the old file is intact).
5. **Quick Rename, case-only branch** (`fs.cpp`): refused also when any listing entry OTHER
   than the old name equals the new name up to case (`QuickRenameOnlyCaseDiffers`, the same
   comparison) or byte for byte. Only when the old name is the sole such entry is it the
   same item.
6. **Download**: the read-only check sits after the overwrite / resume question, before the
   remote file is opened; "No", "skip the rest" and the resume prompt's Cancel stay silent
   skips (section 7's R7 is reversed).
7. **`CSFTPSession::Stat`** calls `NoteTransportError(rc)` on a failure; the error text is
   still left alone.
8. **L1**: a `.tcpart-*` that cannot be unlinked is appended to the box that is shown anyway
   (`UploadShowFailure`: "... (the temporary file X could not be removed)"); without a box
   (a stop by the user, or success of the second pass) it is in the log only. To make that
   possible the upload shows **one box per failed file, at the end**: `UploadWriteData` /
   `UploadSendAndConfirm` return the reason instead of showing it. A failed write now reads
   `Cannot upload "<path>": Cannot write to the remote file.` (it was the bare second
   sentence) - the probe rows that keep dialog texts will see the longer text.
   **L2**: a stat / chown / chmod that failed because the connection died returns `utfLost`
   and the box shows the connection's error.

### Decisions taken here

- **S1 - a replaced file with a set-user-ID or set-group-ID bit is written in place**
  (decided before the data, logged): a write by an ordinary account clears these bits on the
  temp, and there is no chmod after the data any more.
- **S2 - an `lstat` of the empty temp that fails on a live session** is "nothing reported":
  the owner is not compared and the bits are set by `Chmod` (its failure -> in place).
- **S3 - a stale `sftp->last_errno`**: `sftp_posix_rename` does not reset it; only the
  malformed-reply path ("packet too short") can leave an older status visible to
  `Rename(..., TRUE)`. Then at worst the plain, non-replacing request is sent.
- **S4 - the message of a kept temp names its base name**; it lies in the target's directory.

### Paths of `UploadOneFileImpl` against the rule

Rule: the old content is never gone unless the complete new content is under the final name
OR the user was told the name of the file that holds it; a move deletes the local source
only on `xrOk`. (`DeleteFileW` is reached in one place, guarded by `res == xrOk`.)

| # | Path | Old file on the server | New content | Result |
|---|---|---|---|---|
| 1 | local open / size fails | not touched | - | failed |
| 2 | `StatEx(target)` = error | not touched | - | failed, reason |
| 3 | target is a directory | not touched | - | failed |
| 4 | question: No / skip the rest | not touched | - | skipped |
| 5 | temp path too long; temp open fails with no status / space / quota / second name clash | not touched, nothing opened under its name | - | failed |
| 6 | empty temp cannot get owner / bits, connection died | not touched; temp unlinked (named in the box if not) | - | failed, connection error |
| 7 | temp route, data fail or stopped, close fails, size not confirmed | not touched | partial temp unlinked (named if not) | failed |
| 8 | temp route, rename ok | replaced by the complete file in one step | final name | **ok** |
| 9 | rename fails without a server status, or session dead | as it was, or already replaced by the complete file | final name or temp (unlink tried) | failed |
| 10 | new target, rename refused | none existed | temp unlinked | failed |
| 11 | rename refused (no replace-rename), `Unlink(target)` ok, second rename ok | removed, then | final name | **ok** |
| 12 | same, second rename fails | removed | **temp kept, named in the box** | failed |
| 13 | same, `Unlink` refused, target shown still there | intact so far -> row 15 | temp kept | second transfer |
| 14 | same, `Unlink` refused, target not shown there | may be gone | **temp kept, named in the box** | failed |
| 15 | second transfer: stopped before the open | intact | temp unlinked | failed |
| 16 | second transfer: open refused by the server | intact | temp unlinked (named if not) | failed |
| 17 | second transfer: open without an answer | may be truncated | **temp kept, named** | failed |
| 18 | second transfer: data fail / stopped / not confirmed | truncated | **temp kept, named** (also after a stop) | failed |
| 19 | second transfer confirmed | overwritten in place, complete | final name; temp unlinked | **ok** |
| 20 | in place from the start (not a regular file, set-id bit, no file may be created, owner / bits cannot be kept): stopped before the open | intact | - | failed |
| 21 | in place from the start: open refused | intact (a status) or may be truncated (no answer) | - | failed |
| 22 | in place from the start: data fail / stopped / not confirmed | **truncated, no other copy on the server** | the local source (never deleted: not `xrOk`) | failed |
| 23 | in place from the start, confirmed | overwritten, complete | final name | **ok** |
| 24 | any **ok** row with `move`: `DeleteFileW` fails | - | final name | failed, source stays, said once |

Rows 21 (no answer) and 22 are the route "in place" - the behaviour before 139, taken only
after the overwrite question and only for the four logged reasons; there the rule is not
kept, because no second file can exist beside the target. The complete content is then the
local source, which is never removed on that path. Every other row keeps the rule.

### Not sure / to look at

- Row 9 with a live session and no status (a transport error that `NoteTransportError` does
  not know): the temp is unlinked although the rename's fate is unknown - safe (either the
  old or the new complete file holds the name), but the box may say "could not be removed"
  when the rename had in fact happened.
- A debug run with the seam fails the second transfer at the same byte as the first.
- `UploadTempFitsOld` costs one `lstat` per replaced file (plus chown / chmod only when
  something differs).

