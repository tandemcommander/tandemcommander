---
title: Same-file checks on file systems without file ids stay approximate
type: tech-debt
status: rejected
severity: 3
area: data-safety
source: leftover:103
who: agent
created: 2026-10-03
updated: 2026-10-17
verified: -
effort: L
feature: -
related: [folder-copy-into-itself-makes-snapshot]
depends-on: []
reason: features 103 (2026-10-03) and 107 (2026-10-04), listed under NEXT-WORK §C Decided - not to do: where the file system gives no ids, identity is judged by size and times; each limit is recorded with its reason (e.g. a local folder vs. its WebDAV path kept as two file systems to avoid refusing uploads to WebDAV).
---

# Same-file checks on file systems without file ids stay approximate

## Problem

Recorded identity limits: a copy on a file system without file ids refuses a different file of equal size and times (WebDAV twins); two different WebDAV servers holding one path below the server name with equal folder times count as one (a refused merge); a local folder and a WebDAV path of the same folder served from this machine are not recognised as one; a folder reachable through two shares of a NAS that gives each share its own volume serial is not recognised (the old behaviour). Also recorded by 103 (`specs/103-same-file-delete-guard/fix-log.md` L235-237, review rows 6 and 7; NEXT-WORK L1239-1240): a copy onto a symbolic link that points at the source is refused (before 103 the link was replaced by a real copy on NTFS) - accepted as correct, it is the same file; hard links on a file system whose two paths to one link do not share share-mode state - a copy onto another spelling of the same link with link count > 1 keeps the old handling.

## Evidence

specs/NEXT-WORK.md item 5, the 103 entry (L1225-1240 at 7993914c) and the 107 entry (L1296-1309); `specs/103-same-file-delete-guard/fix-log.md`, `specs/107-folder-alias-move/fix-log.md`; rules in `src/common/salsamefile.h`. Migrated from specs/NEXT-WORK.md §C *Decided - not to do* (L494-496, at 7993914c).

## Expected

(not stated in the source)

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §C and 'Recorded, deliberately not on the list' (feature 242)
- 2026-10-17 — migration review N4: the two 103 limits (symlink onto the source, share-mode hard links) added to Problem
