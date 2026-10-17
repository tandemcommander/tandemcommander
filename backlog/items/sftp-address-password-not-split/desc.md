---
title: SFTP: a password typed in sftp:user:password@host is not split off
type: bug
status: rejected
severity: 1
area: sftp
source: leftover:085
who: agent
created: 2026-10-17
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: feature 085 (research R1), listed under NEXT-WORK §C Decided - not to do: recorded, not changed - unreachable in practice, because the server rejects such a user name, the session never lists and the path is never recorded; the typed text itself is covered by the history sinks 085 fixed.
---

# SFTP: a password typed in sftp:user:password@host is not split off

## Problem

`ParseUserPart` takes everything before `@` as the user name, so `sftp:u:secret@h` would set the user name to `u:secret` and echo it into the panel path.

## Evidence

`specs/085-privacy-defect-fixes/research.md` R1 ("SFTP does not split a password out of an address", `sftp/fs.cpp:298-314`); specs/NEXT-WORK.md item 7 (L2090-2093 at 7993914c). Migrated from specs/NEXT-WORK.md §C *Decided - not to do* (L497, at 7993914c).

## Expected

(not stated in the source)

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §C and 'Recorded, deliberately not on the list' (feature 242)
