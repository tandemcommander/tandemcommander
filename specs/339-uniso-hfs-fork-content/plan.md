# Implementation Plan: ISO plug-in - an HFS+ file whose content is not in its data fork is not extracted empty

**Branch**: `339-uniso-hfs-fork-content` | **Date**: 2026-10-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/339-uniso-hfs-fork-content/spec.md`

## Summary

`CHFS::UnpackFile` (ISO plug-in, `src/plugins/uniso/hfs.cpp`) writes an HFS+ file's data fork as its
content. A new pure rule `SalHfsFileContentKind` (`src/common/salhfscatalog.h`, with `saltests` checks)
reads the file record: the compressed flag (`UF_COMPRESSED`, 0x20 in the BSD owner flags) in initialised BSD
information (file mode type bits not 0, TN1150) -> COMPRESSED; else an empty data fork with a non-empty
resource fork -> RESOURCE_ONLY; else DATA. `UnpackFile` asks the rule after its record checks and before it
creates the target file: for COMPRESSED / RESOURCE_ONLY it shows the reader's Skip / Skip all / Cancel box
(`DialogError`, `BUTTONS_SKIPCANCEL`) with one of two new texts, unless `silent` is set (then no box), and
returns `UNPACK_ERROR` (Skip / Skip all / silent) or `UNPACK_CANCEL` - no file is created. Feature 338's
`ExtractAllItems` tally then fails the whole unpack and the image is kept.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI; plug-in API (`CSalamanderGeneralAbstract::DialogError`), no new dependency
**Storage**: N/A (nothing stored)
**Testing**: `saltests` (pure rule), hidden-desktop probe `probe/iso339_probe.ps1` (+ `img339.py`, seed by
332's `mkimg332.sh` in WSL Ubuntu); regression probes 332 and 333
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (uniso.spl)
**Performance Goals**: one check of bytes already in memory per extracted HFS+ file - no measurable cost
**Constraints**: plug-in ABI untouched; UI strings in a free slot of an existing bundle (rule 084: ids 1062,
1063 of bundle 66); the error text to `DialogError` is UTF-8 (`LoadStrU8`, CFileErrorDlg sets it with
`SalSetWindowTextU8`), the caption code page (`LoadStr`) as the other readers
**Scale/Scope**: one reader function, one header rule, two strings, eight enabled languages

## Constitution Check

- I Build reproducibility: no new dependency, vendored nothing - PASS
- II Backward compatibility: files whose content is the data fork extract exactly as before (rows H-OK,
  H-NOMODE, H-BOTH); plug-in ABI unchanged - PASS
- III Incremental modernization: a header-only rule beside 322/332/333's, tested - PASS
- IV Windows commitment: WinAPI only - PASS
- V Plug-in architecture preservation: uses the existing `DialogError` service - PASS
- VI UI consistency: the same box as the readers' read errors; texts translated (formal register) - PASS

Re-checked after design: no change.

## Project Structure

### Documentation (this feature)

```text
specs/339-uniso-hfs-fork-content/
├── plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md
└── probe/ (iso339_probe.ps1, img339.py, result_*.txt)
```

### Source Code (repository root)

```text
src/common/salhfscatalog.h        # + SalHfsFileContentKind, SAL_HFSFILE_*
src/saltests/saltests.cpp         # + TestHfsFileContent339
src/plugins/uniso/hfs.cpp         # CHFS::UnpackFile: refuse before creating the file
src/plugins/uniso/uniso.rh2       # + IDS_ERR_HFS_FILE_COMPRESSED 1062, IDS_ERR_HFS_FILE_RSRC_ONLY 1063
src/plugins/uniso/lang/lang.rc2   # + the two English texts
translations/<language>/uniso.slt / .origin  # two-stage refresh (stop-rules 2.13)
```

**Structure Decision**: the existing uniso plug-in and the shared header of its HFS+ rules.

## Complexity Tracking

None.
