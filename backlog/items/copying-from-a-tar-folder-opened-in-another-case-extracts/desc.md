---
title: Copying from a TAR folder opened in another case extracts nothing
type: bug
status: new
severity: 5
area: archives
source: review:252
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: [case-sensitive-twins-first-match]
depends-on: []
reason: -
---

# Copying from a TAR folder opened in another case extracts nothing

## Problem

A user opens a folder inside a TAR archive by a path typed in another case than the archive spells it (for example `t.tar\DOCS` for the folder `Docs`, from the command line, Change Directory or a hot path). The panel lists the folder (archive listings without case twins compare paths case-insensitively), but Copy (F5) of its files extracts nothing: the dialog says "Copy file f.txt", the target stays empty and no error is shown. The same steps with a 7z archive extract the file. The user believes the files were copied.

## Evidence

Found by the independent review of feature 252 (`specs/252-archive-case-sensitivity/fix-log.md`, section *Review*), reproduced on the 252 build and on a Release build from before 252 (a pre-existing defect). Fixture: a TAR holding `Docs/f.txt` and `z.txt`; the left panel opened at `<archive>\DOCS`, Select All, F5 into an empty folder -> nothing arrives. Cause by reading at the 252 commit: `CFilesWindow` stores the archive path as typed (`SetZIPPath`, `src/fileswn2.cpp` ~L2646, the path change into an archive); the TAR plug-in builds the names to extract from that root (`CArchive::UnpackArchive`, `src/plugins/tar/untar.cpp` ~L377-390) and matches them byte for byte (`CNameTree::IsNamePresent`, `src/plugins/tar/names.cpp`) against `Docs\f.txt`. The 7-Zip plug-in extracts by item index and is not affected. Probe base: `specs/252-archive-case-sensitivity/probe/arc252_probe.ps1` row TAR-CONTROL (it checks only that the folder opens).

## Expected

Copying from a TAR folder entered in another case extracts the files (or the panel shows the folder under the archive's own spelling, so the extraction names match); a probe row "open `<archive>\DOCS`, Select All, F5" passes for TAR and 7z.

## Approach

Either the core stores the archive path in the listing's own spelling after a successful case-insensitive path change (all archive plug-ins then get exact roots), or the TAR plug-in maps `archiveRoot` to the listing's spelling. Measure which archive plug-ins match by name (TAR, UnISO, others) first.

## Notes

Severity 5: nothing is lost (the archive is untouched) but a copy silently does nothing; the workaround is to enter the folder by Enter instead of a typed path.

## Log

- 2026-10-20 — created (source review:252)
