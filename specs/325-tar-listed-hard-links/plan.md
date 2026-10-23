# Implementation Plan: Hard-linked names of a tar are listed and copied

**Branch**: `325-tar-listed-hard-links` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/325-tar-listed-hard-links/spec.md`

## Summary

The TAR plug-in (`src/plugins/tar/untar.cpp`) lists every hard-link member (type `1`) as a file whose
size is that of the data member it names (a chain of links followed), so the panel shows it and every
panel operation can ask for it. An extraction asked for a hard link whose target it did not write and
was not asked for records it as *deferred* instead of reporting it; after the single pass, when any
deferred link exists, the archive is opened again (`CDecompressFile::CreateInstance` with the same
file, offset and size - compressed archives too) and a further pass writes the data member (the latest earlier one of the name, review 1) each
deferred link resolves to under the first link's name, copies the other links of that target from it
(feature 309's identity-safe `WriteOutLinkCopy`), and stops reading once nothing is wanted. Links still
unresolved are reported with feature 309's message and fail the operation. Unpacking one listed hard
link (F3, the disk cache) resolves the link in its pass and re-reads the archive for the target, written
under the link's file name. Feature 309's cases (target written / asked but not written / symbolic
links) are unchanged. The pure rules (decision, chain resolution, listed size) live in
`src/common/saltarlink.h` with `saltests` checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; `saltarlink.h` (309), `salpaxheader.h` (306), `salsamefile.h`
(through `WriteOutLinkCopy`)
**Storage**: N/A
**Testing**: `saltests` (`TestTarLink325`: decision table, chain resolution incl. cycles, listed size);
GUI probe `probe/link325_probe.ps1` (9 rows, hidden desktop); regression: probes of 309, 308, 306, 321
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (plug-in DLL `tar.spl`)
**Performance Goals**: a second read of the archive only when a deferred link exists, stopping at the
last wanted data member; listing: two hash maps of names
**Constraints**: no plug-in interface, UI string, registry or file-format change; names UTF-8, never cut
**Scale/Scope**: `untar.cpp`, `tar.h`, `saltarlink.h`, `saltests.cpp`

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency; header-only rule - PASS |
| II. Backward compatibility | no ABI, registry or configuration change; listing adds entries the panel never had, every previously listed entry unchanged - PASS |
| III. Incremental modernization | changes confined to the TAR plug-in's listing and extraction passes - PASS |
| IV. Windows commitment | Win32 only - PASS |
| V. Plug-in architecture | the archiver interface of the plug-in unchanged - PASS |
| VI. UI consistency | no new UI; the existing overwrite question and feature 309's report - PASS |

CLAUDE.md standing rules: *Never lose the user's data* - Copy never deletes the archive; a link that
cannot be reproduced fails the operation (Unpack keeps the archive, 309); same-file decisions by
identity (`WriteOutLinkCopy`, 103); names UTF-8 and whole (066, 097). Post-design re-check: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/325-tar-listed-hard-links/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md
└── probe/link325_probe.ps1, mklink325.py, result_*.txt
```

### Source Code (repository root)

```text
src/common/saltarlink.h       SAL_TAR_LINK_DEFER, SalTarLinkDecideAsked, SalTarResolveHardLink,
                              SalTarListedLinkSize
src/plugins/tar/tar.h         CArchive: ArchiveFileName / InputOffset / InputSize, ReopenStream,
                              SDeferredLink, ExtractDeferredLinks, UnpackOneFilePass
src/plugins/tar/untar.cpp     ListArchive (hard links listed), DoUnpackArchive (defer + second
                              pass), UnpackOneFile (link -> target in a second pass)
src/saltests/saltests.cpp     TestTarLink325()
```

No contracts folder: the change is internal to the TAR plug-in.

## Complexity Tracking

None.
