---
title: FTP: PWD reply cut at 300 bytes and other long-name leftovers of 215
type: bug
status: open
severity: 5
area: ftp
source: review:215
who: agent
created: 2026-10-15
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [ftp-per-server-encoding-flag]
depends-on: []
reason: -
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
