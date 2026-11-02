# Implementation Plan: After a folder that cannot be read, the ISO plug-in still lists the later folders

**Branch**: `400-uniso-walk-after-unreadable` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/400-uniso-walk-after-unreadable/spec.md`

## Summary

The ISO plug-in's three folder walks (ISO 9660 `CISO9660::ListDirectoryRe`, UDF `CUDF::ScanDir`,
Xbox `CXDVDFS::ScanDir`) descend a listed folder only while nothing in the directory and below it has
failed. The fix replaces that condition by a walk state per file system walk: a folder is descended
unless the walk was stopped by out of memory; a nested failure makes the directory incomplete without
being forgotten by a later folder that walks fine; the walk's error boxes are shown once; the UDF and
Xbox walks get feature 328's visited set (each directory walked once, met again = empty folder). The
three rules are pure functions in a new header `src/common/salisowalk.h` with `saltests` checks that
fail for the old rule.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: plug-in `uniso` (`src/plugins/uniso/`), header-only rule in `src/common/`
**Storage**: N/A
**Testing**: `saltests` (pure rules); GUI probe `specs/400-uniso-walk-after-unreadable/probe/iso400_probe.ps1` on the hidden desktop (built on 330's)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in
**Performance Goals**: a crafted loop image opens within the probe's 30 s answer limit; each directory walked once per walk
**Constraints**: plug-in ABI unchanged; no UI string; no change for undamaged images
**Scale/Scope**: three reader files, one new header, saltests, one probe + image maker

## Constitution Check

- I Build reproducibility: no new dependency; the header is vendored source. PASS
- II Backward compatibility: undamaged images list exactly as before (FR-006, control rows). PASS
- III Incremental modernization: the change stays inside the three walks. PASS
- IV Windows commitment: N/A. PASS
- V Plug-in architecture: no ABI, no `spl_*.h` change. PASS
- VI UI consistency: no new string, existing boxes. PASS

Post-design re-check: unchanged (PASS).

## Project Structure

### Documentation (this feature)

```text
specs/400-uniso-walk-after-unreadable/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/  iso400_probe.ps1, img400.py, mkimg400.sh, result_*.txt
```

### Source Code (repository root)

```text
src/common/salisowalk.h          new: SalIsoWalk, SalIsoWalkDescends, SalIsoWalkAfterChild, SalIsoWalkBoxQuiet
src/plugins/uniso/iso9660.h/.cpp walk state member; ListDirectoryRe, ChainNotListed, AddFileDir boxes; CountUnder saves the state
src/plugins/uniso/udf.h/.cpp     walk state + visited set; ScanDir, AddFileDir out-of-memory sites, ListDirectory resets
src/plugins/uniso/xdvdfs.h/.cpp  walk state + visited set; ScanDir, AddFileDir out-of-memory sites, ListDirectory resets
src/saltests/saltests.cpp        TestIsoWalk_400: model walks of damaged trees, old rule fails
```

**Structure Decision**: plug-in sources plus one header-only rule (CLAUDE.md: shared rules for
plug-ins are header-only).

## Design

1. `salisowalk.h` (header-only, no Windows types):
   - results `SAL_ISO_WALK_OK / CONTINUE / TERMINATE` = the plug-in's `ERR_OK / ERR_CONTINUE /
     ERR_TERMINATE` (a `static_assert` in each reader);
   - `struct SalIsoWalk { bool Stopped; bool BoxShown; }`;
   - `SalIsoWalkDescends(w)` = `!w.Stopped`;
   - `SalIsoWalkAfterChild(ret, child)`: `TERMINATE` stays; a child other than OK makes `CONTINUE`;
     an OK child keeps `ret` (the old code assigned the child's result and could forget a failure);
   - `SalIsoWalkBoxQuiet(w, quiet)`: quiet walks stay quiet; else the first box shows, later quiet.
2. ISO 9660: member `SalIsoWalk Walk`, reset in `ListDirectory` before the fit walk and before the
   listing walk; `CountUnder` saves / restores it around its count walk (count walks are quiet).
   Every `Error(...)` of `ListDirectoryRe` and `ChainNotListed` passes `SalIsoWalkBoxQuiet(Walk,
   FitCheck)`; out-of-memory sites (visited insert, directory buffer, name buffer, chain) and an
   `ADD_FAILED` result (out of memory in `AddFileDir`) set `Walk.Stopped`. `AddFileDir`'s
   out-of-memory boxes pass the walk gate too. Descent: `if (SalIsoWalkDescends(Walk))`, result
   `ret = SalIsoWalkAfterChild(ret, sub)`.
3. UDF: members `SalIsoWalk Walk; std::set<unsigned long long>* Visited` (key `partition << 32 |
   location` of the folder's ICB). `ListDirectory` resets the state, inserts the root ICB, walks.
   `ScanDir`: boxes gated; before `MapICB` of a folder: met again -> not descended (empty folder,
   not marked); out of memory on insert -> `Stopped`, gated box, `ret = CONTINUE`. `AddFileDir`'s
   out-of-memory sites set `Stopped` and gate their box; a file whose entry cannot be read keeps
   ending its directory silently (330: marked through the walk result).
4. Xbox: as UDF, key = the folder's start sector; `new` failure and `AddFileDir` out of memory set
   `Stopped`.
5. Unchanged: the damaged directory's own tail (a bad record ends it), the core's `IDS_ERROR` boxes
   of a refused entry (328 / 329), root failures, HFS+ and audio readers.

## Verification

- `saltests`: model trees (one damaged folder before a readable one, several damaged folders, out of
  memory, a nested failure followed by a good folder) walked with the rule: every readable file
  listed, one box, result CONTINUE; the same trees with the old rule fail; mutants recorded.
- Probe `iso400_probe.ps1` (330's rows with the new expectation `zlast/z.txt` extracted; new rows
  RD-TWO, XD-TWO, XD-LOOP, XD-LOOP2, UD-LOOP) before (main build) and after; regressions: 328 (LOOP
  rows), 329, 330's control rows (in 400's probe), 327.

## Complexity Tracking

None.
