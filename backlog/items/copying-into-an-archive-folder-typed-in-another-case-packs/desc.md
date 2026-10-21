---
title: Copying into an archive folder typed in another case packs into a new folder beside it
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

# Copying into an archive folder typed in another case packs into a new folder beside it

## Problem

A user copies (F5) or moves (F6) disk files into an archive and types the target in the Copy dialog as a path inside the archive in another case than the archive spells it (`x.7z\DOCS` while the archive holds the folder `Docs`). The typed spelling reaches the archive plug-in as the folder to pack into, so the files may land in a new folder `DOCS` beside `Docs` instead of in `Docs` (suspected; ZIP's own case rules may differ). Feature 273 fixed the panel route (a folder entered by a typed path is stored as the archive spells it), not this typed-target route.

## Evidence

By reading only, not measured. Found by the independent review of feature 273 (`specs/273-tar-case-root/fix-log.md`, section *Review*, NOTE 3). At ff3cd942: `src/fileswn8.cpp` line 720, the copy / move from disk into an archive named in the target text, calls `PackCompress(HWindow, this, path, hasPath ? secondPart + 1 : "", ...)` - `secondPart` is the typed path inside the archive, passed unchanged as the archive root; the panel's `ZIPPath` (re-spelled since 273 in `ChangePathToArchive`, `src/fileswn2.cpp`) is not involved. The 7-Zip plug-in builds the new items from `archiveRoot` (`src/plugins/7zip/7zip.cpp`, `CFileItem(sourcePath, archiveRoot, name, ...)` in `PackToArchive`).

## Expected

Copying into `<archive>\DOCS` typed in another case puts the files into the existing folder `Docs` (the typed root re-spelled by the archive's listing, as 273 does for the panel - or the same result by another route); a probe row "F5 from disk, target `<x.7z>\DOCS`, archive holds `Docs`" shows the files under `Docs/` for 7z and ZIP.

## Approach

Measure first (7z and ZIP; TAR does not pack). If it reproduces, list the archive (or reuse a panel's listing when the other panel shows the same archive) and re-spell `secondPart` with `SalArcPathRespell` (`src/common/salarcpathspell.h`, feature 273); a part that names no folder yet (a new folder) keeps the typed spelling for the missing tail only.

## Notes

Severity 4 (suspected): nothing is lost, the files land in an unexpected second folder. Listing the archive before packing costs a read of the archive - check how other typed-target routes already do it.

## Log

- 2026-10-21 — created (source review:273)
- 2026-10-21 — moved to Next position 13
