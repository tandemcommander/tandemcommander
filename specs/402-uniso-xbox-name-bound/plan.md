# Implementation Plan: ISO plug-in - an Xbox entry name is never read past the end of its directory

**Branch**: `402-uniso-xbox-name-bound` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/402-uniso-xbox-name-bound/spec.md`

## Summary

`CXDVDFS::ScanDir` (`src/plugins/uniso/xdvdfs.cpp`) checks only the 14-byte head of a directory entry
against the directory's buffer before copying `len` name bytes. A new header-only rule
`src/common/salisoxboxentry.h` decides, without wrap-around, whether an entry's head lies in the
directory (`SalIsoXboxEntryHeadFits`) and whether its whole name does, giving the offset of the next
entry (`SalIsoXboxEntryFits`). `ScanDir` uses the first for its loop and padding checks and the second
before it reads the name: a failing entry is a damaged record - the walk's one box
(`IDS_ERROR_LISTING_IMAGE`, `SalIsoWalkBoxQuiet`), the directory's walk ends with `ERR_CONTINUE`
(through `SalIsoWalkAfterChild(ret, ERR_TERMINATE)`), so `ListDirectory` marks the listing incomplete
and a whole unpack keeps the image. `saltests` gets `TestIsoXboxEntry402` (the boundaries and a model
walk over crafted directories).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; `src/common/salisowalk.h` (feature 400)
**Storage**: N/A
**Testing**: `saltests` (pure rule), GUI probe `probe/iso402_probe.ps1` on the hidden desktop (images by
`probe/img402.py`); regressions: feature 400's `iso400_probe.ps1` and 401's `iso401_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (uniso.spl)
**Performance Goals**: no measurable change (one comparison per entry)
**Constraints**: header-only (the plug-in cannot compile a `.cpp` from `src/common`); no new UI string;
no ABI change
**Scale/Scope**: one function in one file plus one header and one test

## Constitution Check

- I. Build reproducibility - no new dependency, no project file change beyond what a header needs (none:
  `src/common` is on the include path of uniso and saltests). PASS
- II. Backward compatibility - valid images list as before (the boundary control XD-EDGE, 400 / 401
  probes). PASS
- III. Incremental modernization - a local bound, pure rule with checks. PASS
- IV. Windows commitment - unchanged. PASS
- V. Plugin architecture - no `spl_*.h` change, no interface version change. PASS
- VI. UI consistency - the existing box and text; no new string, no translation. PASS

## Project Structure

### Documentation (this feature)

```text
specs/402-uniso-xbox-name-bound/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ img402.py, iso402_probe.ps1, result_*.txt
```

### Source Code (repository root)

```text
src/common/salisoxboxentry.h        new: SalIsoXboxEntryHeadFits, SalIsoXboxEntryFits
src/plugins/uniso/xdvdfs.cpp        CXDVDFS::ScanDir uses them; a damaged record ends the directory's walk
src/saltests/saltests.cpp           TestIsoXboxEntry402
```

**Structure Decision**: the existing layout; one new header beside `salisowalk.h`.

## Complexity Tracking

None.
