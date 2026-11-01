---
title: A typed archive target in another case of a non-ASCII letter still makes a twin
type: bug
status: open
severity: 3
area: archives
source: review:383
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: M
feature: -
related: [archive-path-typed-opens-another-letter-equal-by-byte-fold]
depends-on: []
reason: -
---

# A typed archive target in another case of a non-ASCII letter still makes a twin

## Problem

Copy (F5) / Move (F6) from disk with a typed target `x.7z\Č\` while the archive holds the folder `č` packs the files into a new folder `Č` beside `č`. Feature 383 re-spells only what the archive's listing takes as the same folder, and the listing's byte fold (`StrICmpEx`, `CharLowerA` of the code page on UTF-8 bytes) does not take `Č` (C4 8C) and `č` (C4 8D) as equal - the trail bytes differ and are not a case pair of the code page. So 383 fixes ASCII case differences only; a real case difference of a non-ASCII letter still makes a twin folder. The panel route has the same gap (typed `x.7z\Č` does not open `č`).

## Evidence

Found by the independent review of feature 383 (`specs/383-arc-typed-target-case/fix-log.md`, section *Review*, NOTE N1): the reviewer's row FOLDCZ (archive folder `č` with `f.txt`, typed `\Č\`) gave `Č\n.txt` beside `č` both before and after 383 (7z and ZIP). Rule at 9e062379: `src/common/salarcpathspell.h` `SalArcPathResolveCase` step 1 (`acc.Equal` = `SalDirStrCmpEx`) and step 2 (`FoldEqual` = `StrICmpEx`); 383's `SalArcPathApplyResolved` only filters what the resolution found.

## Expected

The typed target `x.7z\Č\` with the archive holding `č` (and no other folder equal by the file system's rule) packs into `č`; twins by the file system's rule are never guessed (as 382 / 383 for ASCII). A probe row FOLDCZ in `specs/383-arc-typed-target-case/probe/arctarget383_probe.ps1` style shows it for 7z and ZIP.

## Approach

Measure first. A resolution step that counts the folders equal by `SalNameEqualOrdinalCI` (the file system's rule) and takes the ONE such folder, for the typed target (and, if the maintainer wants it, the panel route - related item).

## Notes

Severity 3: nothing is lost; the archive gets two folders differing in case, as before 383. Whether the panel should open `č` for typed `Č` changes what a listing shows - close to the rejected B-2 work (`b2-systemic-name-comparison-not-implemented`); the target route alone does not change any listing.

## Log

- 2026-11-01 — created (source review:383)
- 2026-11-01 — moved to Next position 90
