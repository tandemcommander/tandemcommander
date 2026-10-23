# Implementation Plan: UDF, Xbox, HFS+ and audio entries the panel listing refuses are left out and reported

**Branch**: `329-uniso-other-readers-refused` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/329-uniso-other-readers-refused/spec.md`

## Summary

Feature 328 gave the ISO 9660 reader of the `uniso` plug-in the rule "ask the listing first: a
refused entry is left out alone and recorded on the image (`CISOImage::ListingLeftOut`)"; the
report box (`ListArchive`) and the failing whole unpack (`UnpackWholeArchive`) already read that
record for the whole image. This feature gives the same rule to the four other readers:

- `CUDF::AddFileDir` / `CXDVDFS::AddFileDir` return 328's three results (listed / left out /
  failed); a left-out entry is recorded and not descended, the walk continues with the next record
  and later folders (no "Error", the rest of the folder kept); out of memory as in 328.
- `CHFS::ListDirectory` records a refused folder or file and continues; the catalog IDs of left-out
  folders are remembered so their contents (whose parent is not in `pFolders`) are skipped instead
  of falling back to the HFS+ root.
- `CAudio::AddFileDir` records a refused track name and no longer clears the listing.

The listing's rule is `sallistingname.h` (the same function the core's `AddFile` / `AddDir` uses);
the remembered left-out folder IDs are a small header-only class in `src/common/salisonamefit.h`
with saltests checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: plug-in API (unchanged), `src/common/sallistingname.h` (321), `src/common/salisonamefit.h` (328)  
**Storage**: N/A  
**Testing**: `saltests` (new checks for the left-out folder set), hidden-desktop probe `probe/iso329_probe.ps1` (7 rows); regression probes 328 / 327 / 322  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application, archiver plug-in `uniso`  
**Performance Goals**: one length check per entry (as the core already does it); HFS+: a lookup per record in a set that is empty unless something was left out  
**Constraints**: plug-in ABI unchanged; no UI string added or removed; never a cut name or path; read errors keep their handling (Inbox item)  
**Scale/Scope**: `udf.cpp/.h`, `xdvdfs.cpp/.h`, `hfs.cpp`, `audio.cpp`, `src/common/salisonamefit.h`, `src/saltests/saltests.cpp`

## Constitution Check

- I Build reproducibility: no new dependency; header-only rule. PASS
- II Backward compatibility: listings with nothing refused are unchanged; plug-in interface untouched. PASS
- III Incremental modernization: four local changes following 328's pattern; the pure part tested. PASS
- IV Windows commitment: N/A. PASS
- V Plug-in architecture: no ABI change; header-only shared rule (CLAUDE.md). PASS
- VI UI consistency: the report is 328's box (system text 206); "Error" / "too long path" boxes for a
  refused entry disappear. PASS

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/329-uniso-other-readers-refused/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md
└── probe/ (iso329_probe.ps1, mkimg329.sh, img329.py, result_*.txt)
```

No `contracts/`: nothing is exposed to plug-ins or users beyond the existing report box.

### Source Code (repository root)

```text
src/common/salisonamefit.h          + CSalLeftOutIds (catalog IDs of left-out folders)
src/plugins/uniso/udf.h, udf.cpp     AddFileDir -> ADD_* results; ScanDir continues
src/plugins/uniso/xdvdfs.h, xdvdfs.cpp  the same
src/plugins/uniso/hfs.cpp            ListDirectory: record, skip the subtree, continue
src/plugins/uniso/audio.cpp          AddFileDir: record, never Clear
src/saltests/saltests.cpp            checks for CSalLeftOutIds
```

**Structure Decision**: the existing plug-in and shared-header layout; no new files besides the probe.

## Complexity Tracking

None.
