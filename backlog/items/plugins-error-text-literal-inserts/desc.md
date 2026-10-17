---
title: Plug-ins show a literal "%1" in Windows error texts that have inserts
type: bug
status: open
severity: 2
area: other-plugins
source: leftover:180
who: agent
created: 2026-10-15
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Plug-ins show a literal "%1" in Windows error texts that have inserts

## Problem

Feature 180 made the core's `GetErrorText` show inserts as "..." (`salfmtinserts.h`). Plug-ins with `FORMAT_MESSAGE_IGNORE_INSERTS` show a literal "%1 ..." (7zip, checksum, uncab, uniso, zip, regedt, renamer, filecomp, undelete, winliblt) - cosmetic; `sfx7zip/extract.c` lacks the flag.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L810-814. Feature 180 (`specs/180-errortext-inserts/`, `salfmtinserts.h` - header-only, usable by plug-ins).

## Expected

The listed plug-ins render Windows error texts with inserts like the core ("..."); `sfx7zip/extract.c` passes `FORMAT_MESSAGE_IGNORE_INSERTS`.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
