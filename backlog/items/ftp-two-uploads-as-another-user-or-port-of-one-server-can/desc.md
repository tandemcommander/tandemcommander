---
title: FTP: two uploads as another user or port of one server can store one file at once
type: bug
status: new
severity: 6
area: ftp
source: measure:347
who: agent
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# FTP: two uploads as another user or port of one server can store one file at once

## Problem

The FTP plug-in's opened-file lock (`FTPOpenedFiles`) keeps two operations of one program from
storing one server file at the same time. Feature 347 made it ignore the host name (two names of
one server), but it still tells two users or two ports apart: an upload running as user `v`
(`ftp://v@host/...`) and an upload as `u` into a panel at the same host both store the same file at
once - two accounts that share folders, or one server reached through a forwarded port. The second
store replaces the first without any question (feature 345 found such shared accounts and ports for
the upload listing cache).

## Evidence

Measured at 794b3207 and again on branch 347-ftp-lock-two-names: probe
`specs/347-ftp-lock-two-names/probe/ftp347_probe.ps1`, row OTHER-USER (facts only) - upload 1 of
`hold.txt` typed to `ftp://v:p@127.0.0.1:2147/OTHER-USER` (its STOR held 20 s by
`ftpmini_hold.py`), upload 2 by F5 into the panel at `ftp://u@127.0.0.1:2147`: 2 STOR hold.txt, 1
while the other was in flight, server file 'UP2', both operations "(100 %)"
(`probe/result_main.txt`, `probe/result_after.txt`). Site: `CFTPOpenedFile::IsSameFile`
(`src/plugins/ftp/operats9.cpp`), `strcmp(User, user) == 0 && Port == port`.

## Expected

Two operations that may reach one server file as two users or through two ports of a server do not
write it at the same time: the second is refused "in use" (or waits), as for one connection. The
probe row OTHER-USER turns into a PASS row (no overlapping STOR); a port variant (a second listener
on another port serving the same folder) likewise.

## Notes

Severity 6: measured data loss, but it needs two accounts (or ports) that reach the same folder and
two uploads of one file at the same moment. Cost to weigh: ignoring user and port too makes every
conflicting access to a file with the same path and name on any connection wait for (be refused
during) the other - also for unrelated servers and accounts whose home folders differ but whose
paths look alike (`/index.html`). Feature 345 took the same "maybe the same server" step for the
upload listing cache (`ftp-two-uploads-under-different-connections-can-stall-each` records its
cost). Related: `ftp-opened-file-lock-two-names-of-one-server` (feature 347, the host-name part).

## Log

- 2026-10-31 — created (source measure:347)
- 2026-10-31 — related item ftp-opened-file-lock-two-names-of-one-server done in feature 347
