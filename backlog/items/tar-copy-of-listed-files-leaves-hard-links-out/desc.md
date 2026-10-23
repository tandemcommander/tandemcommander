---
title: Copying the files of a tar folder leaves hard-linked names out silently
type: bug
status: open
severity: 5
area: archives
source: review:309
who: agent
created: 2026-10-22
updated: 2026-10-23
verified: 2026-10-23 0991f43c
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Copying the files of a tar folder leaves hard-linked names out silently

## Problem

The TAR plug-in does not list link members (hard links '1', symbolic links '2') in the panel. Since feature 309 a whole Unpack, and a Copy of a selected folder that holds them, extract a hard link as a copy of its target (or report a link it cannot reproduce). But a user who opens an archive folder and copies the files shown there (Select All + Copy inside the folder) never asks for the link members, so they are left out without a word - the second name of a hard-linked file is missing from the target.

## Evidence

- Review 1 of feature 309 (branch `309-tar-link-members`), own row REV-COPY-SUBROOT-INSIDE (copy of `specs/309-tar-link-members/probe/link309_probe.ps1` in the reviewer's `%TEMP%\rev309`, log `rev309_inside.txt`): Select All + Copy inside `top\sub` -> 1 of 3 files, no message.
- `src/plugins/tar/untar.cpp` `CArchive::ReadTarHeader`: LNKTYPE / SYMTYPE set `Ignored`; `CArchive::ListArchive` skips `Ignored` members. `DoUnpackArchive` handles a link member only when `names.IsNamePresent` matches it.

## Expected

A hard-link member is listed as a file (size of its target) and a Copy of it extracts the copy of its target - which needs the target's data in the same pass even when the target is not selected (the stream cannot seek back) - or the Copy of a folder's files reports the link members it leaves out. Symbolic links: listed and reported, or left as now (decide with the item).

## Notes

Not a data-loss path (Copy never deletes the archive). Listing link members changes the panel, the free-space check and the 306 / 308 / 309 probes.

## Log

- 2026-10-22 — created (source review:309)
- 2026-10-22 — moved to Next position 11
- 2026-10-23 — verified at 0991f43c: reproduced at 0991f43c: probe link325 COPY-INSIDE Select All + Copy inside t.tar/sub -> 1 of 3 files, no box; F3 on a link impossible (not listed)
