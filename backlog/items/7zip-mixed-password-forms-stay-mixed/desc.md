---
title: 7-Zip: an archive that mixes the two password forms stays mixed
type: improvement
status: rejected
severity: 2
area: archives
source: leftover:093
who: agent
created: 2026-10-17
updated: 2026-10-17
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: feature 093, listed under NEXT-WORK §C Decided - not to do: the plug-in cannot re-encrypt, so an archive holding items under both password forms stays mixed.
---

# 7-Zip: an archive that mixes the two password forms stays mixed

## Problem

After 093 the 7zip plug-in keys passwords the new way; an archive whose older items use the old form and newer items the new form stays mixed, because the plug-in cannot re-encrypt existing items.

## Evidence

specs/NEXT-WORK.md item 5, *7zip plugin* entry (L1982-1985 at 7993914c); `specs/093-unicode-dialogs/fix-log.md`. Migrated from specs/NEXT-WORK.md §C *Decided - not to do* (L491, at 7993914c).

## Expected

(not stated in the source)

## Notes

The same source entry also records non-decisions (a damaged item under a two-form password decoded up to three times; Test's second pass, cancel during a retry pass and RAR not driven) - those are the item `7zip-two-form-password-passes-not-driven`.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §C and 'Recorded, deliberately not on the list' (feature 242)
- 2026-10-17 — migration review N3: cross-reference to the final slug
