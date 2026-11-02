---
title: Unpack silently drops a cpio file whose only name normalizes to empty
type: bug
status: open
severity: 7
area: archives
source: review:394
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: 2026-11-02 bb8aa693
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Unpack silently drops a cpio file whose only name normalizes to empty

## Problem

A cpio archive (newc / crc, also an rpm payload) whose regular-file member holds data under a name
that normalizes to nothing (`.`, `./`, an empty name) and has no other usable name - a single-name
file (nlink 1), or a hard-linked file whose other names are missing from the archive - is skipped
without a word by a whole Unpack: the operation reports success, so "Delete archive after
unpacking" deletes the archive with the only copy of that data. A refused (too long) name matched
by the mask fails the operation (feature 393); an empty name is never reported.

## Evidence

Review 1 of feature 394 (S1), measured on branch `394-cpio-empty-name-link` (HEAD 0bea9e93) and on
`main` (the same result - pre-existing): extra probe rows written by the reviewer in a copy of
`specs/394-cpio-empty-name-link/probe/cpioempty_probe.ps1` / `mkcpioempty.py`:
`UNP-EMPTY-DOT-SOLO-DEL` (`.` regular, nlink 1, `AAA`, plus `ok.txt`) and
`UNP-EMPTY-DOT-ORPHAN-DEL` (`.` nlink 2 `AAA`, the other name absent) - Alt+F9 with "Delete
archive after unpacking" extracts only `ok.txt`, shows nothing and deletes the archive (logs were
under `%TEMP%\rev394\extra.txt`, `extra_main.txt` - not kept). Code: `src/plugins/tar/untar.cpp`,
`ReadArchiveHeader`, branch "skip invalid names" (`Ignored`, `NameEmpty` since 394) and
`DoUnpackArchive` (`found = FALSE` for `NameEmpty`, feature 394 - needed: the default mask matches
the raw `.` and the plug-in would try to create the target folder itself as a file).

## Expected

Measured first with a probe row (the two layouts above, whole Unpack with "Delete archive after
unpacking"). Then a regular-file member with data whose name normalizes to nothing and whose data
reaches no extracted name is reported (an existing message, e.g. "(206)" / "(123)" with the raw
name) and the operation fails so the archive is kept - never success while data stayed in the
archive. A `.` folder member (GNU cpio's `find . | cpio -o`) and a size-0 member stay silent.

## Notes

Crafted archives only; no common writer stores a file's data under an empty name. Feature 394
spec FR-005 kept this behaviour on purpose (scope). Decide at the start whether a tar member with
an empty name and data gets the same rule (tar has no hard-link grouping; out of this item unless
measured the same).

## Log

- 2026-11-02 — created (source review:394)
- 2026-11-02 — related item a-cpio-hard-link-whose-data-name-normalizes-to-empty-is done in feature 394
- 2026-11-02 — moved to Next position 1
- 2026-11-02 — verified at bb8aa693: reproduced at bb8aa693: probe cpiosolo 9 rows (newc/crc/odc/rpm solo, orphan, tar solo) drop the data silently and delete the archive
