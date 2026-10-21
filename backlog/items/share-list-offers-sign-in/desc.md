---
title: A server's share list that needs a password shows only the Windows error
type: improvement
status: open
severity: 3
area: panels-ui
source: leftover:125
who: agent
created: 2026-10-13
updated: 2026-10-21
verified: -
effort: M
feature: -
related: [decide-ship-network-plugin-nethood]
depends-on: []
reason: -
---

# A server's share list that needs a password shows only the Windows error

## Problem

For a server that wants a name and password before it lists its shares, feature 125 shows the Windows error. It could offer the sign-in that the full `\\server\share` path already has.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L540-541. Feature 125 (`specs/125-unc-server-shares/`).

## Expected

Opening `\\server\` on a server that refuses an anonymous share list offers the same sign-in as a `\\server\share` path; after signing in the share list appears.

## Notes

Needs a real file server that refuses the list to verify (see the person step `real-file-server-person-rows`). The core's logon path (`drivelst.cpp`, `WNetAddConnection2` / `CredUIPromptForCredentialsA`) is ANSI per the nethood audit - check before reusing it.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-21 — related item share-root-parent-offers-share-list done in feature 284
