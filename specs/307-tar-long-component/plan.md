# Implementation Plan: An archive member whose name the panel cannot hold never crashes the program

**Branch**: `307-tar-long-component` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/307-tar-long-component/spec.md`

## Summary

Two changes, each enough for the measured crash, together closing the route for every plug-in:

1. **Core** (`CSalamanderDirectory::AddFile` / `AddDir`, `src/zip.cpp`): the name bound of
   feature 222 is skipped when the plug-in passes no folder part (`path == NULL` - the archive
   root of the tar plug-in, every file-system plug-in). A new header-only rule
   `src/common/sallistingname.h` decides acceptance; with no folder part it refuses only a name of
   `SAL_FIND_NAME_U8` (780) bytes or more - the size of the panel's name buffers - and keeps
   accepting everything shorter (FR-001 - FR-003). With a folder part the rule is the existing one,
   moved unchanged into the header.
2. **Tar plug-in** (`src/plugins/tar/untar.cpp`, `tar.h`): a member whose effective name comes from
   a GNU long name (`L`) gets feature 306's `SalPaxNameFitsListingU8` check and refusal (member
   ignored, "(206)" text + path once per listing / whole unpack) - FR-004 - FR-006. A flag
   `NameFromGnuLong` beside `NameFromPax`, set in the GNU branch and reset with the header.

`saltests` check the core rule at its boundaries (FR-007). A new hidden-desktop probe
`specs/307-tar-long-component/probe/tar307_probe.ps1` (built on 306's) drives the rows.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new
**Storage**: N/A
**Testing**: `saltests` (the rule), hidden-desktop probe `tar307_probe.ps1` + 306's `pax306_probe.ps1` (regression)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand` + plug-in `tar.spl`)
**Performance Goals**: none; `AddFile` is time-critical - the rule stays a few comparisons (the 255-unit count runs only for names over 255 bytes, as before)
**Constraints**: plug-in ABI and `spl_*.h` unchanged; no new UI strings; tar plug-in uses header-only shared code
**Scale/Scope**: two functions in the core, one branch in the tar reader, one header, one probe

## Constitution Check

| Principle | Status |
|---|---|
| I Build reproducibility | PASS - a plain header, no dependency |
| II Backward compatibility | PASS - every name accepted today below 780 bytes stays accepted; only names that overflowed the panel (crash) are refused; tar members with classic names unchanged; ABI untouched |
| III Incremental modernization | PASS - local changes |
| IV Windows commitment | PASS |
| V Plugin architecture preservation | PASS - `AddFile` / `AddDir` already "return success"; a refusal uses the existing failure path |
| VI UI consistency | PASS - existing message box and texts |

Standing rules: names UTF-8 (byte length and UTF-16 units of UTF-8); a path is never cut - the
member is refused whole; pure decisions in `src/common/` with `saltests`. Post-design re-check: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/307-tar-long-component/
├── spec.md  plan.md  research.md  data-model.md  quickstart.md  contracts/listing-name-bound.md
├── fix-log.md  tasks.md  checklists/requirements.md
└── probe/   tar307_probe.ps1, mktar307.py, result_*.txt
```

### Source Code (repository root)

```text
src/common/sallistingname.h      new: SalListingAcceptsFileU8 / SalListingAcceptsDirU8
src/zip.cpp                      AddFile / AddDir use the rule (path == NULL no longer bypasses it)
src/plugins/tar/tar.h            SCommonHeader::NameFromGnuLong
src/plugins/tar/untar.cpp        GNU 'L' branch sets the flag; ReadArchiveHeader's refusal covers it; Initialize
src/saltests/saltests.cpp        checks of the rule
```

**Structure Decision**: existing layout; one new header beside `salpaxheader.h` / `salmaskname.h`.

## Complexity Tracking

None.
