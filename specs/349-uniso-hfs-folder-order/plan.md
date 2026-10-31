# Implementation Plan: ISO plug-in - an HFS+ folder whose ID is lower than its parent's lists its contents in it

**Branch**: `349-uniso-hfs-folder-order` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/349-uniso-hfs-folder-order/spec.md`

## Summary

`CHFS::ListDirectory` (ISO plug-in, `src/plugins/uniso/hfs.cpp`) takes the HFS+ catalog's leaf records in
order and finds each record's folder among the folders listed so far (`pFolders`), else the HFS+ root.
The fix keeps that loop and its per-record logic and adds an order rule:

1. A first pass collects every folder record the listing would list (`SalHfsCatalogRecordClass` ==
   `SAL_HFSREC_FOLDER`): its folder ID, its parent ID, its record index - into a new pure class
   `CSalHfsFolderOrder` (`src/common/salisonamefit.h`, beside 329's `CSalLeftOutIds`; header-only, with
   `saltests` checks).
2. In the loop, before a record is taken, `Pending(parentId)` gives the folder records above it that are
   not taken yet, outermost first (or reports a loop of parents). Those folders are taken first through
   the same per-record code (moved into a member `CHFS::ListRecord`), so each lands under its own parent's
   path, is left out by the listing rule (329) or is skipped under a left-out folder (`CSalLeftOutIds::Under`)
   exactly as when met in order. Every record taken is marked; the loop skips a record already taken.
3. A loop: its folders (and the chain below them that led into it) are marked taken, their IDs added to
   `CSalLeftOutIds` (everything inside follows through `Under`), the listing marked incomplete
   (`ListingLeftOut.SetIncomplete`), no message.

A parent that is no folder of the table (the root used as the volume label, metadata folders, damaged
records, unknown IDs) has no pending folders: the record goes where it went before.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI; plug-in API unchanged; `std::vector` / `std::lower_bound` (as `CSalLeftOutIds`)
**Storage**: N/A
**Testing**: `saltests` (`TestHfsFolderOrder349`), hidden-desktop probe `probe/iso349_probe.ps1`
(+ `mkimg349.sh` in WSL Ubuntu, `img349.py`); regression probes 322, 329, 332, 333, 339
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (uniso.spl)
**Performance Goals**: one extra pass over the records already in memory; each folder walked up at most
once until taken (amortised linear); no recursion
**Constraints**: plug-in ABI untouched; no UI string; behaviour for in-order catalogs identical; Extent =
record index kept (extraction reads it)
**Scale/Scope**: one reader function split in two, one header class, one test function

## Constitution Check

- I Build reproducibility: no new dependency - PASS
- II Backward compatibility: in-order catalogs list exactly as before (probe H-OK, regression probes);
  plug-in ABI unchanged - PASS
- III Incremental modernization: a header-only rule beside 329's, tested - PASS
- IV Windows commitment: unchanged - PASS
- V Plug-in architecture preservation: no interface change - PASS
- VI UI consistency: no new UI; a left-out folder reported as 329 does - PASS

Re-checked after design: no change.

## Project Structure

### Documentation (this feature)

```text
specs/349-uniso-hfs-folder-order/
├── plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md
└── probe/ (iso349_probe.ps1, mkimg349.sh, img349.py, result_*.txt)
```

### Source Code (repository root)

```text
src/common/salisonamefit.h        # + CSalHfsFolderOrder, SAL_HFS_PENDING_*
src/saltests/saltests.cpp         # + TestHfsFolderOrder349
src/plugins/uniso/hfs.cpp         # CHFS::ListDirectory: first pass + pending folders; CHFS::ListRecord
src/plugins/uniso/hfs.h           # + ListRecord, TakePending declarations
```

**Structure Decision**: the existing uniso plug-in and the shared header of its listing rules.

## Complexity Tracking

None.
