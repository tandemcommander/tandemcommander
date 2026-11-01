# Implementation Plan: A path typed in another case into an archive with case twins elsewhere opens the folder

**Branch**: `382-arc-case-twins-path` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/382-arc-case-twins-path/spec.md`

## Summary

When the panel changes its path inside an archive whose listing is case-sensitive (case twins
somewhere, feature 252), a typed path in another case (`DOCS` for `Docs`) names no folder and
the shortening loop of `CFilesWindow::ChangePathToArchive` falls back to the root silently. Fix:
before that loop, resolve the typed path component by component - exactly first (the listing's
comparison, first match, as `GetFiles`); in a case-sensitive folder otherwise by the only
sub-folder equal ignoring case - and store it with the listing's spelling. The rest of the path
from the first component that does not resolve stays as typed for the existing loop. The pure
rule is a new template in `src/common/salarcpathspell.h` with saltests checks; the core accessor
lives beside 273's in `src/zip.cpp`.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new (header-only rule in `src/common/`)
**Storage**: N/A (nothing stored; history gets the re-spelled path as for 273)
**Testing**: `saltests` (pure rule), GUI probe `probe/arctwins382_probe.ps1` on the hidden desktop,
regression probes of 273 (`arccase273_probe.ps1`) and 252 (`arc252_probe.ps1`)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand`)
**Performance Goals**: one extra walk over the sibling folders of each component, only when the
exact lookup fails in a case-sensitive listing (a path change, not a hot loop)
**Constraints**: never cut a path (result has the typed length; a result that does not fit is
refused and the typed path kept); no change of the listing's comparison rule; plug-in ABI untouched
**Scale/Scope**: 3 source files (`salarcpathspell.h`, `zip.cpp` / `zip.h`, `fileswn2.cpp`), saltests

## Constitution Check

- I. Build reproducibility - no new dependency, no build change. PASS
- II. Backward compatibility - exact paths, case-insensitive listings and every plug-in unchanged;
  only a path that today shortens to a parent now opens the unique folder. PASS
- III. Incremental modernization - small core change with a pure, tested rule. PASS
- IV. Windows commitment - n/a. PASS
- V. Plug-in architecture - no `spl_*.h` change, no plug-in change. PASS
- VI. UI consistency - no UI text, dialog or menu change (no `.slt` refresh). PASS

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/382-arc-case-twins-path/
├── plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/arcpath-resolve.md   # the pure rule's contract (core-internal)
├── fix-log.md
└── probe/arctwins382_probe.ps1, result_before.txt, result_after.txt
```

### Source Code (repository root)

```text
src/common/salarcpathspell.h   # + SalArcPathResolveCase (template, header-only)
src/zip.h, src/zip.cpp         # + CSalamanderDirectory::ResolvePathCase (accessor: exact, fold, ordinal)
src/fileswn2.cpp               # ChangePathToArchive: resolve before the "same path" check and the loop
src/saltests/saltests.cpp      # + TestArcPathResolveCase382
```

**Structure Decision**: extend 273's header and accessor rather than a new header - same
listing abstraction, same callers.

## Complexity Tracking

None.
