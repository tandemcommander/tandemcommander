---
title: Tar unpack skips FIFO and device members without a word
type: bug
status: new
severity: 3
area: archives
source: review:325
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: [tar-copy-of-listed-files-leaves-hard-links-out]
depends-on: []
reason: -
---

# Tar unpack skips FIFO and device members without a word

## Problem

A tar member that is a FIFO, a character or a block device (types `6`, `3`, `4`) is never extracted and never mentioned: an Unpack (Alt+F9) or a Copy asked for it ends as successful, so "Delete archive after unpacking" deletes the archive although the member's name was left out. Windows cannot create such a node, so the member can only be reported (as feature 309 reports symbolic links), not reproduced.

## Evidence

- `src/plugins/tar/untar.cpp` at 786c1d34, `CArchive::ReadTarHeader`, `case CHRTYPE: case BLKTYPE: case FIFOTYPE: case CHRSPEC:` - `header.Ignored = TRUE` ("types we cannot handle"); `DoUnpackArchive` extracts an Ignored member as nothing (`WriteOutData(..., simulate = header.Ignored || !found, ...)`) and counts it as success.
- Review 2 of feature 325 (branch `325-tar-listed-hard-links`, the reviewer's probe `%TEMP%\rev325d\rev325d_probe.ps1`, row N-DEV-MASK-DEL; recorded in `specs/325-tar-listed-hard-links/fix-log.md`, section "Review 2, second launch"): a tar with `a.txt`, `sub/c.txt`, a hard link `sub/b.txt -> a.txt` and a later FIFO `sub/b.txt`; Unpack with mask `*b.txt` and Delete archive -> nothing written, no message, archive deleted. (The FIFO correctly replaces the link - tar's result is the FIFO - the silent skip is older than 325.)
- Not verified: whether `ListArchive` shows such members (they are Ignored, so not listed - a Copy of a listed folder never asks for them; the defect is reachable through Unpack with a mask or a whole Unpack).

## Expected

An extraction asked for a FIFO or device member reports it once per operation with the system's "not supported" text and the member's name (as feature 309's `ReportLinkMember` does for symbolic links) and fails the operation after the rest is extracted, so the archive is kept.

## Notes

Pre-existing in every version; found while reviewing feature 325. A whole Unpack of a Linux root-file-system tarball (`/dev` nodes) would then end as failed - the same trade-off feature 309 made for symbolic links.

## Log

- 2026-10-23 — created (source review:325)
