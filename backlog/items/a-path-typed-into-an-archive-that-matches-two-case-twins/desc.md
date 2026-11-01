---
title: A path typed into an archive that matches two case twins opens the root silently
type: bug
status: open
severity: 3
area: archives
source: leftover:382
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# A path typed into an archive that matches two case twins opens the root silently

## Problem

A user opens a folder inside a TAR or 7z archive by a path typed in another case (`t.tar\docs`) - command line, Change Directory, hot path - and the archive holds two folders whose names differ only in case (`Docs` and `DOCS`). The typed name matches both, so neither is opened (feature 382 never guesses between twins) and the panel silently shows the archive's root; a user who goes on with Select All and F5 copies the whole root (`Docs\f.txt`, `DOCS\g.txt`) instead of being told that the path is ambiguous or not found. The same silent shortening happens for any path inside an archive that names nothing (pre-existing, every archive).

## Evidence

Review of feature 382 (`specs/382-arc-case-twins-path/fix-log.md`, section *Review*, SHOULD 2), the reviewer's row AMBIGCOPY (copy of `specs/382-arc-case-twins-path/probe/arctwins382_probe.ps1`), TAR and 7z, the same on the 382 build and on `main` 59053ae5: fixture `Docs\f.txt`, `DOCS\g.txt`; left panel started at `<archive>\docs`, Select All, Copy -> panel at the archive root, target `Docs/f.txt, DOCS/g.txt`. Cause by reading at the 382 branch: `CFilesWindow::ChangePathToArchive` (`src/fileswn2.cpp`, the loop `while (path[0] != 0 && GetArchiveDirFiles() == NULL)`) shortens a path that names nothing down to the root without a message; `SalArcPathResolveCase` (`src/common/salarcpathspell.h`) deliberately leaves an ambiguous component unresolved. The 382 probe's row AMBIG checks only that neither twin is opened, not the copy.

## Expected

A path typed into an archive whose component matches two or more folders ignoring case (and no folder exactly) is not silently replaced by the archive's root: the user is told the path was not found (or is ambiguous) and the panel stays where it was, or opens the deepest unambiguous parent with a message; a probe row "twins `Docs` / `DOCS`, open `<archive>\docs`, Select All, F5" passes for TAR and 7z (nothing or only the announced parent is copied after a message).

## Notes

Severity 3: nothing is lost and the panel visibly shows the root, but a following copy takes more than the user meant. The item that 382 fixed (`a-path-typed-in-another-case-into-an-archive-with-case-twins`) allowed either "opens the unambiguous folder or tells the user"; 382 implemented the first and kept the existing silent shortening for the ambiguous case (spec *Clarifications*, conservative). Whether a missing path inside any archive should get a message (as on disk) is a wider question - the shortening is old Open Salamander behaviour; decide the scope (only ambiguous twins, or every missing archive path) when the item is taken.

## Log

- 2026-11-01 — created (source leftover:382)
- 2026-11-01 — moved to Next position 89
