# Implementation Plan: Extraction of a PAX tar takes every member a file system takes

**Branch**: `308-pax-deep-unpack` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/308-pax-deep-unpack/spec.md`

## Summary

Feature 306 refuses a PAX member in `CArchive::ReadArchiveHeader` (`src/plugins/tar/untar.cpp`) with the
panel listing's bound (`SalPaxNameFitsListingU8`, `src/common/salpaxheader.h`) in every pass over the
archive, so extraction passes skip members a file system takes and still return success; the core then
honours "Delete archive after unpacking" (`src/fileswn7.cpp`, `SalDeleteFile` on success only). The fix:
the bound depends on the pass - the listing bound only while listing, the component rule (over 255
UTF-16 units) in extraction passes - and an extraction that meets a refused member it was asked to
extract reports it ("(206)" + path, once) and returns FALSE after extracting the rest.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; header-only rule in `src/common/salpaxheader.h` (shared with saltests)
**Storage**: N/A (no registry or configuration change)
**Testing**: `saltests` (new checks of the pass-dependent rule); hidden-desktop probe
`probe/unp308_probe.ps1`; regression: `specs/306-tar-pax-headers/probe/pax306_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, archiver plug-in (TAR)
**Performance Goals**: unchanged (one string scan per member, as before)
**Constraints**: plug-in ABI untouched; no UI string added (the "(206)" text is the system's)
**Scale/Scope**: `src/plugins/tar/untar.cpp`, `src/plugins/tar/tar.h`, `src/common/salpaxheader.h`,
`src/saltests/saltests.cpp`

## Constitution Check

- I Build reproducibility: no new dependency, no build change - PASS.
- II Backward compatibility: listing unchanged (306 probe); extraction returns to extracting every
  member that a file system takes, as 0.1.10 did for these archives under their fallback names - PASS.
- III Incremental modernization: a local change in one plug-in; the rule stays header-only - PASS.
- IV Windows commitment: the bound is the Windows file-system component limit - PASS.
- V Plugin architecture preservation: no `spl_*.h` change, `LAST_VERSION_OF_SALAMANDER` untouched - PASS.
- VI UI consistency: the existing "(206)" box, same title, no new string - PASS.

Standing rules touched: never cut a name (a too-long component is refused, never shortened - kept);
never lose the user's data (a failed extraction keeps the archive - the point of the feature).

## Project Structure

### Documentation (this feature)

```text
specs/308-pax-deep-unpack/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/   unp308_probe.ps1, mkunp308.py, result_*.txt
```

No `contracts/`: no interface other components rely on changes (the plug-in returns FALSE from an
operation it already could fail).

### Source Code (repository root)

```text
src/common/salpaxheader.h      SalPaxNameUsableU8(name, isDir, prefixLen, listing) - the pass-dependent rule
src/plugins/tar/tar.h          SCommonHeader::NameRefused; CArchive::Listing replaces ReportRefusedNames;
                               CArchive::ReportRefusedName()
src/plugins/tar/untar.cpp      ReadArchiveHeader uses the rule; ListArchive sets Listing; DoUnpackArchive
                               and UnpackOneFile report a refused member they were asked for and fail
src/saltests/saltests.cpp      checks of SalPaxNameUsableU8
```

**Structure Decision**: existing tar plug-in and shared header; no new file in `src/`.

## Complexity Tracking

None.
