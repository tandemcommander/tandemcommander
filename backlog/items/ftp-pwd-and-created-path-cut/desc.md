---
title: FTP: a PWD reply or a created folder path that does not fit is cut and used
type: bug
status: in-progress
severity: 4
area: ftp
source: manual
who: agent
created: 2026-10-20
updated: 2026-10-21
verified: 2026-10-21 65c337dc
effort: M
feature: 277
related: [ftp-long-name-and-path-leftovers]
depends-on: []
reason: -
---

# FTP: a PWD reply or a created folder path that does not fit is cut and used

## Problem

Part of `ftp-long-name-and-path-leftovers` (split at 4c6fd132). The FTP plug-in still cuts a server path at its 301-byte buffer (`FTP_MAX_PATH`) in a few places and then works on the result:

- **PWD reply** (`FTPGetDirectoryFromReply`): the German AIX form (`257 '/path' ist das aktuelle Verzeichnis.`) is cut at 300 bytes and returned as success; and a code-page path (legacy server) whose UTF-8 form is longer than the buffer is cut by `FTPDecodeServerReplyPathInPlace`, possibly inside a letter. The panel then shows and works in an ancestor under its own name. (The RFC 959 form `257 "/path"` is refused when it does not fit - the connection is closed with "cannot get the working directory" - but already at 300 bytes, one byte before the buffer is full.)
- **Created folder** (`CUploadListingsOnServer::ReportCreateDirs`): the typed relative name of Create Directory (`newName`, up to 2 * MAX_PATH) is cut to 300 bytes before its components are reported to the upload listing cache - the last, cut component is recorded as a created folder; `FTPCompleteAbsolutePath` (OS/2 drive, VMS device prefix) cuts the end of an absolute name to fit.
- **AS/400 member name** (`FTPAS400CutFileNamePart`): cut to MAX_PATH; used as the download target name (`fs4.cpp`) and the upload's (`operats6.cpp`).
- **Opened-file lock** (`CFTPOpenedFile::IsSameFile`): names on a case-insensitive server are compared with `StrICmp` (code-page case table on UTF-8 bytes), not the file-system rule of 092 (`SalNameEqualOrdinalCI`, header-only `salnameorder.h` for plug-ins) - two different non-ASCII names may match, or two case twins may not (the lock is off).
- **Upload link size** (`fs5.cpp`, the upload's queue build): the local source path is cut into `linkName[MAX_PATH]` and the link's target size is read from the cut path + name (another file's size; only the size estimate).

## Evidence

By reading at 4c6fd132 (measured during the split run, no probe):
- `src/plugins/ftp/ftputils.cpp:1744-1748` (AIX branch: `if (len >= dirBufSize) len = dirBufSize - 1;` then `return TRUE`), `:1709` (`lstrcpyn(dirBuf, u8, dirBufSize)` in `FTPDecodeServerReplyPathInPlace`), `:1758-1759` (quoted form: the loop stops at `d == endDir`, `ok` stays FALSE). Callers: `ctrlcon3.cpp:806` (`GetCurrentWorkingPath` - FALSE closes the connection), `ctrlcon5.cpp:582` (Create Directory's 257 reply), `operats7.cpp:594` (explore-dir PWD), `operatsa.cpp:726` (upload target PWD).
- `src/plugins/ftp/operats9.cpp:565` (`lstrcpyn(relPath, newDirs, FTP_MAX_PATH)`), `ftputils.cpp:2193` / `:2218` (`FTPCompleteAbsolutePath` shortens `l`).
- `ftputils.cpp:3353` `FTPAS400CutFileNamePart` (`lstrcpyn(mbrName, mbrBeg, MAX_PATH)`); callers `fs4.cpp:1129`, `operats6.cpp:1543`.
- `operats9.cpp:1852-1857` `CFTPOpenedFile::IsSameFile`.
- `fs5.cpp:1149-1151` `linkName` and its use with `GetLinkTgtFileSize` (:1185).
- Origin: the audit of feature 215 (`specs/215-ftp-long-name-command/fix-log.md`, *Review*, last paragraph) and 233 (`specs/233-ftp-long-server-paths/fix-log.md`, *Measured*, last bullet: "a PWD reply longer than 300 bytes is the one input left that `lstrcpyn` cuts").

## Expected

A PWD / 257 reply whose path (in UTF-8) does not fit is refused as the RFC form already is (never an ancestor under the deep folder's name), and a path of exactly 300 bytes is accepted; `ReportCreateDirs` invalidates the affected listing instead of recording a cut component; `FTPCompleteAbsolutePath` and `FTPAS400CutFileNamePart` fail instead of cutting and their callers refuse; the lock compares names by the 092 rule; a source path that does not fit `linkName` leaves the link size unknown (as a too long name does now). A probe with 215's `ftpmini.py` (an option for a long home folder in the AIX form and in cp1250) shows the refusal.

## Approach

`FTPGetDirectoryFromReply` already returns FALSE for the quoted form and every caller handles FALSE; give the AIX branch and the decode the same failure (decode into a heap string, fail when it does not fit). Measure first: add a PWD-reply override to `ftpmini.py` (224's probe has the cp1250 mode).

## Notes

Measured narrower than the original item said: the plain RFC 959 PWD reply over 300 bytes is refused, not cut. The original's "FTP download target name in `fs4.cpp` cut at a byte (cosmetic)" was not found at 4c6fd132 - the source description is whole since feature 178 and a target name that does not fit is refused since 215; check and drop it if so.

## Log

- 2026-10-20 — created (source manual)
- 2026-10-20 — moved to Next position 15
- 2026-10-21 — verified at 65c337dc: probe ftp277 at 65c337dc: AIX-form PWD of 305 bytes cut to 300, after a reconnect the ancestor file was downloaded under the deep folder name; cp1250 decode cut and CWD sent; RFC 300-byte path refused; other sites by reading
- 2026-10-21 — run started, feature 277
