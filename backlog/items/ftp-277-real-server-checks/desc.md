---
title: FTP 277 on real servers: long PWD paths, AS/400 member names, case-insensitive lock
type: person-step
status: open
severity: 3
area: ftp
source: leftover:277
who: person
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: M
feature: -
related: [ftp-real-server-checks-090-116-121]
depends-on: []
reason: -
---

# FTP 277 on real servers: long PWD paths, AS/400 member names, case-insensitive lock

## Problem

Feature 277 (the FTP plug-in refuses a PWD / 257 path, a created folder name, an AS/400 member name that does not fit instead of cutting it; the opened-file lock compares names by the 092 rule; the upload's link size from a cut source path) was measured against the local test server `ftpmini.py` only (AIX reply form and a cp1250 server emulated). The AS/400 member-name, OS/2 / VMS created-folder, lock and link-size parts were checked by reading; no real AIX, AS/400, OS/2 or VMS server was available.

## Evidence

`specs/277-ftp-pwd-path-cut/fix-log.md`, *Measured after* (the "Not driven" paragraph); probe `specs/277-ftp-pwd-path-cut/probe/ftp277_probe.ps1` (`result_after.txt` PASS 10 / FAIL 0).

## Expected

Each step below gives the result it names; results recorded in `specs/277-ftp-pwd-path-cut/fix-log.md`.

## Notes

Optional confirmations - the defect the item was about (an ancestor's file downloaded under a deep folder's name) is proven by the probe and its control on the old code. Severity 3: the parts left are rare server types.

## Steps

- [ ] On an AIX (or any) FTP server, copy (F5) a folder reached through a symbolic link whose real path is longer than 300 bytes: the copy reports "Error Getting Working Path On Server" for it; nothing of another folder is downloaded.
- [ ] On an AS/400 server (`/QSYS.LIB`), download a member (F5) from the panel and a folder of members: the local names are the member names (`X.MBR`), whole.
- [ ] On a Windows (IIS) FTP server, start a download of `Č.txt` and, while it runs, an upload of `č.txt` into the same folder: the second operation does not work on the file at the same time (it waits or reports that the file is in use by another operation - the lock).
- [ ] On an OS/2 or VMS server, Create Directory with an absolute name (`/a/b` or `[A.B]`), then upload into the new folder: the upload finds the folder (no "cannot create" for an existing folder).

## Log

- 2026-10-21 — created (source leftover:277)
- 2026-10-21 — moved to Person steps position 21
