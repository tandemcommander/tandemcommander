---
title: FTP 303 on real servers: an upload of B.txt beside b.txt asks first
type: person-step
status: new
severity: 4
area: ftp
source: leftover:303
who: person
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: S
feature: -
related: [ftp-288-real-server-checks]
depends-on: []
reason: -
---

# FTP 303 on real servers: an upload of B.txt beside b.txt asks first

## Problem

Feature 303 (an FTP upload whose target name differs from a listed file or link only in case - `B.txt` beside `b.txt`, `čaj.txt` beside `Čaj.txt` - counts as existing and gets the "Target File Already Exists" question; a folder twin does not count) was measured only with the local test server `ftpmini.py` on NTFS (a case-insensitive server with Unix-style listings) and on an NTFS folder made case-sensitive. A real Windows-backed server with Unix listings (FileZilla Server, IIS FTP in Unix listing style) and a real Unix server were not available; the configured automatic answers ("file exists" = skip / auto-rename / resume) were checked by reading only (Resume is not a button of the question).

## Evidence

`specs/303-ftp-upload-case-only/fix-log.md` *Measurements after*, *Review* (NOTEs 2-4); probe `specs/303-ftp-upload-case-only/probe/ftp303_probe.ps1` (`result_review1.txt` PASS 12 / FAIL 0); `quickstart.md`.

## Expected

On a real case-insensitive server with Unix listings no file is replaced without the question or the configured answer; on a real case-sensitive server a file beside a case twin is still uploadable.

## Steps

- [ ] FileZilla Server (or IIS FTP with Unix-style listings) on Windows: a folder holding `b.txt` (content OLD); F5 a local `B.txt` into it -> the "Target File Already Exists" question appears; Skip -> the server's `b.txt` still holds OLD.
- [ ] The same server: a folder holding `Čaj.txt`; F5 a local `čaj.txt` -> the question appears.
- [ ] The same server, FTP configuration "When target file already exists" set to Auto-rename: F5 `B.txt` beside `b.txt` -> the file arrives under a new name (for example `B (2).txt`), `b.txt` keeps OLD; restore the setting.
- [ ] The same server, that setting set to Resume, a local `B.txt` longer than the server's `b.txt`: F5 -> resume continues the server's `b.txt` (the server answers SIZE) or reports that the size cannot be determined - never a corrupt or replaced other file; restore the setting.
- [ ] A Unix server (vsftpd / ProFTPD on Linux): a folder holding `b.txt` and a folder `build`; F5 a local `B.txt` -> the question appears, Overwrite creates `B.txt` beside `b.txt` (both listed); F5 a local file `BUILD` -> uploaded without a question beside the folder `build`.

## Log

- 2026-10-22 — created (source leftover:303)
