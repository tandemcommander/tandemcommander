---
title: 7-Zip, TAR and SFTP do not declare case-sensitive listings
type: bug
status: open
severity: 5
area: archives
source: review:230
who: agent
created: 2026-10-15
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [case-sensitive-twins-first-match]
depends-on: []
reason: -
---

# 7-Zip, TAR and SFTP do not declare case-sensitive listings

## Problem

Only ZIP and FTP set `SALDIRFLAG_CASESENSITIVE`. Paste from a 7-Zip / TAR archive holding a.txt and A.txt may extract the other one (`salshlib.cpp:791-818`); SFTP should declare its case sensitivity (`SALDIRFLAG_CASESENSITIVE`, `sftp/fs.cpp:778`).

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L746-752. Features 230 (`specs/230-dragdrop-case-sensitive-names/`), 232.

## Expected

7-Zip, TAR and SFTP listings declare case sensitivity; paste of a.txt from an archive holding a.txt and A.txt extracts a.txt.

## Notes

Severity 5: the wrong file's content arrives under the expected name; not measured.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
