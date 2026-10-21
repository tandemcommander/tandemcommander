---
title: FTP: PWD reply cut at 300 bytes and other long-name leftovers of 215
type: bug
status: blocked
severity: 5
area: ftp
source: review:215
who: agent
created: 2026-10-15
updated: 2026-10-21
verified: 2026-10-20 4c6fd132
effort: M
feature: -
related: []
depends-on: []
reason: split: larger than one feature (an interface decision, long local paths, a part depending on ftp-per-server-encoding-flag); agent 2026-10-20
---

# FTP: PWD reply cut at 300 bytes and other long-name leftovers of 215

## Problem

Left by the audit of feature 215 and by 233: a PWD reply over 300 bytes is cut (the panel shows an ancestor under its own name); VMS / AS/400 / OS/2 listing helpers that cut; the lock's `StrICmp`; `fs1.cpp:741` `FTPAddHexEscapeSequences` result ignored; the local side's 259-byte paths; the FTP download target name in `fs4.cpp` cut at a byte (cosmetic); the FTP upload's link size from a cut path (`fs5.cpp:1149`); the whole-letter rule of `?` also counts two code-page bytes of a non-UTF-8 FTP server as one letter when they look like UTF-8.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L684-706 and L754-755. Features 215 (`specs/215-ftp-long-name-command/`, `probe/ftpmini.py`), 233 (`specs/233-ftp-long-server-paths/`, `ftp233_probe.ps1`: the core refuses typed / entered paths of ~260+ bytes, the queue refuses sub-paths over 300 bytes).

## Expected

A PWD reply of any length is kept whole or refused (never an ancestor shown under the deep folder's name); the listed helpers and paths never act on a cut name; `?` counts letters by the server's encoding.

## Notes

Deep FTP paths are limited to ~260 bytes by the core (a limit, recorded in 233). Severity 5 because the cut PWD shows an ancestor under the deep folder's name, which later operations may act on; unsure - not measured beyond 233.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-20 — verified at 4c6fd132: by reading at 4c6fd132: PWD cut only in the AIX form and the UTF-8 decode (RFC form refused); helpers, lock compare, link size still cut; split into four parts
- 2026-10-20 — blocked: split: larger than one feature (an interface decision, long local paths, a part depending on ftp-per-server-encoding-flag); agent 2026-10-20
- 2026-10-20 — split into: ftp-pwd-and-created-path-cut, ftp-escaped-path-does-not-fit-decision, ftp-local-long-paths, ftp-mask-letters-by-server-encoding
- 2026-10-21 — related item ftp-per-server-encoding-flag done in feature 288
