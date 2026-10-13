# Implementation Plan: SFTP - nothing replaced without a question

**Branch**: `139-sftp-no-silent-overwrite` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

## Summary

`src/plugins/sftp/operats.cpp`, `session.cpp/.h`, `fs.cpp`, `sftputils.cpp/.h`:

- **Upload** (`UploadOneFile`): `lstat` the target. A directory: error. An existing file: the
  question (`ConfirmOverwriteRemote`, the twin of the local one; Cancel = skip the rest). Then
  the data go to a temporary name in the same directory (`<name>.tcpart-<8 hex digits>`,
  pure helper `SftpTempName`), the size the server reports for it is compared with the local
  size, the old file's permission bits are applied, and `Session.Rename(temp, target,
  replace = TRUE)` puts it in place; any failure removes the temporary file and leaves the
  target untouched. Exceptions that write in place (after the question): the target is a
  symbolic link; the temporary file cannot be created.
- **Download** over an existing local file (not a resume): into `<name>.tcpart-<hex>` beside
  it, then `SalReplaceWithTempW` (`src/common/salsafereplace.h`, feature 105).
- **Rename**: `CSFTPSession::Rename(from, to, BOOL replace)`. Quick Rename passes FALSE: plain
  `SSH_FXP_RENAME` (the server itself refuses an existing target - no window between a check
  and the rename) after an `lstat` of the target for a clear message.
- **Upload as a whole** is restructured like the download of 138: `UploadOneFile` and
  `UploadDirRecursive` return the tri-state (`xrOk` / `xrSkipped` / `xrFailed`) and carry
  `move`; a file removes its local source after its upload is confirmed, a folder after all its
  items were moved; `DeleteLocalTree` (delete by re-listing) is removed. A failed remote
  `Mkdir` (and the target not being a directory), a failed `FindFirstFile` / `FindNextFile` are
  failures. Only name-surrogate reparse points (`IsReparseTagNameSurrogate`: junctions,
  symbolic links) are skipped - said once per operation; other reparse tags (cloud files) are
  traversed. The per-level buffers (about 30 KB) are one heap block per level.
- The files a download wrote are remembered by `salsamefile.h`'s identity (the 128-bit id,
  all-zero ids rejected) instead of the hand-made volume + index pair of 138.
- A probe seam (debug only) `TC_SFTP_PROBE_XFER_FAIL = "<name suffix>;<bytes>"` makes a
  transfer of a matching file fail after that many bytes - for "before" and "after" rows.

## Technical Context

- Probe: rows UPASK (No / Yes), UPFAIL, UPNEWFAIL, DLFAIL, RENEXIST in
  `specs/133-sftp-server-verify/probe/sftp133_probe.ps1` + `fixture133.sh` (the probe gets a
  local source panel: the row's local folder on the active side, the server on the other).
- No new strings; the harness checks `SftpTempName`.

## Constitution Check

Never lose the user's data: replace only by a complete file (rule of 105 / 110 / 113), ask
before replacing; verified by content on both sides.

## Structure

1. Spec, plan, tasks. 2. Seam + rows, "before". 3. Code. 4. Rows, review, records, commit.
