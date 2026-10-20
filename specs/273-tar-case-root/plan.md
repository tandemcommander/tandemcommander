# Implementation Plan: A folder inside an archive opened in another case is entered under the archive's own spelling

**Branch**: `273-tar-case-root` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/273-tar-case-root/spec.md`

## Summary

When `CFilesWindow::ChangePathToArchive` has found the folder inside the archive (the existing
loop that shortens the typed path until the listing knows it), the stored path inside the archive
(`ZIPPath`) is re-spelled from the listing: each component is replaced by the bytes of the folder
the listing's own lookup (`CSalamanderDirectory::SalDirStrCmpEx`, first match - exactly what
`GetFiles` does) finds for it. The walk is a header-only rule in `src/common/salarcpathspell.h`
with `saltests` checks; the core calls it through a small accessor on `CSalamanderDirectory`.
Every consumer of the path inside the archive - the archive plug-ins' `archiveRoot` (TAR extracts
by exact names), the directory line, Change Directory and the history - then sees the archive's
spelling. Nothing changes for a path that already matches, a case-sensitive listing or the root.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: core only (`src/fileswn2.cpp`, `src/zip.cpp`, `src/zip.h`); new
header-only rule `src/common/salarcpathspell.h`
**Storage**: N/A (nothing stored changes - spec *Clarifications*)
**Testing**: `saltests` (the rule over a fake tree: case-insensitive and case-sensitive lookups,
first match, missing component, empty component, too small output); hidden-desktop probe
`probe/arccase273_probe.ps1` (TAR and 7z, COPY / DEEP / TWINS rows); 252's probe as regression
**Target Platform**: Windows 11 x64
**Project Type**: desktop application
**Performance Goals**: one walk over the path's components per path change into an archive (the
same linear search `GetFiles` already does)
**Constraints**: no plug-in ABI change; never cut a path (a result that does not fit keeps the typed
path); UTF-8 names compared by the listing's own rule
**Scale/Scope**: one call site, one accessor, one header, one test function

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency; header-only rule; `build.cmd` unchanged |
| II Backward compatibility | a path already spelled as listed, case-sensitive listings and the root are unchanged; no ABI change; plug-ins untouched |
| III Incremental modernization | the decision is a pure rule in `src/common/` with `saltests` checks |
| IV Windows commitment | no new API |
| V Plug-in architecture preservation | plug-ins receive the same parameter, now spelled as their own listing |
| VI UI consistency | no UI change, no strings; the panel shows the folder's real name (as after Enter) |

Gate: PASS (also after Phase 1 - design adds nothing outside this table).

## Project Structure

### Documentation (this feature)

```text
specs/273-tar-case-root/
├── plan.md          # this file
├── research.md      # Phase 0
├── data-model.md    # Phase 1
├── quickstart.md    # Phase 1
├── fix-log.md       # running log
├── probe/           # arccase273_probe.ps1 + results
└── tasks.md         # Phase 2 (/speckit-tasks)
```

No `contracts/`: no interface is added or changed (internal core behaviour; the plug-in API is
untouched).

### Source Code (repository root)

```text
src/common/salarcpathspell.h          # new: SalArcPathRespell (header-only rule)
src/zip.h, src/zip.cpp                # CSalamanderDirectory::GetPathSpelling (accessor over the rule)
src/fileswn2.cpp                      # ChangePathToArchive: re-spell ZIPPath after the shortening loop
src/saltests/saltests.cpp             # TestArcPathRespell273
src/vcxproj/saltests/saltests.vcxproj # the new header listed (as salcasetwins.h; the core project lists no src/common rule headers)
```

**Structure Decision**: core-only fix at the single setter of the path inside an archive.

## Complexity Tracking

None.
