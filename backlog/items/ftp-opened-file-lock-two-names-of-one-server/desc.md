---
title: FTP: two operations under two names of one server can open one file at the same time
type: bug
status: in-progress
severity: 7
area: ftp
source: review:341
who: agent
created: 2026-10-24
updated: 2026-10-31
verified: 2026-10-31 794b3207
effort: S
feature: 347
related: [ftp-server-path-compare-code-page-fold]
depends-on: []
reason: -
---

# FTP: two operations under two names of one server can open one file at the same time

## Problem

The FTP plug-in keeps a lock of the server files its operations have open (`FTPOpenedFiles`), so
that two uploads of one file, or an upload and a download of it, never run at the same time. The
lock identifies the server by the host as typed: an operation to `ftp://u@localhost/...` and one to
`ftp://u@127.0.0.1/...` (a server's name and its address, two names or two addresses of one
server) do not see each other's lock, and both can write the same server file at once - the result
is whichever store finishes last, or a mixed file, without any question. Feature 341 made the
upload listing cache treat every other host name of the same user and port as maybe the same
server; the lock still does not.

## Evidence

By reading at 1468b771 (review 2 of feature 341, NOTE N4, `specs/341-ftp-upload-cache-alias/fix-log.md`
*Review*): `CFTPOpenedFile::IsSameFile` (`src/plugins/ftp/operats9.cpp`) compares
`SalamanderGeneral->StrICmp(Host, host) == 0` with the user (`strcmp`) and the port;
`CFTPOpenedFiles::OpenFile` refuses a conflicting access only for a matching entry
(`CFTPOpenedFile::IsInConflictWith`). Not measured.

## Expected

Two operations that may reach one server file under two host names of the same user and port do
not write it at the same time: the second waits or is refused, as for one name.

## Notes

Severity 6 because not measured (narrow scenario: two names of one server, the same file, at the
same moment); if a probe shows two concurrent `STOR` of one file, raise it to 7. The probe of
feature 341 (`specs/341-ftp-upload-cache-alias/probe/ftp341_probe.ps1`, second server on 127.0.0.2
through `ftpmini_at.py`) can drive it. Treating every other host as the same file would make two
uploads to two different servers with the same user, port and path wait for each other - a cost
to weigh.

## Log

- 2026-10-24 — created (source review:341)
- 2026-10-30 — moved to Next position 1
- 2026-10-31 — verified at 794b3207: probe ftp347 on main: uploads under localhost and 127.0.0.1 sent two overlapping STOR of one file, server file ended with the 2nd content
- 2026-10-31 — severity 7: probe ftp347 measured two concurrent STOR of one file (the Notes rule)
- 2026-10-31 — run started, feature 347
