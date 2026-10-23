---
title: FTP 323 by hand: Send FTP Command during an open upload, then an upload asks before overwriting
type: person-step
status: open
severity: 6
area: ftp
source: leftover:323
who: person
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# FTP 323 by hand: Send FTP Command during an open upload, then an upload asks before overwriting

## Problem

Feature 323 made a command sent with Send FTP Command (FTP plug-in menu) invalidate every cached
listing of the server that a running upload consults, so that a folder Create Directory (F7) had
recorded as new and empty is listed again before the upload decides whether a name exists. The
hidden-desktop probe cannot reach that menu command, so this path is checked by reading only.

## Evidence

`specs/323-ftp-upload-cache-args/fix-log.md` (Analyze C1) and `fix-log-302.md` (review 1):
`CUploadListingsOnServer::ReportUnknownChange` -> `InvalidateAllListings()` (`src/plugins/ftp/operats9.cpp`),
called from Send FTP Command (`fs3.cpp`) only when "Command can make changes on working path
(refresh working path)" is ticked (the default).
The other rows of the change are driven by `specs/323-ftp-upload-cache-args/probe/ftp302_probe.ps1` (16 / 0).

## Expected

After a typed FTP command changes a folder that F7 made during an open upload, the next upload
into that folder lists it on the server and asks before overwriting a file of the same name.

## Steps

- [ ] Any FTP server you can write to (a test account). Left panel: a local folder with `o1.txt`
      and `f.txt` (content `LOCAL`). Right panel: an FTP folder `/t` holding `o1.txt`.
- [ ] Copy `o1.txt` to `/t` (F5) and leave the "Target File Already Exists" question open - the
      upload stays in progress.
- [ ] In the FTP panel at `/t`, press F7 and create `new`.
- [ ] FTP plug-in menu -> Send FTP Command, with "Command can make changes on working path
      (refresh working path)" ticked, send
      `RNFR o1.txt`, then again `RNTO new/f.txt` (puts a file `f.txt` into `new`).
- [ ] Copy the local `f.txt` into `/t/new` (F5): expected - the "Target File Already Exists"
      question appears for `f.txt`, and the server's `/t/new/f.txt` keeps the content of the old
      `o1.txt` unless you choose to overwrite.

## Log

- 2026-10-23 — created (source leftover:323)
- 2026-10-23 — moved to Person steps position 6
