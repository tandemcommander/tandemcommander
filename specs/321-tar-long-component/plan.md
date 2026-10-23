# Implementation Plan: An archive member whose name the panel cannot hold never crashes the program

**Branch**: `321-tar-long-component` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/321-tar-long-component/spec.md`; the first run's plan
in `run307/plan.md`.

## Summary

Three changes, carried over from the first run (307) and adapted to features 308-310 on `main`:

1. **Core** (`CSalamanderDirectory::AddFile` / `AddDir`, `src/zip.cpp`): the name bound of feature
   222 is skipped when the plug-in passes no folder part (`path == NULL`). The header-only rule
   `src/common/sallistingname.h` decides acceptance; with no folder part it refuses only a name of
   `SAL_FIND_NAME_U8` (780) bytes or more and keeps accepting everything shorter (FR-001 - FR-003).
   With a folder part the rule is feature 222's, moved unchanged.
2. **Panel extension copies** (`CFilesWindow::ReadDirectory`, `src/fileswn3.cpp`, the two loops into
   `char buf[SAL_FIND_NAME_U8]`): bounded, an extension that does not fit gets no association
   (FR-009; first run's review 1 MUST).
3. **Tar plug-in** (`src/plugins/tar/untar.cpp`, `tar.h`): `SCommonHeader::NameFromGnu`, set when a
   `GNUTYPE_LONGNAME` header supplied `header.Name`; `ReadArchiveHeader`'s refusal runs for
   `NameFromPax || NameFromGnu` with 308's pass-dependent `SalPaxNameUsableU8(..., Listing)` -
   listing: the depth / folder-name bound + component rule, message once; extraction: only the
   component rule, `NameRefused` set, an extraction asked for the member reports it and fails
   (FR-004 - FR-006; first run's review 2 MUST). `SalPaxNameFitsListingU8` keeps the first run's
   review-1 change: a top-level folder name is not byte-bounded.

`saltests` check both rules (FR-008). The probe `probe/tar321_probe.ps1` (the first run's, extended
with Unpack and Unpack + Delete-archive rows of a deep GNU tree and of the refused name) drives the
rows; 306 / 308 probes are re-run for regression.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new
**Storage**: N/A
**Testing**: `saltests`; hidden-desktop probes `tar321_probe.ps1`, `pax306_probe.ps1`, 308's probe
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand` + plug-in `tar.spl`)
**Performance Goals**: none; `AddFile` is time-critical - the rule stays a few comparisons
**Constraints**: plug-in ABI and `spl_*.h` unchanged; no new UI strings; tar plug-in uses header-only shared code
**Scale/Scope**: two core functions, two loops, one branch + one condition in the tar reader, one header

## Constitution Check

| Principle | Status |
|---|---|
| I Build reproducibility | PASS - a plain header, no dependency |
| II Backward compatibility | PASS - every name accepted today below 780 bytes stays accepted; only names that overflowed the panel are refused; a whole unpack extracts every member a file system takes, as 0.1.10; ABI untouched |
| III Incremental modernization | PASS - local changes |
| IV Windows commitment | PASS |
| V Plugin architecture preservation | PASS - `AddFile` / `AddDir` already return success; a refusal uses the existing failure path |
| VI UI consistency | PASS - existing message box and texts |

Standing rules: names UTF-8; a path is never cut - the member is refused whole; "Never lose the
user's data": a refusal in an extraction fails the operation (no "Delete archive after
unpacking"); pure decisions in `src/common/` with `saltests`. Post-design re-check: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/321-tar-long-component/
├── spec.md  plan.md  research.md  data-model.md  quickstart.md  contracts/listing-name-bound.md
├── fix-log.md  tasks.md  checklists/requirements.md
├── run307/  the first run's record (read-only)
└── probe/   tar321_probe.ps1, mktar321.py, result_*.txt
```

### Source Code (repository root)

```text
src/common/sallistingname.h      new: SalListingAcceptsFileU8 / SalListingAcceptsDirU8
src/common/salpaxheader.h        SalPaxNameFitsListingU8: top-level folder name not byte-bounded
src/zip.cpp                      AddFile / AddDir use the rule
src/fileswn3.cpp                 two bounded extension copies
src/plugins/tar/tar.h            SCommonHeader::NameFromGnu
src/plugins/tar/untar.cpp        GNU 'L' branch sets it; Initialize resets it; the refusal covers it
src/saltests/saltests.cpp        TestListingName321, 306's corrected folder checks, GNU pass checks
```

**Structure Decision**: existing layout.

## Complexity Tracking

None.
