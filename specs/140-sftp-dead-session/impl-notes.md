# Implementation notes: feature 140 - SFTP dead session, special files, refused attribute changes

Session 2026-10-14, source changes only. Edited: `src/plugins/sftp/session.cpp`, `session.h`,
`operats.cpp`, `fs.cpp`, `sftputils.cpp`, `sftputils.h`, `test/harness.cpp`. No resource
strings, no project files, no run of the program, no GUI, no git writes, no Docker.

## 1. What was checked

| Check | Result |
|---|---|
| Unit harness `src\plugins\sftp\test\build_and_run.cmd` | **217 passed, 0 failed** (179 before; 38 new) |
| `cl /Zs` of `operats.cpp`, `session.cpp`, `fs.cpp`, `sftputils.cpp`, Debug and Release defines, `/W3` | exit 0, no warning, both |
| Build of the plug-in project only (`sftp.vcxproj`, Debug x64 and Release x64) **into a scratch output directory** (`OPENSAL_BUILD_DIR` = the session's scratchpad `impl140\build\`; `tasklist` showed no `tandemcommander.exe`) | compiles and **links**, both (only the linker's usual LNK4217 / LNK4286 / LNK4198 notes of this project). The product's build tree was **not** touched - the real Debug binaries still hold the code before 140 |
| `tools/check_encoding.py` | `TOTAL: 0 finding(s)` |
| BOM / line endings | unchanged per file (`session.cpp` BOM + CRLF; `session.h`, `fs.cpp`, `sftputils.cpp` CRLF; `operats.cpp`, `sftputils.h`, `test/harness.cpp` LF) |

Nothing was run against a server: the probe rows (T002 / T007) and the review (T008) are open.

## 2. The library fact (vendored libssh2, `src/common/dep/libssh2/src`)

Claim: after an API timeout the per-request state stays "sent", and the next call of the same
kind does not send its own request but waits for, and returns, the answer to the OLD one.
**Verified:**

- `session.h:55-66` `BLOCK_ADJUST` (and `:74-86` `BLOCK_ADJUST_ERRNO` for the opens): the
  blocking wrapper calls the worker again while it returns `LIBSSH2_ERROR_EAGAIN`, waiting in
  `_libssh2_wait_socket` between the calls; a non-zero result of that wait ends the loop and
  is what the API returns.
- `session.c:594` `_libssh2_wait_socket`: returns `LIBSSH2_ERROR_TIMEOUT` at `:633` ("API
  timeout expired"), `:707` ("Timed out waiting on socket"), `:723`. It also returns the code
  of a failed automatic keepalive (`:610-612`; `keepalive.c:82-89`). The worker is **not**
  called again and is not told.
- `sftp.c`, `sftp_unlink`: the request is built and gets its id only in the idle state
  (`:2790-2808`), is sent and the state becomes `libssh2_NB_state_sent` (`:2827`); the wait for
  the answer returns `EAGAIN` with the state unchanged (`:2830-2835`); the state goes back to
  idle only on an answer or on another error (`:2843-2849`). A second `sftp_unlink` with the
  state "sent" skips both blocks and waits for `sftp->unlink_request_id` - the id of the OLD
  request - while its own `filename` is never looked at.
- The same shape in `sftp_stat` (`:3667` idle block, `:3723` sent, `:3726-3729` EAGAIN,
  `:3737-3743` reset) - stat, lstat and setstat share the one `stat_state`, so a chmod can be
  "answered" by an old stat; `sftp_open` (`:1159`, `:1229`, `:1233-1244`); `sftp_readdir`
  (`:1828`, `:1969`); `sftp_rename` (`:2899`, `:2947`); `sftp_posix_rename` (`:3056`, `:3096`);
  `sftp_mkdir` (`:3450`, `:3490`); `sftp_rmdir` (`:3558`, `:3596`); `sftp_symlink` (`:3808`,
  `:3871`, also readlink / realpath); `sftp_read` (`:1593`, `:1665`); `sftp_write` (`:2224`);
  `sftp_close_handle` (`:2656`, `:2691`, `:2697-2703`, per handle).
- Other errors of the wait for the answer (`sftp_packet_require`, `:496-546`: socket died ->
  `SOCKET_DISCONNECT` at `:545`; `sftp_packet_requirev` `:599` its own `TIMEOUT`, `:610`) DO
  reset the state to idle. So the mismatch needs the API timeout (or a failed keepalive inside
  the wait); the other transport codes "only" mean that every later request fails.
- A malformed answer ("packet too short", e.g. `:3730-3736`) returns
  `LIBSSH2_ERROR_SFTP_PROTOCOL` and also leaves the state "sent" - with the answer already
  consumed. The next request of that kind then waits for the timeout and the session ends
  there; no wrong answer is handed out. **Not handled specially** (see section 8).
- Handles: `sftp_close_handle` frees the handle when the server answered or the close could
  not be sent (`:2684-2689`, `:2738-2757`); when the wait times out it returns at `:2702-2703`
  with the handle allocated. `sftp_shutdown` (`:1053-1123`) frees the per-request packets and
  the channel, not the handles (`:1117` "TODO: We should consider walking over the
  sftp_handles list and kill any remaining sftp handles"). `libssh2_sftp_seek64`
  (`:2543-2560`) talks to nobody.

## 3. Changes per function

### `sftputils.cpp` / `.h` (pure; harness)

- `BOOL SftpRcIsDeadTransport(int rc)` - the list `NoteTransportError` had (5 codes) plus:

  | Code | Why it is in |
  |---|---|
  | `TIMEOUT` -9, `SOCKET_TIMEOUT` -30, `SOCKET_SEND` -7, `SOCKET_RECV` -43, `SOCKET_DISCONNECT` -13 | as before (051) |
  | `CHANNEL_CLOSED` -26, `CHANNEL_EOF_SENT` -27 | `channel.c:2362-2369`: every later write on the SFTP channel fails |
  | `SOCKET_NONE` -1, `BAD_SOCKET` -45 | by meaning (no usable socket); in this tree only `agent_win.c:229` / `session.c:740` raise them - not reachable from an established SFTP session, listed so that a later library cannot slip through |
  | `INVALID_MAC` -4, `DECRYPT` -12 | `packet.c:657`, `transport.c:163`: the incoming packet stream is out of step - nothing later can be read |
  | `ENCRYPT` -44, `MAC_FAILURE` -52, `ZLIB` -29, `COMPRESS` -40 | `transport.c:1185/1196/1264`, `comp.c`: an outgoing packet could not be made / the compression stream is broken. **Not verified** that the session is unusable afterwards; listed fail-closed (the cost of a wrong "dead" is a reconnect) |
  | `EAGAIN` -37 | must not come out of a blocking call; if it does, the request is half done - exactly the dangerous state |

  Not in: `SFTP_PROTOCOL` -31 (the server refused), `ALLOC`, `BAD_USE`, `INVAL`,
  `BUFFER_TOO_SMALL`, `OUT_OF_BOUNDARY` (also an argument error at `sftp.c:3044`). The numbers
  are literals (the harness compiles without the library); `session.cpp` has a `static_assert`
  tying them to the header.
- `CSftpDownloadKind SftpDownloadKind(BOOL hasMode, unsigned long mode)`: `sdkRegular`,
  `sdkDirectory`, `sdkLink`, `sdkSpecial` (CHR, BLK, FIFO, SOCK), `sdkUnknown` (no mode, no type
  bits, an undefined type).

### `session.cpp` / `session.h`

New private helpers: `NoRequest(quiet)` (the gate), `SetLastErrorLost(detail)`,
`NoteFailure(rc, textIsSet)`, `RequestFailed(rc, prefix)`; debug only `ProbeTimeoutAt` (static)
and `ProbeTimedOut`.

- **Gate.** `NoRequest()` is TRUE when `Sftp == NULL` ("Not connected to the server.", as
  before) or `!Connected` (`IDS_ERR_CONNLOST`, the existing string "The connection to the
  server was lost."); `LastSftpStatus` = 0. It is the first statement of: `RealPath`,
  `ListDir`, `Stat`, `StatEx`, `ReadLink`, `Mkdir`, `Rmdir`, `Unlink`, `Rename`, `Symlink`,
  `Chmod`, `Chown`, `SetMTime`, `OpenRead`, `OpenWrite`, `OpenWriteNew`, `Read`, `Write`,
  `CloseHandle`, `CloseHandleChecked`; `Keepalive` tests `Connected` itself. "Quiet" (text and
  status untouched) for `Stat`, `ReadLink`, `RealPath`, `CloseHandle`.
- **Every failure** goes through `NoteFailure` (directly, or via `RequestFailed` =
  `SetLastErrorFromSftp` + `NoteFailure`), with the real return code. Before: `Mkdir`, `Rmdir`,
  `Unlink`, `Symlink`, `Chmod`, `Chown`, `SetMTime`, the opens and `CloseHandleChecked` relied
  on `SetLastErrorFromSftp` -> `SetLastErrorFromSsh` -> `NoteTransportError(0)` (the session's
  last errno - it did catch a timeout, but not a code the function returned without recording
  it); `RealPath`, `ReadLink`, `CloseHandle`, the `readdir` loop and `closedir` noted nothing.
- **The error text of the request that ended the session** is
  `The connection to the server was lost. (<the library's or the request's text>)`, status 0.
  So: session lost <=> `GetLastErrorText()` begins with that sentence (the operations rely on
  it for their one box). Plain `Stat` still leaves the text alone, except in that one case.
- `ListDir`: the gate; `opendir` -> `RequestFailed`; a failed `readdir` -> `NoteFailure(rc)`
  (not for the seam of 133: its rows are a listing that fails on a LIVE session, see D3);
  `closedir` only while the session lives, its failure -> `NoteFailure` (the result of a
  complete listing stays TRUE - the server had said "no more entries" - but the session is
  dead for the caller's next step).
- `Rename`: the second request (after "no such extension") only while `Connected`.
- `Chown`: see the table (F12) - the read of the current owner is skipped when both fields
  are given, and its failure now fails the call.
- `CloseHandle` / `CloseHandleChecked`: on a dead or freed session the library is not called;
  `CloseHandleChecked` returns FALSE ("not confirmed"). `CloseHandle` now also notes a failed
  close. **Memory:** a handle that is not closed is NOT freed by `Disconnect` -
  `sftp_shutdown` / `session_free` do not know handles (section 2). It leaks until the process
  ends: the handle struct, for a read handle what it had buffered, queued request chunks -
  one handle (rarely two: the listing's and a file's) per lost connection. It is the leak a
  timed-out close already had (139, L5). Nothing is freed twice: after the gate no code calls
  the library with that handle again, and `Disconnect` frees only `Sftp` and `Ssh`.
- `SeekWrite`: no gate (local only).
- `NoteTransportError`: the list is `SftpRcIsDeadTransport`; the log line carries the code.
- `GetLastSftpStatus()` is 0 for a gated call (not for the quiet ones, which never set it).
- **Seam** (`#ifdef _DEBUG`): `TC_SFTP_PROBE_TIMEOUT_AT=<path suffix>`. The first `Stat` /
  `StatEx` / `OpenRead` / `Unlink` of the process whose path ends with the suffix is not sent:
  text "API timeout expired" (the library's text of a real one), then
  `NoteFailure(LIBSSH2_ERROR_TIMEOUT)` - the same path as a real timeout. Fires once. A line
  "Probe seam: ..." goes to the session log.
- Reconnect: `EnsureConnected` / `Reconnect` / `Disconnect` are untouched. (It is not an
  "offer": the next operation reconnects by itself with the kept parameters, as before.)

### `operats.cpp`

- `COperationCtx`: `SessionLost()`, `ReportSessionLost()` (one box per operation; text = the
  session's lost text; also logged; nothing after a cancel), `NoteRefused`, `RefusedCount`,
  `RefusedPath`, `RefusedReason`.
- `TransferSessionLost` -> `StopIfSessionLost(ctx, what)` (same behaviour, used by every
  operation now); `TransferNoteFailure` is gone - its job is done by `ShowRequestError`.
- new `ShowRequestError(ctx, fmtID, path, reason)`: the box of a failed server request (see D1).
- `DownloadOneFile(…, knownRegular)` / `DownloadOneFileImpl`: the special-file check (D4),
  `OpenRead` failure through `ShowRequestError`; a failed read on a lost session shows the
  lost connection instead of "Cannot read from the remote file."
- `ReportNotRemoved`: on a lost session -> `ShowRequestError` (not the "refused" flag).
- `RemoveMovedFile`: stops before the stat when the session is lost.
- `DownloadDirLevel`: listing failure through `ShowRequestError`; before the `Rmdir` of a
  move a lost session stops (an empty directory whose `closedir` timed out).
- `DownloadRecursive`: link branch stops on a lost session before its stat; the plain branch
  passes `SFTP_S_ISREG(mode)` as `knownRegular`.
- `UploadShowFailure`, `UploadSecondPass`, `UploadOneFileImpl`, `UploadDirLevel`: every box of
  a server step through `ShowRequestError`; before `DeleteFileW` (moved file) and
  `RemoveDirectoryW` (moved folder) a lost session stops.
- `DeleteRecursive`: stops at entry, before each child and before `Rmdir`; boxes through
  `ShowRequestError`. `SFTPDeleteFromPanel`: stops before each item.
- `ChmodRecursive` / `ChownRecursive`: stop on a lost session (entry, after the change, in the
  child loop); refusals counted by new `NoteAttrRefused` (log line as before + count); a
  failed sub-directory listing and a tree deeper than `SFTP_MAX_RECURSION` (was a silent
  `return`) count too. `SFTPChangeAttrsFromPanel` / `SFTPChangeOwnerFromPanel`: item loop
  stops on a lost session; a failed `SetMTime` is logged and counted (was ignored entirely);
  after the wait window is closed new `ShowRefused` shows the ONE box: the lost connection,
  else `IDS_ERR_CHMOD` / `IDS_ERR_CHOWN` (two `%s` each, `lang.rc2:78`, `:113`) with the first
  path and `<reason> (and N more refused; see the log)` when N > 0. Return values unchanged
  (TRUE: the panel is refreshed).

### `fs.cpp`

- `ChangePath`: after `RealPath`, and after a failed `Stat` in the loop: session lost -> one
  box with the session's text, `return FALSE` (F13).
- `ListCurrentPath`: a link is marked broken only while the session lives (F14).
- `ViewFile`: the special-file check (D5).
- `QuickRename`, `CreateDir`, `Delete`, `CopyOrMove*`, `ChangeAttributes`: read, not changed -
  each returns at its first failed request (the gate covers what follows a silently dead
  `closedir`).

## 4. Failures that were read as facts

| # | Place | Reading before | Now |
|---|---|---|---|
| F1 | `DownloadRecursive`, link: `Stat` fails | "not a directory" -> download as a file | unchanged reading, but `DownloadOneFile` stops at once on a lost session (no request, one box) |
| F2 | `DownloadOneFileImpl`, new pre-stat fails | - | lost -> fail the item; a server's refusal -> go on, the open reports |
| F3 | `RemoveMovedFile`: `Stat` fails | size unknown -> source kept (already fail-closed) | same; stops before it on a lost session, and the message is the lost connection |
| F4 | `DownloadDirLevel`: listing complete with 0 entries -> `Rmdir` (move) | fact | a fact only from a live answer (`ListDir` FALSE otherwise); the session may die in `closedir` -> checked before `Rmdir` |
| F5 | `DeleteRecursive`: the same for `Rmdir` | fact | same check |
| F6 | `DeleteRecursive`: `Unlink` / `Rmdir` FALSE | "the server refused" -> next item | lost -> stop everything, one box |
| F7 | `UploadDirLevel`: `Mkdir` failed, `Stat` says directory -> fine | fact | `Stat` on a dead session is FALSE -> the folder fails (nothing below is sent) |
| F8 | `UploadOneFileImpl`: `StatEx(target)` | 139: `sxError` fails the item | a gated / dying call is `sxError`, never `sxNotFound` |
| F9 | `UploadSendAndConfirm`: `Stat` for the size | unknown -> not confirmed (139) | same; no further request follows on a lost session (temp removal is gated - the box names the temp that stays) |
| F10 | `UploadPlaceTemp`: `StatEx(temp) == sxFound` -> `Unlink(target)`; `Unlink` ok -> `Rename` | 139: needs a live session and a status | re-read: every branch that acts needs `sxFound` / TRUE from a live answer; nothing changed |
| F11 | `UploadOneFileImpl` `DeleteFileW`, `UploadDirLevel` `RemoveDirectoryW` (move) | after `xrOk` | also not when the session was lost after the confirmation (D6) |
| F12 | `CSFTPSession::Chown`: `stat` of the current owner fails | "uid and gid are 0" - the field that was to stay was sent as 0 (root) | the call fails with the reason; nothing is sent. With both fields given the stat is not sent at all |
| F13 | `fs.cpp` `ChangePath`: `RealPath` fails -> path as asked; `Stat` fails -> "does not exist", cut a component, again - down to `/` | after a timeout the panel went to the root (after the reconnect in `ListCurrentPath`) | lost -> box, FALSE |
| F14 | `fs.cpp` `ListCurrentPath`: `Stat` of a link's target fails -> `LinkBroken` | fact | only on a live session |
| F15 | `ChmodRecursive` / `ChownRecursive`: listing fails -> log, go on | - | counted; lost -> stop |
| F16 | `fs.cpp` `QuickRename`: `StatEx(to)`, the case-only listing | 139: `sxError` / failed listing refuses | unchanged (a dying call is `sxError`) |
| F17 | `fs.cpp` `ListCurrentPath`: listing fails -> `LastFailedListPath` -> `ChangePath` shortens the path | "this directory cannot be listed" | **left** (D7) |

## 5. Decisions where the brief left room

- **D1 - one box, which one.** The first failure met on the dead session shows ITS OWN box:
  the item's template and path, and as the reason the session's text
  (`Cannot delete "/x/f10.txt": The connection to the server was lost. (API timeout
  expired)`). A reason of the caller's that says something else (a fixed sentence, "the
  complete new file is left as .tcpart-…", "the temporary file … could not be removed")
  follows after " - ", so nothing an upload has to tell is lost. Every later failure goes to
  the log only. Where the step has no box of its own (before an item, a failed read, the end
  of Change Attributes) the plain box with the same sentence is shown instead. Never both,
  never a second. This keeps 139's rule ("the item's box counts") and makes that box name the
  lost connection - 139's box could be "Cannot read from the remote file." alone.
- **D2 - cancel.** `ReportSessionLost` shows nothing once the user has stopped the operation.
  `ShowRequestError` still shows its box after a stop (an upload's "the complete new file is
  left as …" must be said also then, as in 139).
- **D3 - the seam of 133** (`TC_SFTP_PROBE_LIST_FAIL`) injects `SOCKET_TIMEOUT` into the
  listing. With `NoteFailure` in the `readdir` loop it would now end the session and the rows
  LISTCOPY / LISTMOVE / LISTPANEL would test another path than they were written for; the
  seam's failure is therefore not passed to `NoteFailure`. A REAL readdir timeout ends the
  session.
- **D4 - special files, where.** `DownloadOneFileImpl` starts with `Stat(path, follow)` unless
  the listing showed a regular file that is not a link (`knownRegular`) - a healthy download
  of ordinary files sends no extra request. Special -> `IDS_ERR_DOWNLOAD` + "not a regular
  file (a device, FIFO or socket).", failed, before the local file is looked at (no question,
  nothing created). A link is stat'ed twice (`DownloadRecursive`, then here). A listing entry
  that is itself a device / FIFO / socket takes the same path (its mode is not REG). A
  **directory** reached here (a top-level item without a mode, or a link whose first stat
  failed): as before - the open goes ahead and the server's answer is reported; `sdkDirectory`
  is not refused.
- **D5 - `ViewFile` (beyond the brief).** F3 on a link to `/dev/zero` filled the viewer's
  cache without an end (it has a Cancel). The same check was added there (FR-003 says "opened
  for a download"); the item's listing mode saves the request for a regular file.
- **D6 - "no action after the loss" is taken strictly on the removing side**: a moved local
  file / folder and a moved remote directory stay when the session died after their transfer
  was confirmed (only a later request - removing a spare temporary file, closing a listing -
  can do that). Harmless: both copies exist. **Not** applied to the local finish of a
  download: when all data arrived (the server's EOF) and only the close of the remote handle
  timed out, the complete temporary file still replaces the local file - that is decided by
  what was read before the loss.
- **D7 - `LastFailedListPath` is set also after a timeout**: the panel then goes to the parent
  directory (after the reconnect). Not setting it lets the core list the same path again,
  and a server that keeps timing out would show the box in a loop. Left as it was.
- **D8 - `ChangePath` ends with FALSE** (a clean error) instead of reconnecting and trying
  again inside the same call. What the core does with FALSE (it may leave the path) is as for
  the existing FALSE returns of this function.
- **D9 - Change Attributes on a lost session returns TRUE as before**; the panel refresh that
  follows reconnects. The same already holds for Delete and Move.
- **D10 - the box of refused attribute changes is shown also after the user stopped the
  operation** (they are facts); the lost-connection box is not.
- **D11 - a refused `SetMTime` uses the `IDS_ERR_CHMOD` template** ("Cannot change
  permissions of … : the time was not set: <reason>") - no other template without a new
  string.
- **D12 - the log** now also gets the item boxes that 131 / 133 showed without logging
  (listing, delete, rmdir), and `ReportSessionLost`'s text.

## 6. Upload side of special files

`UploadOneFileImpl` opens the local file with `CreateFileW(GENERIC_READ)`; device names are
not reachable through a path the panel enumerates. Left. A REMOTE target that is a device /
FIFO is written in place after the question (139, D2) - not changed here.

## 7. Not done

- No probe run, no build of the product tree, no review, no `fix-log.md`, `CHANGELOG.md`,
  `FEATURE-HISTORY.md`, `NEXT-WORK.md`; `tasks.md` not ticked.
- Attribute rows cannot be driven by the test account (plan.md) - by review only.
- `ViewFile`: a failed `OpenRead` / read still shows no message at all (as before).
- Orphaned `.tcpart-*` / the handle leak of section 3: not cleaned up.
- Which mode a recursive chmod gives to directories: out of scope (spec, Assumptions).

## 8. Not sure / to look at

- **A malformed answer** (`SFTP_PROTOCOL` without a status, section 2) leaves a request
  "sent"; handled only by the timeout that follows. Marking the session dead for "protocol
  error and `libssh2_sftp_last_error() == FX_OK`" would close it, but `sftp_posix_rename` does
  not reset `last_errno` (139, S3), so the test is not reliable for every request.
- `SetLastErrorFromSsh` still calls `NoteTransportError(0)` on the session's LAST errno, which
  the library does not clear on success: a failure that records no error of its own (e.g.
  `BUFFER_TOO_SMALL`) could in theory be classified by an older code. Unchanged from 051;
  every older dead code has already ended the session, so it cannot turn a live session dead.
- `ENCRYPT` / `MAC_FAILURE` / `ZLIB` / `COMPRESS` in the list: by reasoning, not by test.
- `Chown` (F12) is a behaviour change on a healthy connection: "set the group only" on an item
  whose `stat` (links followed) fails - a dangling link - now reports that failure instead of
  sending uid 0. Recursive Change Owner skips links anyway.
- The text of the dead-session box depends on which request died:
  `… was lost. (API timeout expired)` / `(Timed out waiting on socket)` /
  `(opendir: …)` / `(close: …)`. The probe's test is the word "connection".
- DEADMOVE: with `knownRegular` the seam fires in `OpenRead` of `f10.txt` (not in a stat); in
  `RemoveMovedFile` the stat of the files before it does not match the suffix. If the fixture
  lists `f10.txt` first, nothing is local and 30 files stay - the row's sums still hold.
- `ShowRefused` runs after `DestroySafeWaitWindow`; all other boxes of the operations are
  shown while the wait window exists (as before).
- A copy whose very last request (the close of the last file or listing) timed out ends as a
  success without a box; the next operation reconnects.

## 9. After the review

No critical finding; three medium and five low ones, all changed in `src/plugins/sftp/` only
(`fs.h` is new in the list of edited files). Where this section and sections 3 - 8 differ,
this one holds (named below).

Checks after the changes: unit harness **217 passed, 0 failed** (the 24 checks of the old code
list were replaced by 24 of the new rule - the same total by chance); `cl /Zs` of
`operats.cpp`, `session.cpp`, `fs.cpp`, `sftputils.cpp`, Debug and Release defines, `/W3`:
exit 0, no warning; the plug-in project built Debug x64 and Release x64 **into the scratch
output directory** again: links; `tools/check_encoding.py`: `TOTAL: 0`; line endings / BOM
unchanged per file. The product tree was not built (GUI probes were running on it).

### What changed

- **M1, `ChangePath` reconnects instead of failing** (`fs.cpp`, new
  `CPluginFSInterface::ReconnectLostInChangePath`, declared in `fs.h`). When `RealPath` or a
  `Stat` of the loop ends the session, `EnsureConnected` is called (it tears the dead session
  down and connects with the kept parameters, with its own wait window and, on failure, its
  own box) and the path is resolved again from `RealPath` (`goto RESOLVE_PATH`; `pathWasCut`
  and `cutFileName` are reset). Once per call: a second loss shows the session's text and
  returns FALSE; so does a failed or stopped reconnect (no box of ours). In the success case
  nothing is shown beyond the reconnect's wait window. **D8 of section 5 is replaced by this.**
- **M2, `SftpRcIsDeadTransport` is inverted**: every negative return code is "dead" except
  `SFTP_PROTOCOL` (-31), `BUFFER_TOO_SMALL` (-38), `BAD_USE` (-39). The table of section 3 no
  longer holds. `ALLOC` (-6) is **not** excepted: besides real memory failures (which the
  reviewer saw leave the request states idle) it is the code the packet reader returns for an
  SFTP packet of an impossible length (`sftp.c:337-340`, "Invalid SFTP packet size") - a
  stream out of step; the two cannot be told apart by the code, so: dead. `INVAL`,
  `OUT_OF_BOUNDARY`, `CHANNEL_PACKET_EXCEEDED`, the re-key codes: dead by the rule. Nothing
  else was shown to leave every state idle AND the stream usable.
- **M3, the last errno is judged by a narrow list**: new `SftpErrnoIsDeadTransport` (the five
  codes of 051: `TIMEOUT`, `SOCKET_TIMEOUT`, `SOCKET_SEND`, `SOCKET_RECV`,
  `SOCKET_DISCONNECT`; never `EAGAIN`). `NoteTransportError(rc)`: `rc != 0` -> the return-code
  rule; `rc == 0` -> the last errno by the narrow list (the only caller left on that route is
  `SetLastErrorFromSsh`). Real return codes are passed everywhere a call has one. The four
  pointer-returning calls (`opendir`, the three opens) have none: new
  `FailedPointerCallCode()` reads the last errno right after the NULL - there it IS the code
  of that failure (every NULL path records one; `BLOCK_ADJUST_ERRNO` leaves only with a code
  other than EAGAIN or after `_libssh2_wait_socket` has cleared and re-recorded the error) -
  and still maps EAGAIN to 0, so EAGAIN from the errno can never end a session.
- **L1 / L2, a `.tcpart-*` that stays is always named**: new `UploadTellStrayTemp` - a box of
  its own, `IDS_ERR_DELETE` with the temporary file's path and
  `<why the removal failed> (a temporary file of the upload of <name>; it can be deleted)`.
  Called where no error box of the upload follows: the upload stopped by the user (temp
  route, and the second pass stopped before its open), the second pass that SUCCEEDED (the
  item stays `xrOk`), and the empty temp of a file that then goes in place. On a lost session
  that box counts as the one about the connection (its reason is the session's text).
- **L3**: `ShowRefused` - refusals counted and the connection lost later: ONE box,
  `<lost-connection text>` + blank line + `Before that: Cannot change … "<first path>":
  <reason> (and N more refused; see the log)`. New `COperationCtx::LostText`.
- **L5**: `DownloadOneFile(…, int knownKind)` replaces `knownRegular`: the link branch of
  `DownloadRecursive` hands on what its own stat found (`CSftpDownloadKind`; a refused stat =
  `sdkUnknown`), so a link costs one stat. `-1` = not known, asked in `DownloadOneFileImpl`
  (an entry without a regular-file mode). **D4's "a link is stat'ed twice" no longer holds.**
- **L8**: `LogListFailure` is removed; a failed sub-listing of chmod / chown writes the one
  line of `NoteAttrRefused` ("Cannot change … : its items were not changed, the directory
  cannot be listed: <reason>").

### Decisions taken here

- **R1 - a dangling link is not asked about twice**: the link branch passes `sdkUnknown` when
  the server refused its stat, and the open reports - as before 140.
- **R2 - `UploadTellStrayTemp` shows its box even when the lost connection was already
  said** (it cannot have been within the same item; the name of the file matters more than
  the count of boxes).
- **R3 - the errno route keeps exactly the list of 051**, not the wider one of section 3: a
  channel-closed or MAC error reaches the session as a RETURN code of the failing call, where
  the inverted rule catches it.

### Not sure / to look at

- With the inverted rule a wrong-argument error other than `BAD_USE` ends the session:
  `OUT_OF_BOUNDARY` of `sftp_posix_rename` for paths whose lengths overflow a packet
  (`sftp.c:3044`) - not reachable with 4,096-byte paths. A real out-of-memory in a request
  now ends the session too (reconnect on the next operation).
- `ChangePath` after the reconnect starts from the path as asked; the two prompts of the
  first open (password) are before the label and are not repeated.
- M1 was not driven: it needs a connection that dies while idle without the keepalive
  noticing (Ctrl+R then waits for the operation timeout, reconnects, stays on the path).
