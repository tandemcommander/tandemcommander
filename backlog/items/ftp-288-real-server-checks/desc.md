---
title: FTP 288 on real servers: names to a code-page server, mainframe listings
type: person-step
status: new
severity: 4
area: ftp
source: leftover:288
who: person
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: M
feature: -
related: [ftp-277-real-server-checks]
depends-on: []
reason: -
---

# FTP 288 on real servers: names to a code-page server, mainframe listings

## Problem

Feature 288 (each FTP server gets names in its own encoding, learned from its listings; never a best-fit look-alike; a name sent in UTF-8 before stays UTF-8) was measured only against the local test server `ftpmini.py` in a cp1250 and a UTF-8 mode on a machine with the system code page 1250. A real old code-page server (IIS 6, an old Serv-U, a Windows FTP service with "UTF-8" off) and the mainframe server types whose listing rules re-assign the name (AS/400, z/VM CMS, VxWorks) were not available.

## Evidence

`specs/288-ftp-per-server-encoding/fix-log.md` *Measured (after)*, *Review 1*, *Review 2* (NOTE 1 "not driven"), *Limits*; probe `specs/288-ftp-per-server-encoding/probe/ftp288_probe.ps1` (`result_after_review2.txt` PASS 20 / FAIL 0); `quickstart.md`.

## Expected

On a real code-page server new names arrive by the name typed, an unknown server behaves as documented, and nothing is ever written to another file than the one named.

## Steps

- [ ] A real code-page FTP server (names in cp1250 or cp1252, the same as the machine's system code page): open a folder whose listing shows a file with an accented letter, then F7 `nový` (or `café` for cp1252), Quick Rename a file to `čaj.txt`, F5 a local `čaj.txt` into it -> the server's own tools show the three names correctly.
- [ ] The same server: hold `senor.txt`; F5 a local `señor.txt` (cp1250 has no ñ) -> `senor.txt` is unchanged; the uploaded file arrives under a garbled name, not as `senor.txt`.
- [ ] The same server, a fresh connection straight into a folder of ASCII names only: F7 `nový` -> arrives garbled (the documented limit); then open a folder with an accented listed name, come back, F8 the garbled `nový` -> it is deleted (the name sent before goes the same way again).
- [ ] A UTF-8 server (FileZilla Server, vsftpd, ProFTPD) after browsing the code-page server in the same program run: delete, rename and download a file with an accented name -> each works (no "550 No such file").
- [ ] If an AS/400, z/VM or VxWorks FTP server with non-ASCII names is reachable: browse it, then F7 a folder with an accented name -> note the name the server shows; record the result in the fix-log of 288 (expected: the code page when the server's listings show code-page names).

## Log

- 2026-10-21 — created (source leftover:288)
