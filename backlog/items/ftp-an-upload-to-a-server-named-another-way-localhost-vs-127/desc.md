---
title: FTP: an upload to a server named another way (localhost vs 127.0.0.1) misses the panel changes
type: bug
status: open
severity: 5
area: ftp
source: review:302
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: [ftp-323-by-hand-send-ftp-command-during-an-open-upload-then]
depends-on: []
reason: -
---

# FTP: an upload to a server named another way (localhost vs 127.0.0.1) misses the panel changes

## Problem

The FTP plug-in keeps, while an upload to a server is in progress, a cache of that server's folder
listings and decides from it whether an uploaded name already exists (the overwrite question).
Changes made in an FTP panel (Create Directory, Quick Rename, Delete, Send FTP Command) are reported
to that cache by the panel's user, host and port. The cache compares the host as typed: an upload
started to `ftp://u@localhost/...` and a panel connected to `ftp://u@127.0.0.1/...` (or a server's
name and its IP address, or two names of one server) are two different servers to it, so the
panel's changes never reach the upload's cache - the same situation feature 323 fixed for the
swapped arguments, where a file renamed to `b.txt` in the panel was replaced by an uploaded
`b.txt` without the overwrite question.

## Evidence

By reading at 83e65086 (feature 323 branch; noted by 302 review 2 in
`specs/323-ftp-upload-cache-args/fix-log-302.md`, *Review 2*, NOTEs):
`CUploadListingCache::FindServer` (`src/plugins/ftp/operats9.cpp`) matches
`StrICmp(server->Host, host)`, the user exactly and the port; no name resolution. Not measured:
the probe `specs/323-ftp-upload-cache-args/probe/ftp302_probe.ps1` (row REN-UP) could show it with
upload 1 to `localhost` and the panel at `127.0.0.1`.

## Expected

A change made in an FTP panel reaches the upload listing cache of every running upload to the
same server, also when the two were opened by different names of it - or, when the identity of
the server cannot be told, the upload does not trust its cached listings for an existence check
(it lists the folder again). A probe row: upload 1 to `localhost` kept open, Quick Rename `a.txt`
-> `b.txt` in a panel at `127.0.0.1`, upload 2 of `b.txt` - the overwrite question appears.

## Notes

Severity 5 because not measured; if the probe row shows the replace without the question, raise
it to the data-loss band (7, narrow scenario: two names of one server at the same time). How the
same server is recognised (resolving names, comparing addresses) may touch network behaviour -
check `PRIVACY.md` / the maintainer-owned list before resolving names.

## Log

- 2026-10-23 — created (source review:302)
- 2026-10-23 — moved to Next position 5
