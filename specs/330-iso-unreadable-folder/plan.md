# Implementation Plan: An image whose folder could not be read is kept by Unpack with "Delete archive after unpacking"

**Branch**: `330-iso-unreadable-folder` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/330-iso-unreadable-folder/spec.md`

## Summary

Feature 328 gave the `uniso` plug-in a "listing incomplete" mark on the image
(`CISOImage::ListingLeftOut.SetIncomplete()`); `ListArchive` copies it into the plug-in data and
`UnpackWholeArchive` then fails, so "Delete archive after unpacking" keeps the image. Read errors of
the folder walks never set it. This feature sets it:

- **ISO 9660** (`CISO9660::ListDirectory`): the real walk's result is checked once at the top - any
  result other than `ERR_OK` marks the listing. Every failure inside `ListDirectoryRe` (directory
  read, record safety checks, zero block / size, out of memory, a nested failure) already makes the
  walk's result non-OK: a nested `ERR_TERMINATE` becomes the parent's `ERR_CONTINUE`, which stays in
  `ret` and is returned by every ancestor; the root's read failure returns `ERR_CONTINUE`. A
  directory met again (328's visited set) returns `ERR_OK` - not marked, as the spec says. The fit
  check and count walks (`FitCheck`) are not the listing: their results are not used for the mark
  (the real walk reads the same directories).
- **Xbox** (`CXDVDFS::ListDirectory`): the same top-level rule (its walk propagates failures the
  same way: a nested `ERR_TERMINATE` becomes `ERR_CONTINUE`, an out-of-memory entry `ERR_CONTINUE`).
- **UDF** (`CUDF::ListDirectory`): the same top-level rule (directory read errors, an invalid tag, a
  file whose entry cannot be read - `ADD_FAILED` - all end their directory with a non-OK result), plus
  the early returns before the walk (the File Set Descriptor not read / not found, the root ICB not
  mapped or not a directory) and, in `CUDF::ScanDir`, a folder whose file entry `MapICB` cannot read
  (it was listed empty without a word, the walk went on with `ERR_OK`). Review 1 (stopped reviewer)
  measured the last three; the first plan marked only the "Error reading directory structure" sites.
- **Hybrids** (`CUDFISO`, review 2): `CISOImage::OpenTrack` passes which parts the track's type
  declares (ISO 9660, UDF); `CUDFISO::Open` remembers when a declared part did not open
  (`PartMissing`) and `CUDFISO::ListDirectory` marks the listing. HFS+ stays quiet (Inbox
  `iso-plug-in-an-hfs-part-of-a-hybrid-that-does-not-open-is`).

No new UI string, no plug-in interface change, no message added or removed.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: plug-in API (unchanged); `src/common/salisonamefit.h` `CSalListingLeftOut` (328)  
**Storage**: N/A  
**Testing**: hidden-desktop probe `probe/iso330_probe.ps1` (Unpack rows of damaged images + controls); regression probes 328 / 329; `saltests` unchanged (no new pure rule - research R3)  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application, archiver plug-in `uniso`  
**Performance Goals**: none (one comparison per listing / per error)  
**Constraints**: plug-in ABI unchanged; no UI string; listing and messages unchanged; damaged-entry skips untouched (Inbox item)  
**Scale/Scope**: `iso9660.cpp`, `udf.cpp`, `xdvdfs.cpp` (a few lines each), the probe and its image writers

## Constitution Check

- I Build reproducibility: no new dependency. PASS
- II Backward compatibility: a readable image lists, unpacks and is deleted as before; the plug-in
  interface is untouched. PASS
- III Incremental modernization: a local fail-closed mark using 328's existing mechanism. PASS
- IV Windows commitment: N/A. PASS
- V Plug-in architecture: no ABI change. PASS
- VI UI consistency: the existing error box is the report; nothing new shown. PASS

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/330-iso-unreadable-folder/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/ (iso330_probe.ps1, mkimg330.sh, img330.py, result_*.txt)
```

No `contracts/`: nothing is exposed to plug-ins or users beyond the existing box and the existing
mark.

### Source Code (repository root)

```text
src/plugins/uniso/iso9660.cpp   ListDirectory: a non-OK walk result marks the listing incomplete
src/plugins/uniso/udf.cpp       ListDirectory / ScanDir: each "Error reading directory structure" marks it
src/plugins/uniso/xdvdfs.cpp    ScanDir: the same
```

**Structure Decision**: the existing plug-in layout; no new source files besides the probe.

## Complexity Tracking

None.
