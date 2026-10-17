---
title: FTP: one process-wide name encoding instead of a per-server flag
type: improvement
status: open
severity: 3
area: ftp
source: leftover:224
who: agent
created: 2026-10-15
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [ftp-long-name-and-path-leftovers]
depends-on: []
reason: -
---

# FTP: one process-wide name encoding instead of a per-server flag

## Problem

Feature 224 made `FTPU8NameToServer` send the code page only for texts a listing / PWD gave in it, using one process-wide set. Until a per-server flag exists, new names (MKD, RNTO, STOR, typed paths, bookmarks) go in UTF-8 also to a legacy code-page server, and a name seen in the code page on one server goes in the code page to another.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L692-699. Feature 224 (`specs/224-ftp-utf8-server-names/`, `ftp224_probe.ps1` with ftpmini in utf-8 / cp1250).

## Expected

Each server (by host, port, user) has an encoding state unknown / UTF-8 / legacy, decided from evidence (FEAT UTF8 or a listing); names go to each server in its own encoding.

## Log

- 2026-10-16 — maintainer: stays in the backlog (severity about 3/10: only legacy code-page servers, new names garbled or typed paths not found, no data lost)
- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
