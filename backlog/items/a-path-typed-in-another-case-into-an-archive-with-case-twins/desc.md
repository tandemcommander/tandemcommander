---
title: A path typed in another case into an archive with case twins elsewhere opens its root
type: bug
status: open
severity: 4
area: archives
source: review:273
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# A path typed in another case into an archive with case twins elsewhere opens its root

## Problem

A user opens a folder inside a TAR or 7z archive by a path typed in another case than the archive spells it (`t.tar\DOCS` for the folder `Docs`), from the command line, Change Directory or a hot path. When any other folder of the archive holds names that differ only in case (for example `X\a.txt` and `X\A.txt`), the whole listing is case-sensitive (feature 252), `DOCS` names no folder, and the panel silently opens the archive's root instead. A user who goes on with Select All and F5 copies the whole root (`Docs\f.txt`, `X\a.txt`, `X\A.txt`) instead of the folder they asked for. Archives without twins open `Docs` since feature 273.

## Evidence

Found by the independent review of feature 273 (`specs/273-tar-case-root/fix-log.md`, section *Review*, NOTE 2), measured on the 273 build with a copy of `specs/273-tar-case-root/probe/arccase273_probe.ps1` (reviewer's row MIXED, TAR and 7z): fixture `Docs\f.txt`, `X\a.txt`, `X\A.txt`; left panel started at `<archive>\DOCS` -> panel at the archive root; Select All, Copy -> target `Docs/f.txt, X/a.txt, X/A.txt`. Cause by reading at ff3cd942: the 7-Zip and TAR plug-ins keep `SALDIRFLAG_CASESENSITIVE` for the whole listing when any folder holds case twins (`src/common/salcasetwins.h`, feature 252); `CSalamanderDirectory::GetFiles` (`src/zip.cpp`) then compares every component exactly, and `CFilesWindow::ChangePathToArchive` (`src/fileswn2.cpp`, the loop that shortens the path until `GetArchiveDirFiles()` finds it) falls back to the root without a message.

## Expected

A path typed in another case into an archive with case twins in another folder opens the folder when its name is unambiguous (only one folder of that name ignoring case in its parent), or the user is told the path was not found; a probe row "twins elsewhere, open `<archive>\DOCS`, Select All, F5" passes for TAR and 7z (only `f.txt` arrives, or nothing is copied after a message).

## Approach

Measure first. Options: a per-folder case rule (only folders that hold twins compare exactly - needs the core's lookup to know which folders hold twins), or a path lookup that, when the exact lookup fails, accepts a component that matches exactly one folder ignoring case (then 273's re-spelling stores the listing's name). Check every consumer of `SalDirStrCmp` in an archive listing before changing the rule.

## Notes

Severity 4: nothing is lost, the panel shows the root (visible), but a following copy takes more than the user meant. Pre-existing since feature 252 (before 252 such archives were listed case-insensitively and the folder opened), not caused by 273.

## Log

- 2026-10-21 — created (source review:273)
- 2026-10-21 — moved to Next position 11
