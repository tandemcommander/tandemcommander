# Implementation Plan: SFTP - dead session, special files, refused attribute changes

**Branch**: `140-sftp-dead-session` | **Date**: 2026-10-14 | **Spec**: [spec.md](spec.md)

## Summary

`src/plugins/sftp/session.cpp/.h`, `operats.cpp`, `sftputils.cpp/.h`, `fs.cpp`:

- **Session gate**: every request method of `CSFTPSession` (RealPath, ListDir, Stat, StatEx,
  ReadLink, Mkdir, Rmdir, Unlink, Rename, Symlink, Chmod, Chown, SetMTime, OpenRead, OpenWrite,
  OpenWriteNew, Read, Write, SeekWrite users, CloseHandle / CloseHandleChecked) (a) returns its
  failure at once, without calling libssh2, when the session was marked dead (`Connected ==
  FALSE` while `Sftp != NULL`), with the error text "the connection to the server was lost",
  and (b) passes every failure through `NoteTransportError`. The pure part - "is this libssh2
  return code a dead transport" - moves to `sftputils` (`SftpRcIsDeadTransport`) with harness
  checks. Handles of a dead session are not closed through the library (a close would resume
  the half-done request); they are released by `Disconnect`.
- **Operation loops**: `COperationCtx` gets `SessionLost()` (session not connected) and
  `ReportSessionLost()` (one box per operation; 139 has the flag for transfers). Every loop -
  download, upload, delete (`DeleteRecursive`), attributes, owner, the top-level item loops -
  tests it before each item and after each failure: stop, no further box for the items that
  only failed because the session is dead, no removal after it.
- **Special files**: pure `SftpDownloadKind(hasMode, mode)` -> regular / directory / link /
  special / unknown. `DownloadOneFile` stats the path following links before `OpenRead` (the
  listing's mode is the link's own) and refuses "special" with `SFTPShowPathError(...,
  "not a regular file (a device, FIFO or socket).")`; result failed (a move keeps it).
- **Attributes**: `ChmodRecursive` / `ChownRecursive` count refusals in `COperationCtx`, keep
  the first path and reason; after the loop one box (`IDS_ERR_CHMOD` template with the first
  item and reason + " (and N more; see the log)" as part of the reason). `SetMTime` likewise.
- **Seam** (debug only): `TC_SFTP_PROBE_TIMEOUT_AT = "<path suffix>"` - the first Stat / open /
  unlink of a matching path behaves as a timed-out request (marks the session dead through the
  same code path as a real `LIBSSH2_ERROR_TIMEOUT`).

## Technical Context

- Probe rows in `specs/133-sftp-server-verify/probe/sftp133_probe.ps1` + `fixture133.sh`:
  DEADCOPY, DEADDEL, DEADMOVE (seam at `f10.txt`), SPZERO (link to `/dev/zero`), SPFIFO.
  "Before" on 0.1.9 only for SPZERO (bounded by the probe's time limit); the seam rows have no
  "before" - the old behaviour is read from the code and the library and recorded as such.
- Attribute rows need a file the account may not change (another owner) - the test account
  cannot create one; NOT DRIVEN, owed to a person, verified by review.

## Constitution Check

Never lose the user's data: fail closed after a lost connection. No interface change, no new
strings.

## Structure

1. Spec, plan, tasks. 2. Seam + rows, "before". 3. Code. 4. Rows, review, records, commit.
