---
title: A cpio hard link whose data name normalizes to empty is written as an empty file
type: bug
status: in-progress
severity: 7
area: archives
source: review:393
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: 2026-11-02 32c55a19
effort: S
feature: 394
related: []
depends-on: []
reason: -
---

# A cpio hard link whose data name normalizes to empty is written as an empty file

## Problem

In a newc / crc cpio (or an rpm), when the member that carries the data of a hard-linked file has a
name that normalizes to nothing (`""`, `.`, `./`), its data never reaches the file's other names: an
extraction writes those names as EMPTY files at the end of the operation and reports success, so
"Delete archive after unpacking" deletes the archive with the only copy of the data.

## Evidence

At 3f3481b0 (branch `393-cpio-long-name`), `src/plugins/tar/untar.cpp`, `ReadArchiveHeader`: "skip
invalid names" (line 2206) sets `header.Ignored = TRUE` without `NameRefused` (line 2211 region), so
`IsCpioGroupMember` (line 1720: `!header.Ignored || header.NameRefused`) drops the member from its
group; the waiting size-0 names are then written empty by `WriteOutCpioEmptyNames` (line 1950) with no
report. Found by review 1 of feature 393 (NOTE-4) by reading the code - not verified by a probe.
Feature 393 fixed the same pattern for refused (too long) names (probe row UNP-HARD-REFUSED-DEL).

## Expected

Measured first with a probe row (newc: `a.txt` size 0 and `.` carrying `AAA`, one inode, nlink 2,
whole Unpack with "Delete archive after unpacking"). Then the other names get the data (the empty-name
carrier kept in its group as not asked, as feature 393 does for a refused name), or - if that cannot
be done safely - they are reported and the operation fails so the archive is kept; never an empty file
with success.

## Notes

Pre-existing (features 310 / 309 behaviour), outside feature 393's scope. Crafted archives only; no
common writer stores a file's data under an empty name.

## Log

- 2026-11-02 — created (source review:393)
- 2026-11-02 — severity 7: a silent empty file plus Delete archive after unpacking loses data in a narrow case
- 2026-11-02 — moved to Next position 1
- 2026-11-02 — verified at 32c55a19: reproduced at 32c55a19: probe cpioempty 9 FAIL - a.txt written empty, archive deleted with success (newc, crc, rpm, data-first)
- 2026-11-02 — run started, feature 394
