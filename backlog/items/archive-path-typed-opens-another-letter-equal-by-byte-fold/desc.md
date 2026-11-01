---
title: A path typed into an archive opens another letter equal only by the byte fold
type: bug
status: open
severity: 4
area: archives
source: review:383
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: M
feature: -
related: [b2-systemic-name-comparison-not-implemented]
depends-on: []
reason: -
---

# A path typed into an archive opens another letter equal only by the byte fold

## Problem

A folder inside an archive opened by a typed path (command line, Change Directory, hot path) is looked up by the listing's legacy byte fold (`StrICmpEx`, `CharLowerA` of the code page applied to UTF-8 bytes). Under code page 1250 / 1252 that fold maps byte 0x8C to 0x9C, so `Č` (C4 8C) and `Ĝ` (C4 9C) are "equal" - and likewise `Ď` / `Ğ`, `Ċ` / `Ě`. Typing `x.7z\Č` opens the existing folder `Ĝ` and, since feature 273, stores the path as `Ĝ`; a following Copy (F5) from the panel or into it acts on another folder than the one the user named. A different letter is not "the same name" by the file system's rule (`SalNameEqualOrdinalCI`, feature 092).

## Evidence

Found by the independent review of feature 383 (`specs/383-arc-typed-target-case/fix-log.md`, section *Review*, MUST M1 and its last remark). Feature 383 fixed the same fold for the typed TARGET of Copy / Move from disk (a component re-spelled only when `SalNameEqualOrdinalCI` agrees); the panel route was left as it is. At 9e062379: `src/fileswn2.cpp` `ChangePathToArchive` - the 382 block (`ResolvePathCase`), the shortening loop (`GetArchiveDirFiles` -> `CSalamanderDirectory::GetFiles`, `SalDirStrCmp`) and the 273 block (`GetPathSpelling`); `src/zip.cpp` `CSalDirRespellAccess::Equal` (`SalDirStrCmpEx`) and `CSalDirResolveCaseAccess::FoldEqual` (`StrICmpEx`); the fold itself `src/str.cpp` (`StrICmpEx`, `LowerCase` table from `CharLowerA`). The reviewer's probe rows FOLD / FOLDOW (archive folder `Ĝ`, typed `Č`) are now rows of `specs/383-arc-typed-target-case/probe/arctarget383_probe.ps1` for the target route. The panel route is by reading, not measured.

## Expected

A path typed into an archive (`x.7z\Č` while the archive holds only `Ĝ`) does not open `Ĝ`: the path is treated as not found (shortened as for any missing folder), and the stored panel path is never re-spelled to another letter; `Docs` for `DOCS` keeps working (273 / 382 rows). A probe row in the style of 273's probe shows it for 7z and TAR.

## Approach

Measure first. In the 273 / 382 blocks accept a re-spelled component only when `SalNameEqualOrdinalCI` takes it as the same name as the typed one (the rule 383 uses, `SalArcPathApplyResolved` with a same-name callback in `src/common/salarcpathspell.h`); the listing's own lookup (`GetFiles`, the shortening loop) also follows the fold - decide whether a typed component is checked component by component before the lookup.

## Notes

Differs from the rejected B-2 item (`b2-systemic-name-comparison-not-implemented`): that one would change how listings compare names in general; this is one concrete wrong-folder case of a typed path, which the rejection reason names as the condition to look again. Severity 4: no data is lost by opening, but a following copy or pack acts on the wrong folder.

## Log

- 2026-11-01 — created (source review:383)
- 2026-11-01 — moved to Next position 31
