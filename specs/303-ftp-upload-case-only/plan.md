# Implementation Plan: An FTP upload asks before replacing a server file whose name differs only in case

**Branch**: `303-ftp-upload-case-only` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/303-ftp-upload-case-only/spec.md`

## Summary

The FTP upload's existence check (`CUploadListingsOnServer::GetListing` -> `CUploadPathListing::FindItem`)
compares names byte for byte on Unix path types, so `B.txt` does not see `b.txt` and is sent
without the overwrite question - a case-insensitive server then replaces `b.txt`. The fix: when
the exact lookup finds nothing and the caller asks for it, a second pass looks for a listed name
that is the same name under the file system's rule of feature 092 (`SalNameOrderEqualCI`); such an
item is reported as existing with its size marked unknown. The file upload's start check, the
resume size lookup and the file auto-rename ask for it; the folder upload sites do not. The pure
lookup lives in a new header `src/common/salftpupname.h` with `saltests` checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; `src/common/salnameorder.h` (header-only, already included by
`operats9.cpp`)
**Storage**: N/A
**Testing**: `saltests` (new `TestFtpCaseOnlyName303`), hidden-desktop probe
`probe/ftp303_probe.ps1` (215's `ftpmini.py` on NTFS), regressions: 288's / 224's FTP probes
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`ftp.spl`)
**Performance Goals**: one pass over the listing per lookup the exact search did not answer
(SC-006); the rule rejects two different ASCII first letters without converting
**Constraints**: no new UI strings (FR-007); plug-in ABI untouched (internal classes only)
**Scale/Scope**: 3 files of the FTP plug-in (`operats9.cpp`, `operats.h`, `operatsb.cpp`, plus
`operatsa.cpp` for the explicit argument), 1 new header, saltests

## Constitution Check

- I. Build Reproducibility - no new dependency; header-only addition. PASS
- II. Backward Compatibility - behaviour changes only where a case-only twin exists (one more
  question); exact matches and folder uploads unchanged; no stored data or settings change. PASS
- III. Incremental Modernization - one decision moved into a tested header. PASS
- IV. Windows Platform Commitment - the rule is Windows' own (`CompareStringOrdinal`). PASS
- V. Plugin Architecture Preservation - no plug-in interface change (`CUploadListingCache` is
  internal to the FTP plug-in). PASS
- VI. UI Consistency - the existing "Target File Already Exists" question; no new text. PASS

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/303-ftp-upload-case-only/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/case-only-lookup.md
├── fix-log.md
├── checklists/requirements.md
├── probe/ftp303_probe.ps1, result_*.txt
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salftpupname.h          new: SalFtpFindCaseOnlyName (pure, header-only)
src/plugins/ftp/operats.h          GetListing declarations: + BOOL caseOnlyCounts
src/plugins/ftp/operats9.cpp       CUploadListingCache::GetListing / CUploadListingsOnServer::GetListing
src/plugins/ftp/operatsb.cpp       the three file-upload callers pass TRUE
src/plugins/ftp/operatsa.cpp       the two folder-upload callers pass FALSE (unchanged behaviour)
src/saltests/saltests.cpp          TestFtpCaseOnlyName303
```

**Structure Decision**: the existing FTP plug-in and saltests; no new project.

## Complexity Tracking

None.
