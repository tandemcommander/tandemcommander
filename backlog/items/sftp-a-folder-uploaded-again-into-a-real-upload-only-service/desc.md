---
title: SFTP: a folder uploaded again into a real upload-only service (279)
type: person-step
status: open
severity: 4
area: sftp
source: leftover:279
who: person
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: -
feature: -
related: [sftp-drop-folder-on-a-real-upload-only-service-and-an-acl-on]
depends-on: []
reason: -
---

# SFTP: a folder uploaded again into a real upload-only service (279)

## Problem

Feature 279 lets a local folder uploaded again into an upload-only ("drop") SFTP folder send its files, and keeps a local folder in a Move when the server confirmed nothing of it. It was proven against a local test server that models such a folder (`dropsftp.py`) and against OpenSSH, not against a real upload-only service. How a real one answers the creation of a folder that is already there (FAILURE or FILE_ALREADY_EXISTS, or a refusal for want of a right) and the `stat` of it decides whether the folder's files are sent there.

## Evidence

Feature 279: `specs/279-sftp-drop-folder-again/fix-log.md` (sections *Probe* and *Not driven / owed*), `specs/279-sftp-drop-folder-again/quickstart.md`, probe `probe/sftp279_probe.ps1` rows DROPDIR2, DROPAGAIN, DROPEMPTY, DROPHOLE2. The program's SFTP log window shows the plug-in's line "The folder ... could not be created (...) and the server does not show whether it exists (...); its items are tried." The related item `sftp-drop-folder-on-a-real-upload-only-service-and-an-acl-on` (258) checks single files on such a service; this one checks folders.

## Expected

Each step below gives the result written next to it; a different result is a new Inbox item with the SFTP log lines.

## Steps

- [ ] On an SFTPGo account (or a hosted drop box) whose folder grants "upload" and "create directories" but not "list": copy a local folder `pack` with two files into it (type the target `sftp:<user>@<host>/<folder>` in the Copy dialog) -> no error; both files arrive (check from an account that may list).
- [ ] Copy the same folder again after adding a third file to it locally -> the new file arrives; for each of the two files already there a box "... the server does not show whether a file of that name is there; nothing was replaced" (or, on an account with "overwrite", see 258's item); no "Cannot create directory" box; the SFTP log has the line "The folder ... could not be created ... its items are tried." (If the creation of the existing folder is refused for want of a right instead, the box "Cannot create directory" with that reason is the expected result - write down the status.)
- [ ] Move an EMPTY local folder of the same name as a folder already there -> one box "Cannot create directory ...: ... nothing of it was confirmed to arrive"; the local folder stays.
- [ ] Move a local folder with one new file into the same place -> the file arrives; the local file and the local folder are removed.

## Log

- 2026-10-21 — created (source leftover:279)
- 2026-10-21 — moved to Person steps position 14
