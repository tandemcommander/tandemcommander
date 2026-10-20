---
title: Adding a file into a ZIP that holds names differing only in case can replace the other twin
type: bug
status: new
severity: 7
area: archives
source: measure:271
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: [a-zip-made-on-windows-that-holds-names-differing-only-in]
depends-on: []
reason: -
---

# Adding a file into a ZIP that holds names differing only in case can replace the other twin

## Problem

Copying or moving a file INTO a ZIP made on Windows that holds `a.txt` and `A.txt` (since feature 271 the panel shows both) decides which existing entry the new file replaces case-insensitively: the first entry of the central directory equal ignoring case is taken - possibly `A.txt` when the user adds `a.txt`. The overwrite question then replaces the other twin (lost) and the old `a.txt` stays beside the new one. The same applies to folders `D` / `d` (the "move into an existing folder" path).

## Evidence

By reading at 671ae06b (feature 271, task T012, not measured): `src/plugins/zip/add.cpp` `CZipPack::MatchFiles` - `pathFlag = NORM_IGNORECASE` unless an entry has the HS_UNIX host byte; `SalZipMemberIs` / `SalZipMemberIsOrIsIn` are called with `pathFlag == NORM_IGNORECASE`; once a name is matched its `Action` becomes `AF_OVERWRITE` / `AF_DEL` and later headers are skipped (`continue`), so only the first case-insensitive match is handled. `PackToArchive` receives no plug-in data of the listing (feature 271 hands the listing's case sensitivity only to Unpack / UnpackOneFile / Delete - `specs/271-zip-case-twins/contracts/zip-case-sensitivity.md` point 4).

## Expected

Adding into a ZIP that holds case twins matches existing entries by exact name (as a Unix-made ZIP already does), so `a.txt` replaces `a.txt` and `A.txt` is untouched; a ZIP without twins behaves as before (case-insensitive overwrite questions).

## Approach

`CZipPack::MatchFiles` already walks the whole central directory before matching (the HS_UNIX pre-pass): collect the names there and apply 252's rule (`salcasetwins.h` `SalNamesHaveCaseTwins` per folder) to set `pathFlag = 0`. Probe: 271's `zip271_probe.ps1` fixture + Copy of a case-sensitive source folder holding `a.txt` (new content) into the archive, answer Yes to overwrite, check that `A.txt` keeps `UPPER`.

## Notes

Not measured - by reading only. Severity 7: narrow (twin ZIPs), but the overwrite removes a file the user did not name.

## Log

- 2026-10-20 — created (source measure:271)
