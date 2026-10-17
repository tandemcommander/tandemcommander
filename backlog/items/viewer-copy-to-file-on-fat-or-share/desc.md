---
title: Viewer Copy to File onto a file held open, on a FAT stick or a network share
type: person-step
status: open
severity: 3
area: data-safety
source: leftover:173
who: person
created: 2026-10-14
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Viewer Copy to File onto a file held open, on a FAT stick or a network share

## Problem

Feature 173 made the viewer's Copy to File replace an existing file in one step (`SalReplaceWithTempW`) instead of delete-then-move. The loss it guards against is not producible on Windows 11 NTFS (POSIX delete semantics); the classic semantics - the name stays until the last handle closes - are those of FAT / exFAT and SMB shares, and none was available to the probe (`\\localhost\C$` refused, no FAT volume). The "kept in the temporary file" message was not driven either.

## Evidence

Migrated from specs/NEXT-WORK.md §A item 5c (L176) (at 7993914c). specs/173-viewer-copy-replace/fix-log.md (rows HELD and LOCKED; "Not driven: the 'kept in the temporary file' message").

## Expected

The target keeps its old content or gets the new one - it never disappears; a kept temporary file is named in a message.

## Steps

- [ ] On a FAT or exFAT USB stick: in the viewer, Copy to File onto an existing file that another program holds open - the target keeps its old content or gets the new one, never disappears
- [ ] The same on a network share (SMB)
- [ ] If a message names a kept temporary file: the file exists and holds the new content

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
