---
title: FTP: an upload that ends between another upload's existence check and its lock
type: bug
status: open
severity: 3
area: ftp
source: review:347
who: agent
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# FTP: an upload that ends between another upload's existence check and its lock

## Problem

An FTP upload decides whether its target file already exists (and so whether to ask the overwrite
question) from its listing before it takes the opened-file lock (`FTPOpenedFiles`). If another
upload of the same file is storing it at that moment and finishes between the check and the lock,
the second upload finds "no such file", gets the lock (the first one released it) and stores the
file - replacing the first upload's file without the question. The window exists under one host
name as well; feature 347 did not introduce it.

## Evidence

By reading at 510fd81f (review of feature 347, NOTE 3; not measured):
`src/plugins/ftp/operatsb.cpp` - the existence check against `UploadListingCache` precedes the
`fwssWorkUploadLockFile` state (`FTPOpenedFiles.OpenFile(..., ffatWrite)`); the lock only refuses
while the other store is still open. Probe base that could drive it: feature 347's
`specs/347-ftp-lock-two-names/probe/ftp347_probe.ps1` with `ftpmini_hold.py` (a held STOR), timed
so that upload 1's store ends between upload 2's LIST and its lock.

## Expected

An upload that took "the target does not exist" from a listing made while another operation of the
program held the file open (or that finds the file locked) asks again or lists again after it gets
the lock - it never stores over a file another upload of the program has just stored, without the
overwrite question.

## Notes

Severity 3: not measured; it needs two uploads of one file with an exact timing (the first store
ending inside a short window). Features 341 / 345 already make an upload list again after a change
reported under another connection; whether that covers this window was not checked - measure first.

## Log

- 2026-10-31 — created (source review:347)
- 2026-10-31 — moved to Next position 82
