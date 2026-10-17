---
title: Email files on a tree with an unreadable deep folder, with a mail client
type: person-step
status: open
severity: 2
area: long-paths
source: leftover:183
who: person
created: 2026-10-15
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Email files on a tree with an unreadable deep folder, with a mail client

## Problem

Feature 183 composes the Email files error text on the heap (before: `fileswn8.cpp` ~1287, `char[2 * MAX_PATH + 100]`, overrun by a folder that cannot be listed deep in the tree). Its probe row EMAIL-DEEP was not driven: the agent's machine has no MAPI client and the command stops before it lists anything.

## Evidence

Migrated from specs/NEXT-WORK.md §A item 5j (L211) (at 7993914c). specs/183-message-overruns/fix-log.md (EMAIL-DEEP: NOT DRIVEN); specs/183-message-overruns/probe/result_after.txt (3 PASS, 1 NOT DRIVEN).

## Expected

The error names the unreadable folder in full; no assertion, no crash.

## Steps

- [ ] On a machine with a MAPI mail client: select a folder tree that contains a folder which cannot be listed (access denied) 620+ bytes deep, Files > Email: the error names that folder in full, no assertion or crash (Debug build)

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
