# Implementation Plan: Archives - F3 / F4 of long member names, the gzip name read whole

**Branch**: `260-archive-cache-long-names` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/260-archive-cache-long-names/spec.md`

## Summary

The disk cache refuses a temporary copy whose UTF-8 path reaches 260 BYTES; F3 / F4 of archive
members with long valid names (90 CJK letters = 274 bytes, 94 UTF-16 units) are therefore
refused although Windows takes the path. The core's own F3 / F4 of archive members get a
"long" mode: the copy fits when its whole path has at most `MAX_PATH - 1` UTF-16 units (a pure
rule in `src/common/salcachename.h`, saltests); the cache builds the path on the heap. The plug-in
services and the User Menu keep the byte rule (plug-in interface unchanged). The edit's way back
(`CFileTimeStamps`) holds paths on the heap and refuses a target the shell cannot take. The tar
plug-in reads a gzip header's stored name whole and refuses a name over 255 UTF-16 units with the
system's "The filename or extension is too long."; long folders need no change (measured: reported).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: WinAPI only; core `src/cache.cpp`, `src/fileswn5.cpp`, `src/fileswn6.cpp`,
`src/salamdr3.cpp`; tar plug-in `src/plugins/tar/gzip/gunzip.cpp`, `fileio.cpp/.h`, `untar.cpp`  
**Storage**: temporary files under %TEMP% (the disk cache) - no change of what is stored or where  
**Testing**: `saltests` (pure rule), hidden-desktop probe `probe/cache260_probe.ps1`, regression
`specs/222-name-length-units/probe/editname222_probe.ps1`  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application + plug-ins  
**Performance Goals**: none (one length count per cache insertion)  
**Constraints**: plug-in ABI unchanged; no new UI strings (no `.slt` refresh); never cut a name  
**Scale/Scope**: ~6 source files, 1 new header, 1 probe

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency, no project change except a header include | PASS |
| II Backward compatibility | plug-in services keep their limit; interface version unchanged; short names behave as before | PASS |
| III Incremental modernization | narrow change of the cache rule for two core callers | PASS |
| IV Windows commitment | rule follows the Windows path limit (UTF-16 units) | PASS |
| V Plug-in architecture | no `spl_*.h` change; tar takes a header-only rule from `src/common` | PASS |
| VI UI consistency | existing messages only (one system text) | PASS |

Re-check after design: PASS (no change).

## Project Structure

### Documentation (this feature)

```text
specs/260-archive-cache-long-names/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/cache-tmp-path.md
├── fix-log.md, closing-report.md (later)
├── probe/cache260_probe.ps1, probe/result_*.txt
└── tasks.md
```

### Source Code

```text
src/common/salcachename.h          NEW: SalCacheTmpPathFitsU8 (pure rule)
src/saltests/saltests.cpp          TestCacheTmpPath260
src/cache.h, src/cache.cpp         long mode through CDiskCache::GetName -> CCacheDirData; heap path
src/fileswn5.cpp                   F3 of an archive member: long mode
src/fileswn6.cpp                   F4 of an archive member: long mode
src/salamdr3.cpp                   CheckAndPackAndClear / CopyFilesTo: whole paths
src/plugins/tar/gzip/gunzip.cpp    ORIG_NAME read whole (bounded), too-long flag
src/plugins/tar/fileio.h/.cpp      the flag
src/plugins/tar/untar.cpp          GetStreamHeader refuses a name over 255 UTF-16 units
```

**Structure Decision**: core + one plug-in, existing layout.

## Complexity Tracking

None.
