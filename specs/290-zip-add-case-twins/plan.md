# Implementation Plan: Adding into a ZIP that holds names differing only in case replaces only the named member

**Branch**: `290-zip-add-case-twins` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/290-zip-add-case-twins/spec.md`

## Summary

`CZipPack::MatchFiles` (`src/plugins/zip/add.cpp`) matches each item being added against the
archive's members ignoring case (Windows-made ZIP: everything; Unix-made ZIP: everything below the
panel's folder) and asks / replaces every match. In a ZIP that holds case twins this replaces a
member the user did not name. The pre-pass of `MatchFiles` over the central directory (already in
memory) also collects the members' names (`ProcessName`, the form the listing uses) and asks a new
header-only rule, `SalPathsHaveCaseTwins` (`src/common/salcasetwins.h`, 252's twin test applied to
every path prefix), whether some folder of the archive holds twins. If so, the match loop compares
the panel's folder and the rest exactly (`SalZipMemberIs` / `SalZipMemberIsOrIsIn` gain a
`nameIgnoreCase` parameter, default TRUE = unchanged for every other caller). Without twins nothing
changes.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; header-only rules `salcasetwins.h` (+ `salnameorder.h`),
`salzipname.h`
**Storage**: N/A (the archive itself; no registry change)
**Testing**: `saltests` (new `TestPathTwins290`, extended `SalZipMemberIs` checks), hidden-desktop
probe `probe/zip290_probe.ps1`, regression probes of 110 (`zipname_probe.ps1`) and 271
(`zip271_probe.ps1`)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, ZIP plug-in (`zip.spl`)
**Performance Goals**: no extra read of the archive; one more `ProcessName` per central header and
one sort of all path prefixes (O(n log n) in the number of path parts) per add
**Constraints**: plug-in ABI unchanged; UTF-8 names (`ProcessName` output); low memory refuses the
add (IDS_LOWMEM, an existing string)
**Scale/Scope**: archives of any size; the twin rule is per archive

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency, no project change - PASS |
| II Backward compatibility | ZIPs without twins: byte-for-byte the old matching (default parameter TRUE, `pathFlag` as before); twin ZIPs: only "replaces the other twin" changes to "adds beside it" - PASS (known change recorded in the spec) |
| III Incremental modernization | one function, one header rule with unit checks - PASS |
| IV Windows commitment | WinAPI only - PASS |
| V Plugin architecture | no change of `spl_*.h` or `LAST_VERSION_OF_SALAMANDER`; the plug-in's own internals only - PASS |
| VI UI consistency | no new UI string, the overwrite question unchanged - PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/290-zip-add-case-twins/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/zip-add-case-twins.md
├── fix-log.md
└── probe/zip290_probe.ps1, result_*.txt
```

### Source Code (repository root)

```text
src/common/salcasetwins.h     # + SalPathsHaveCaseTwins (prefix rule)
src/common/salzipname.h       # SalZipMemberIs / SalZipMemberIsOrIsIn: + nameIgnoreCase (default TRUE)
src/plugins/zip/add.cpp       # CZipPack::MatchFiles: collect names in the pre-pass, twins -> exact
src/saltests/saltests.cpp     # TestPathTwins290 (+ cross-check against SalDirTreeHasCaseTwins)
```

**Structure Decision**: the rule is pure and goes to `src/common/` with saltests checks (CLAUDE.md:
shared rules for the ZIP plug-in are header-only); the plug-in only gathers the names and switches
the comparison.

## Complexity Tracking

None.
