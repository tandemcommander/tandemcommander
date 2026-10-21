---
title: Adding a file into a ZIP that holds names differing only in case can replace the other twin
type: bug
status: open
severity: 7
area: archives
source: measure:271
who: agent
created: 2026-10-20
updated: 2026-10-21
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Adding a file into a ZIP that holds names differing only in case can replace the other twin

## Problem

Copying a file INTO a ZIP made on Windows that holds names differing only in case matches the existing entries case-insensitively, so an entry the user did not name is replaced:

- the archive holds `D/x.txt` and `d/y.txt`; since feature 271 the panel shows folders `D` and `d` apart, and `t.zip\d` lists only `y.txt`. Copying a disk file `x.txt` into `t.zip\d` (OK, Yes to the overwrite question, which names `t.zip\D\x.txt`) leaves `d/x.txt` (new) and `d/y.txt` - **`D/x.txt` is gone**, although nothing in the folder the user is in shows it (before 271 the merged folder showed `x.txt`, so the result was the same but visible);
- the archive holds `A.txt` (UPPER) and `a.txt` (lower); adding `a.txt` (NEW) asks twice (same size, 5 bytes); Yes to both leaves only `a.txt` = NEW - **`A.txt` is lost** (also before 271).

## Evidence

Measured by the independent review of feature 271 on the build of commit 24925c60 (hidden desktop; rows ADD-DIR and ADD-FILE of the reviewer's probe, not in the repository; `specs/271-zip-case-twins/fix-log.md` *Review*). By reading: `src/plugins/zip/add.cpp` `CZipPack::MatchFiles` (~L1317-1321: `pathFlag = NORM_IGNORECASE` unless an entry has the HS_UNIX host byte; ~L1375: `SalZipMemberIs(..., pathFlag == NORM_IGNORECASE, ...)`; the question at ~L1424-1431). Every case-insensitive match gets its own question and its own replacement. `PackToArchive` receives no plug-in data of the listing (feature 271 hands the listing's case sensitivity only to Unpack / UnpackOneFile / Delete - `specs/271-zip-case-twins/contracts/zip-case-sensitivity.md` point 4).

## Expected

Adding into a ZIP that holds case twins matches existing entries by exact name (as a Unix-made ZIP already does), so `a.txt` replaces `a.txt` and `A.txt` is untouched; a ZIP without twins behaves as before (case-insensitive overwrite questions).

## Approach

`CZipPack::MatchFiles` already walks the whole central directory before matching (the HS_UNIX pre-pass): collect the names there and apply 252's rule (`salcasetwins.h` `SalNamesHaveCaseTwins`; two byte-different, case-insensitively equal path prefixes exist exactly when some folder holds twins) to set `pathFlag = 0`. Probe: 271's `zip271_probe.ps1` fixtures + Copy of a disk file into the archive (rows as ADD-DIR / ADD-FILE above), answer Yes, check that `D/x.txt` / `A.txt` keep their content.

## Notes

Severity 7: narrow (twin ZIPs), but the overwrite removes a file the user did not name; the review of 271 recommends taking it right after 271, because 271 shows `D` and `d` apart and so hides the entry that gets replaced.

## Log

- 2026-10-20 — created (source measure:271)
- 2026-10-21 — related item a-zip-made-on-windows-that-holds-names-differing-only-in done in feature 271
- 2026-10-21 — moved to Next position 1
