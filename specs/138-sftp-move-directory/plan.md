# Implementation Plan: SFTP - move of a directory

**Branch**: `138-sftp-move-directory` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

## Summary

`src/plugins/sftp/operats.cpp`:

- `DownloadOneFile` reports "complete" only when the local file was closed without error
  (`FlushFileBuffers` + `CloseHandle` checked) - today a failed close is not seen.
- `DownloadRecursive` / `DownloadDir` get the `move` flag. A **file** that came back `xrOk` is
  removed from the server by `RemoveMovedFile`: the source is `Stat`-ed again, the local file's
  size is read, and only when both are known and equal the file is unlinked. A **directory** is
  removed (`Rmdir`) only when every item in it came back "moved" - the same "every item is
  gone" rule `DeleteRecursive` got in 133.
- A new result `xrKept`? No - the tri-state stays; a file that was copied but could not be
  removed makes the result `xrFailed` for the move (the copy stays, the source stays, the
  message says why), so every parent directory is kept.
- `SFTPDownloadFromPanel`: the top-level "best-effort" `Rmdir` / unchecked `Unlink` go; the
  same helper decides.
- The decision "may this source be removed" is a pure function in `sftputils.h/.cpp`
  (`SftpMoveMayRemove(transferResultOk, localSizeKnown, localSize, remoteSizeKnown,
  remoteSize)`) with checks in the plug-in's harness.

## Technical Context

- Probe: `specs/133-sftp-server-verify/probe/sftp133_probe.ps1` + `fixture133.sh`: M1 expects
  the directory gone; new rows MTREE (sub-directories, an empty directory), MKEEP (one
  unreadable file in the tree), MSKIP (an existing local file, answer No); LISTMOVE and P5M
  stay "nothing removed".
- Container `tandem-sftp`. No new strings (`IDS_ERR_DELETE`, `IDS_ERR_RMDIR` exist).

## Constitution Check

Never lose the user's data: the removal fails closed (not everything checked = kept); verified
on the server's state by the probe, including the build before.

## Structure

1. Spec, plan, tasks. 2. Probe rows, "before" on the current build. 3. Code + harness checks.
4. Rows again, review, records, commit.
