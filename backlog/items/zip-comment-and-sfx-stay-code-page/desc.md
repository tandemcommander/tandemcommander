---
title: ZIP: the archive comment and the self-extractor stay code page
type: tech-debt
status: rejected
severity: 1
area: archives
source: leftover:094
who: agent
created: 2026-10-02
updated: 2026-10-17
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: features 094 (2026-10-02) and 104/121, listed under NEXT-WORK §C Decided - not to do: the ZIP comment is code page by format; the self-extractor routes and the SFX password prompt stay code page because no SFX package is shipped (the routes are unreachable).
---

# ZIP: the archive comment and the self-extractor stay code page

## Problem

The ZIP plug-in's comment field is code page (by format). The ZIP self-extractor routes stay code page, and the self-extractor's own password prompt (a separate program) turns a password outside the code page into `?`; items added to an existing self-extracting archive are keyed the new way.

## Evidence

specs/NEXT-WORK.md item 5, queue 104 entry 5 (L1860-1881 at 7993914c: "the ZIP comment and the self-extractor routes stay code page (decided)") and the 094 note (L1965-1971: "decided, no SFX package is shipped"); `specs/094-plugin-password-encoding/fix-log.md`; `specs/104-plugin-unicode-names/research.md`. Migrated from specs/NEXT-WORK.md §C *Decided - not to do* (L489-491, at 7993914c).

## Expected

(not stated in the source)

## Notes

Re-open if an SFX package is ever shipped.

## Log

- 2026-10-02 — feature 094: the self-extractor's password prompt stays code page - decided, no SFX package is shipped
- 2026-10-17 — migrated from specs/NEXT-WORK.md §C and 'Recorded, deliberately not on the list' (feature 242)
