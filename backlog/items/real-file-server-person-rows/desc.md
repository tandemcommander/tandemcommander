---
title: Real file server rows: shares, other-script names, refused list, SMB timing
type: person-step
status: open
severity: 3
area: panels-ui
source: leftover:125
who: person
created: 2026-10-13
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [share-list-offers-sign-in]
depends-on: []
reason: -
---

# Real file server rows: shares, other-script names, refused list, SMB timing

## Problem

The share list of feature 125 and the case-sensitive work of 232 need a real file server.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L751 and L846-848. `specs/125-unc-server-shares/fix-log.md`, `quickstart.md`; feature 232.

## Expected

The share list shows the real shares, names in another script read correctly, a refused list gives a clear message; the SMB listing time is recorded.

## Steps

- [ ] A real file server with visible shares - the share list of `\\server\` (125)
- [ ] Shares named in another script (125)
- [ ] A server that refuses the list (125)
- [ ] A timed listing on an SMB share (232)

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
