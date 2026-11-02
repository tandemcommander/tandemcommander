# Implementation Plan: An ISO 9660 folder met again with another length is walked for its own length

**Branch**: `401-uniso-share-length` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/401-uniso-share-length/spec.md`

## Summary

The ISO 9660 walk of the ISO plug-in records each folder it walks in a visited set keyed by the
folder's start block alone (feature 328). Two folder records naming one block with different data
lengths make the second folder "met again": listed empty, nothing marked, and a whole Unpack with
"Delete archive after unpacking" deletes the image. Key the set by start block **and** data length
(one 64-bit key, the rule feature 400 gave the Xbox walk), in all three ISO 9660 walks (fit check,
count walks, listing walk); count walks keep removing exactly the keys they added.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new (std::set, std::vector)
**Storage**: N/A
**Testing**: `saltests` (the key rule in `src/common/salisowalk.h`), GUI probe `iso401_probe.ps1` on the
hidden desktop; regressions `iso328_probe.ps1`, `iso400_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`uniso.spl`)
**Performance Goals**: a walk stays bounded: each distinct (block, length) pair at most once per walk
**Constraints**: plug-in ABI untouched (internal change of `CISO9660`); no UI text
**Scale/Scope**: `src/plugins/uniso/iso9660.cpp` / `.h`, `src/common/salisowalk.h`, `saltests.cpp`;
`xdvdfs.cpp` takes the shared key function (identical value)

## Constitution Check

| Principle | Check |
|-----------|-------|
| I Build reproducibility | no new dependency, vendored only - PASS |
| II Backward compatibility | listing of well-formed images unchanged (one record per directory); plug-in ABI untouched - PASS |
| III Incremental modernization | a small, local change with a tested header rule - PASS |
| IV Windows commitment | n/a - PASS |
| V Plugin architecture preservation | internal to uniso - PASS |
| VI UI consistency | no UI change - PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/401-uniso-share-length/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
├── probe/ (img401.py, iso401_probe.ps1, results)
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salisowalk.h            + SalIsoFolderVisitKey(start, length)
src/plugins/uniso/iso9660.h        Visited: std::set<unsigned long long>*, VisitedLog: std::vector<unsigned long long>*
src/plugins/uniso/iso9660.cpp      ListDirectory (fitVisited, visited), ListDirectoryRe (the key), CountUnder (countLog)
src/plugins/uniso/xdvdfs.cpp       VisitFolder uses SalIsoFolderVisitKey (same value as its inline formula)
src/saltests/saltests.cpp          TestIsoWalk401 (the key rule)
```

**Structure Decision**: the existing plug-in and its shared header; no new files in the source tree.

## Complexity Tracking

None.
