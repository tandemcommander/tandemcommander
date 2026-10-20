---
title: SFTP drop folder on a real upload-only service and an ACL on a replaced file (258)
type: person-step
status: open
severity: 4
area: sftp
source: leftover:258
who: person
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: -
feature: -
related: []
depends-on: []
reason: -
---

# SFTP drop folder on a real upload-only service and an ACL on a replaced file (258)

## Problem

Feature 258 made uploads into an upload-only ("drop") SFTP folder work and was proven against a local test server that behaves like one (`dropsftp.py`), not against a real service. How a real one answers (the status of a refused `stat`, whether it honours the exclusive create, whether it lets the uploader remove a partial file) decides whether the upload works there. The statement in the overwrite question about ACLs was checked by reading only (the test container has no ACL tools).

## Evidence

Feature 258: `specs/258-sftp-drop-folder-upload/fix-log.md` (sections *Not driven / owed* and *Review*), `specs/258-sftp-drop-folder-upload/quickstart.md`, probe `probe/sftp258_probe.ps1` rows DROPNEW, DROPEXIST, DROPMOVE, DROPFAIL, DROPNOEXCL. The program's SFTP log window shows the plug-in's lines ("The server does not show ... it is created only if no file of that name is there", "... acknowledged all N bytes and the close").

## Expected

Each step below gives the result written next to it; a different result is a new Inbox item with the log lines.

## Steps

- [ ] On an SFTPGo account (or a hosted drop box) whose folder grants "upload" but not "list": copy a new file into it by typing the target `sftp:<user>@<host>/<folder>` in the Copy dialog -> no error; the file arrives whole (check from an account that may list); the SFTP log says the size was confirmed by acknowledgments (or by size).
- [ ] The same with a file of that name already there and the account WITHOUT "overwrite" -> an error box "... the server does not show whether a file of that name is there; nothing was replaced"; the server file unchanged.
- [ ] The same account WITH "overwrite": copy a SHORTER file over a longer one -> either the box of the previous step (the server keeps the exclusive create) or the server file holds exactly the new content (never the new content followed by the old file's end).
- [ ] Move a file into the folder -> it arrives and the local file is removed only then.
- [ ] On a Linux server with ACL tools: `setfacl -m u:nobody:r f.txt`, upload over `f.txt` (answer Yes) -> the question names ACL and extended attributes; afterwards `getfacl f.txt` shows no `nobody` entry (the statement is true).

## Log

- 2026-10-20 — created (source leftover:258)
- 2026-10-20 — moved to Person steps position 10
