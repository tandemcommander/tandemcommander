---
title: SFTP: a folder uploaded again whose files are all there ends with a misleading folder box
type: improvement
status: open
severity: 2
area: sftp
source: review:279
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# SFTP: a folder uploaded again whose files are all there ends with a misleading folder box

## Problem

Feature 279 lets a folder uploaded again into an upload-only ("drop") SFTP folder send its files. When EVERY file of such a folder is already on the server, each file shows its own box ("Cannot upload ... the server does not show whether a file of that name is there; nothing was replaced") and then a second box names the folder: "Cannot create directory ...: the server does not show whether the folder is there; nothing of it was confirmed to arrive". The second box is misleading - the server's "a file of that name exists" answer to the exclusive create shows that the folder is there. Likewise, nested folders that are both already there and empty give one box per level (the subfolder's, then the parent's). Nothing is lost (the local folders and files stay); only the messages are more and less clear than they could be.

## Evidence

Review 1 of feature 279 (`specs/279-sftp-drop-folder-again/fix-log.md`, section *Review*), NOTE-1 and NOTE-2: the reviewer's rows RVALLEXIST (Copy of `pack9` with `a.txt` already in `/drop/pack9`: the file's box, then the folder box) and RVNESTEMPTY (Move of `pack8/sub`, both empty and already there: two boxes), run with a copy of `specs/279-sftp-drop-folder-again/probe/sftp279_probe.ps1` against `probe/dropsftp.py`. Site: `UploadDirLevel` in `src/plugins/sftp/operats.cpp` (the verdict `SftpUnconfirmedDirVerdict` after the loop of an unconfirmed folder) at the commit of feature 279. The folder box after the files' boxes is the rule the spec chose (Clarification Q1: "zero confirmed always fails the folder with one box").

## Expected

A folder uploaded again whose files are all already there shows the files' boxes and no folder box saying that nothing arrived (or one clearly worded summary instead); nested empty folders that are already there give at most one box. A Move still keeps every local folder of which nothing was confirmed.

## Approach

Let an item report "a file of that name is there" (the exclusive create refused with FAILURE / FILE_ALREADY_EXISTS in the drop route) as evidence that its folder exists - for the message only, never for the Move's removal of the local folder (review 2 of 258, MUST-1). Measure first with the reviewer's rows.

## Notes

Severity 2: the wording of a box and one box too many; no data at risk.

## Log

- 2026-10-21 — created (source review:279)
- 2026-10-21 — moved to Next position 95
