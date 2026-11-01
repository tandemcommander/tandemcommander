# Implementation Plan: The ISO plug-in extracts Video CD / SVCD video files whole

**Branch**: `366-uniso-form2-files` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/366-uniso-form2-files/spec.md`

## Summary

A file whose ISO 9660 record carries a CD-XA attribute "Form 2" (not "Form 1"), on a track that stores the
2324-byte Form 2 user data where the plug-in reads user data, and whose first sector is a valid Form 2
sector, is listed with sectors x 2324 bytes and read 2324 bytes a sector by both content readers
(`CISO9660::UnpackFile`, `CRawFS::UnpackFile`); feature 337's coverage span counts its sectors by 2324.
Every other file is unchanged. Rules in `src/common/salisotrack.h` with `saltests` checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: none new  
**Storage**: N/A  
**Testing**: `saltests` (`TestIsoXaForm2_366`); hidden-desktop probe `probe/iso366_probe.ps1` (images by
`probe/img366.py` from the real vcdimager output in `%TEMP%\rev335c\data`; content checked by SHA-256 against
expectations the generator writes); regressions: the probes of 337 (with 336 / 335 rows), 365, 334  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (uniso)  
**Performance Goals**: one extra read of 24 bytes per listed file with an XA Form 2 attribute (a Video CD has
one per video track)  
**Constraints**: plug-in ABI unchanged (`CFilePos` is the plug-in's own data); header-only rules; no UI string  
**Scale/Scope**: iso9660.cpp, rawfs.cpp, isoimage.cpp/.h, salisotrack.h, saltests.cpp

## Constitution Check

| Principle | Status |
|---|---|
| I. Build reproducibility | No new dependency. PASS |
| II. Backward compatibility | Every file without an XA Form 2 attribute, or on a track that cannot hold Form 2 data, or whose first sector is not Form 2, is listed and read as before (FR-004; probe control rows, regression probes). PASS |
| III. Incremental modernization | The decisions as pure rules with tests. PASS |
| IV. Windows commitment | Unchanged. PASS |
| V. Plugin architecture | No change to `spl_*.h`, no ABI change. PASS |
| VI. UI consistency | No new text, dialog or menu - no `.slt` refresh. PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/366-uniso-form2-files/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
├── checklists/requirements.md
└── probe/ (iso366_probe.ps1, img366.py, vcdscan.py, result_*.txt)
```

No `contracts/`: the change is internal to the plug-in (no plug-in interface, file format written or
command line).

### Source Code (repository root)

```text
src/common/salisotrack.h       # + SalIsoXaAttributes, SalIsoXaIsForm2File, SalIsoTrackStoresForm2,
                               #   SalIsoForm2FileSize; SalIsoFileSectorSpan takes the bytes a sector
src/plugins/uniso/isoimage.h   # CFilePos::Form2; CISOImage::FileIsForm2, ReadForm2Block
src/plugins/uniso/isoimage.cpp # FileIsForm2 (track of the extent, first sector's subheader), ReadForm2Block,
                               #   NoteListedFileStarts passes the file's sector size
src/plugins/uniso/iso9660.cpp  # ListDirectoryRe -> AddFileDir: XA attributes, Form 2 size; UnpackFile 2324
src/plugins/uniso/rawfs.cpp    # UnpackFile 2324 for a Form 2 file
src/saltests/saltests.cpp      # TestIsoXaForm2_366
```

**Structure Decision**: the existing uniso plug-in and its rule header `salisotrack.h`.

## Complexity Tracking

None.
