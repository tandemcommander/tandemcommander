---
title: FTP: an upload as another user or on another port of one server misses the panel changes
type: bug
status: in-progress
severity: 7
area: ftp
source: review:341
who: agent
created: 2026-10-24
updated: 2026-10-30
verified: 2026-10-30 ad3eb597
effort: S
feature: 345
related: [ftp-opened-file-lock-two-names-of-one-server]
depends-on: []
reason: -
---

# FTP: an upload as another user or on another port of one server misses the panel changes

## Problem

While an upload to an FTP server runs, the FTP plug-in decides from cached folder listings whether
an uploaded name already exists. Feature 341 made a change reported under one host name reach the
uploads under every other host name with the same user and port (they list again). A change made
as **another user** of the same server (`ftp://u@...` in the panel, the upload as `ftp://v@...`,
two accounts that see the same folders - e.g. a shared home, or `anonymous` and a named account
of a public folder), or through **another port** of it (21 and a forwarded 2121), still never
reaches the upload: the upload trusts its listing and replaces a file without the overwrite
question.

## Evidence

Measured by review 3 of feature 341 (a copy of `specs/341-ftp-upload-cache-alias/probe/ftp341_probe.ps1`,
row USER-REN, at 53e4ca36): upload 1 as `ftp://v:p@127.0.0.1:2141/USER-REN` held at its question;
Quick Rename `a.txt` -> `b.txt` in the panel connected as `u@127.0.0.1:2141`; upload 2 of the local
`b.txt` as `v`: `USER v / ... / STOR b.txt` without LIST or question, the server's `b.txt` became
`LOCAL-B` (was `SRV-A`). The same row on another port (PORT-REN, a second server on 127.0.0.1:2142
serving the same folder) was not finished (the review was interrupted). Code:
`CUploadListingCache::InvalidateOtherNamesOfServer` and `ChangedUnderOtherName`
(`src/plugins/ftp/operats9.cpp`) compare the user exactly and the port; `FindServer` likewise.

## Expected

A change made as another user or through another port of a server reaches the uploads to it, or -
since the client cannot tell which accounts and ports share folders - the uploads do not trust
their cached listings after such a change (they list the folder again).

## Notes

Feature 341 kept user and port as identity on purpose (spec *Clarifications*: the item named only
host names; conservative). Failing closed here means **every** change on any FTP server makes
every other running upload list its folders again (two uploads to two unrelated servers would
slow each other down) - a cost/benefit choice for the maintainer; a middle way (only the same
host with another user or port) covers the shared-home and forwarded-port cases at a smaller cost.
The probe of feature 341 (`ftpmini_at.py`, rows MULTI-REN / SEED-ALIAS) is the template for the
rows.

## Log

- 2026-10-24 — created (source review:341)
- 2026-10-30 — moved to Next position 1
- 2026-10-30 — verified at ad3eb597: reproduced at ad3eb597: probe rows USER-REN, PORT-REN, ALL-REN, SEED-USER, SEED-PORT FAIL (STOR without question), controls PASS
- 2026-10-30 — run started, feature 345
