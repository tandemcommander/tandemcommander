---
title: Compare Directories misses a case-only pair beside a soft-hyphen or NFD name
type: bug
status: open
severity: 3
area: panels-ui
source: review:261
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Compare Directories misses a case-only pair beside a soft-hyphen or NFD name

## Problem

Compare Directories in two ordinary (case-insensitive) folders can mark identical files as
different when a folder holds names that the locale order treats as equal but the file system does
not - a name with a soft hyphen (U+00AD) beside the same name without it, or an NFC and an NFD form
(files copied from a Mac). Feature 232's rule "a pair differing only in case is one name" then
fails, and an identical NFD file can be marked on both sides. Pre-existing (0.1.10 fails the same
way); feature 261 fixed it only for runs that hold case twins.

## Evidence

Measured by review 2 of feature 261 (hidden desktop, size + time; probe copy under the reviewer's
%TEMP%, rows P232_SHY / P232_NFD), on 0e151c5a and on 0.1.10:
- L `ab.txt` "s" + `A<U+00AD>b.txt` "tt", R `AB.txt` "s" + `A<U+00AD>b.txt` "tt": L `ab.txt` and
  R `AB.txt` both marked;
- L NFC `é.txt` "s" + NFD `É.txt` "tt", R NFD `É.txt` "tt" + NFC `É.txt` "s": the identical NFD
  `É.txt` marked on both sides.
Cause: `src/mainwnd5.cpp` `CmpDirsNames` uses `CmpNameExtIgnCase` for runs without twins; its
tie-break `SalNameCompareOrdinalCI` (`src/sort.cpp` `CmpNameExtIgnCase`) orders a run differently
from the lists' sort `CmpNameExt` (locale order with case, then bytes), so the merge steps past
partners. By reading: the sub-folder check (index pairing) reports such folders as different.

## Expected

Every run of one first sort key with more than one name on either side is paired as a set (feature
261's `SalTwinRunPairs` / `CmpDirsAlignRun`), so the pairing does not depend on the order; the rows
above pass, `cmp232_probe.ps1` and `twin261_probe.ps1` stay green.

## Notes

The likely fix is small: in `CmpDirsNames` align every run pair with more than one name on either
side, not only runs with twins (the rearrangement and re-sort already exist).

## Log

- 2026-10-20 — created (source review:261)
- 2026-10-20 — moved to Next position 34
