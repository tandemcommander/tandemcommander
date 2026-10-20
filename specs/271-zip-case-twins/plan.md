# Implementation Plan: A ZIP that holds names differing only in case is case-sensitive

**Branch**: `271-zip-case-twins` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/271-zip-case-twins/spec.md`

## Summary

The ZIP plug-in builds its listing case-sensitively (as 7-Zip / TAR since 252), keeps
`SALDIRFLAG_CASESENSITIVE` when an entry is Unix-made (the existing rule, unchanged restart) or when
`SalDirTreeHasCaseTwins(dir)` finds twins, and clears it otherwise. The decision is stored in the
listing's own plug-in data object (`CPluginDataInterface`, one per listing) and every operation the
core starts from that listing - `UnpackArchive` (copy / move out, paste), `UnpackOneFile` (view,
edit), `DeleteFromArchive` (delete, the second half of a move) - starts its `CZipCommon::Unix`
(the plug-in's "compare names case-sensitively" switch) from it, so a folder that has no entry of its
own is matched with the listing's case sensitivity too (research R2).

## Technical Context

**Language/Version**: C++20, MSVC v143
**Primary Dependencies**: plug-in SDK (`spl_*.h`, unchanged), `src/common/salcasetwins.h` (252)
**Storage**: N/A
**Testing**: hidden-desktop probe `probe/zip271_probe.ps1`; saltests already cover the twin rule
(`TestCaseTwins252`); build + encoding guard
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`src/plugins/zip`)
**Performance Goals**: one twin check per listing (252's measured cost); the central directory is
read once for archives without Unix entries, as before (SC-003)
**Constraints**: no plug-in ABI change; no UI strings
**Scale/Scope**: 5 files of the ZIP plug-in (`list.cpp`, `list.h`, `main.cpp`, `zipdll.h`,
`extract.cpp`)

## Constitution Check

- I Build reproducibility: no new dependency; header-only rule already vendored in `src/common`. PASS
- II Backward compatibility: ZIPs without twins keep today's case-insensitive listing and matching;
  Unix ZIPs stay case-sensitive. The only visible changes are the defect's (twin ZIPs). PASS
- III Incremental modernization: reuse of 252's rule, no rewrite. PASS
- IV Windows commitment: N/A. PASS
- V Plug-in architecture: no interface change - `CPluginDataInterface` is the plug-in's own class;
  the core hands it back unchanged. PASS
- VI UI consistency: no UI change. PASS

## Project Structure

### Documentation (this feature)

```text
specs/271-zip-case-twins/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/zip-case-sensitivity.md
├── fix-log.md, closing-report.md
└── probe/zip271_probe.ps1, result_*.txt
```

### Source Code (repository root)

```text
src/plugins/zip/
├── list.cpp    CZipList::List - build case-sensitively, twin check after the listing
├── list.h      CZipList - the listing's decision (CaseSensitive)
├── zipdll.h    CPluginDataInterface - carries the decision of its listing
├── main.cpp    ListArchive stores it; UnpackArchive / UnpackOneFile / DeleteFromArchive use it
└── extract.cpp CZipUnpack::UnpackOneFile - OR the per-entry flag instead of overwriting
```

**Structure Decision**: plug-in-only change; the pure rule stays in `src/common/salcasetwins.h`.

## Complexity Tracking

None.
