---
title: Checksum: an OEM-encoded list's accented names stay "missing"
type: improvement
status: rejected
severity: 2
area: other-plugins
source: leftover:117
who: agent
created: 2026-10-17
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: feature 117 (research E2), listed under NEXT-WORK §C Decided - not to do: OEM is never guessed - no signal tells an OEM list from a code-page list, so a guess would mis-read correct lists.
---

# Checksum: an OEM-encoded list's accented names stay "missing"

## Problem

Checksum decides a list's encoding once per file (mark, UTF-16 by NUL bytes, UTF-8 when the whole file is, else the code page). A list written in the OEM code page is read as the ANSI code page, so its accented names are reported "missing".

## Evidence

specs/NEXT-WORK.md item 5, the 117 entry (L1818-1841 at 7993914c): "an OEM list's accented names stay 'missing' (no signal tells OEM from the code page - a decision, 117 research E2)"; `specs/117-checksum-lists/research.md` E2; helper `src/common/salcsumlist.h`. Migrated from specs/NEXT-WORK.md §C *Decided - not to do* (L489, at 7993914c).

## Expected

(not stated in the source)

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §C and 'Recorded, deliberately not on the list' (feature 242)
