---
title: SFTP: a folder uploaded again into an upload-only folder fails with Cannot create directory
type: bug
status: in-progress
severity: 4
area: sftp
source: leftover:258
who: agent
created: 2026-10-20
updated: 2026-10-21
verified: 2026-10-21 3541e7ad
effort: M
feature: 279
related: []
depends-on: []
reason: -
---

# SFTP: a folder uploaded again into an upload-only folder fails with Cannot create directory

## Problem

Feature 258 made file uploads into an upload-only ("drop") SFTP folder work (the server refuses `stat` / `lstat` there; files are only created, exclusively). A local folder uploaded there a second time still fails: `Mkdir` of the folder that is already there is refused (FAILURE) and the server will not show that it exists, so the whole folder fails with "Cannot create directory ...: SFTP error 4: Failure" and none of its files are sent. The reason says little about why.

## Evidence

Feature 258: `specs/258-sftp-drop-folder-upload/fix-log.md`, section *Review* (review 1 NOTE-4, review 2 MUST-1); probe `specs/258-sftp-drop-folder-upload/probe/sftp258_probe.ps1` rows DROPDIR2 and DROPHOLE (they guard the current behaviour); test server `probe/dropsftp.py`. Site: `UploadDirLevel` in `src/plugins/sftp/operats.cpp` (the block after a failed `session->Mkdir(remoteDir, 0755)`). A first attempt (commit a5100148 on branch 258-sftp-drop-folder-upload) took such a folder as there when `Mkdir` answered FAILURE / FILE_ALREADY_EXISTS and `stat` was refused for want of a right; review 2 rejected it: a Move of an EMPTY local folder then deleted it although nothing reached the server (also on plain OpenSSH, through a symbolic link into an unreadable folder), and a folder with a file of its name in the way gave one box per file.

## Expected

A folder uploaded again into a drop folder sends its files (each by exclusive create), or says clearly that the server does not show whether the folder exists. A Move removes a local folder only when something of it was shown to arrive (an exclusive create or a `Mkdir` that succeeded at that level); a folder with nothing confirmed fails with one box and is kept.

## Approach

Take the folder as there only for the files' sake, never for the Move's removal of the local folder: the level counts confirmed creations; zero confirmed (an empty folder, or every file failed) = the level fails with one box naming the folder. Stop the level at the first file whose create fails with "no such file / path" (the folder is not there) instead of one box per file. Probe rows: DROPDIR2 turns into "arrives", DROPHOLE and the reviewer's OpenSSH symbolic-link case (`/home/tctest/x` -> link into a root 0700 folder) must keep the local folder.

## Notes

Severity 4: a function that does not work, with a workaround (upload the files into the folder one level down, or upload the folder under a new name).

## Log

- 2026-10-20 — created (source leftover:258)
- 2026-10-20 — moved to Next position 19
- 2026-10-21 — verified at 3541e7ad: reproduced at 3541e7ad: probe 258 row DROPDIR2 - Move of pack2 into /drop where pack2 exists: mkdir FAILURE, stat DENIED, box Cannot create directory, c.txt not sent
- 2026-10-21 — run started, feature 279
