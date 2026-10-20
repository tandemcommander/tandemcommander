---
title: A ZIP made on Windows that holds names differing only in case is not case-sensitive
type: bug
status: in-progress
severity: 5
area: archives
source: leftover:252
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: 2026-10-20 671ae06b
effort: S
feature: 271
related: []
depends-on: []
reason: -
---

# A ZIP made on Windows that holds names differing only in case is not case-sensitive

## Problem

The ZIP plug-in declares a listing case-sensitive only when an entry was made on Unix (host OS). A ZIP made on Windows from a case-sensitive folder (WSL, `fsutil file setCaseSensitiveInfo`) can hold `a.txt` and `A.txt`, or folders `D` and `d`, without any Unix entry; it is listed case-insensitively, so - as 7-Zip and TAR archives were before feature 252 - Paste, Reselect, Store / Restore Selection and Hide Selected Names can take one twin for the other, and folders `D` and `d` are merged into one.

## Evidence

Left by feature 252 (`specs/252-archive-case-sensitivity/spec.md`, *Assumptions*): 252 made 7-Zip and TAR listings case-sensitive when they hold case twins (`src/common/salcasetwins.h`, `SalDirTreeHasCaseTwins`) and kept ZIP's own rule out of scope. ZIP's rule by reading at the 252 commit: `src/plugins/zip/list.cpp` ~L104 (`centralHeader->Version >> 8 == HS_UNIX` -> `dir->Clear`, `SetFlags(SALDIRFLAG_CASESENSITIVE)`, restart of the listing). Not measured: whether ZIP extraction matches by name or by entry (a merged folder could be extracted only in part, as TAR's was - 252 probe row TAR-TREE before).

## Expected

A ZIP listing that holds case twins in any folder is case-sensitive; a ZIP without twins behaves as before; a probe row like 252's HIDE / GLOBAL / TREE / CONTROL passes for ZIP.

## Approach

The same hook as 252's: build with `SALDIRFLAG_CASESENSITIVE`, clear it after the listing unless `SalDirTreeHasCaseTwins(dir)` or a Unix entry was seen; keep the Unix rule. Fixture: .NET `ZipArchive` can write `a.txt` and `A.txt` entries directly.

## Log

- 2026-10-20 — created (source leftover:252)
- 2026-10-20 — severity as the 7-Zip / TAR item it continues
- 2026-10-20 — related item case-sensitive-twins-first-match done in feature 261
- 2026-10-20 — moved to Next position 5
- 2026-10-20 — verified at 671ae06b: probe zip271 at 671ae06b: 6 FAIL - HIDE/GLOBAL take both twins, one folder copied/deleted with its twin (also Unix ZIP)
- 2026-10-20 — run started, feature 271
