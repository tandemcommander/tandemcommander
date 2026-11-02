# Implementation Plan: A cpio or rpm member whose name the panel cannot hold is refused alone

**Branch**: `393-cpio-long-name` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/393-cpio-long-name/spec.md`

## Summary

Cpio member names (every cpio format, and the rpm payload) get the refusal PAX paths and GNU long
names have had since features 306 / 308 / 321: the shared decision `SalPaxNameUsableU8` in
`CArchive::ReadArchiveHeader`, with a cpio folder known by its mode (research R2). A refused name
that carries a hard-linked file's data stays in its link group as "not asked", so the other names
still get the data (R3). No UI strings, no plug-in interface change.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: none new; `src/common/salpaxheader.h` (header-only, saltests)  
**Storage**: N/A  
**Testing**: `saltests` (unchanged rule), hidden-desktop GUI probe `probe/cpio393_probe.ps1`  
**Target Platform**: Windows 11+ x64  
**Project Type**: desktop application, TAR plug-in (`src/plugins/tar/untar.cpp`)  
**Performance Goals**: N/A (one check per header, as for tar)  
**Constraints**: refusal only in the listing pass for depth (308); never cut a name (CLAUDE.md)  
**Scale/Scope**: about 15 lines in one file

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency; vendored only - PASS |
| II Backward compatibility | archives that opened still open (names that fit unchanged); archives that failed whole now open - PASS |
| III Incremental modernization | reuses the shared rule, no rewrite - PASS |
| IV Windows commitment | unchanged - PASS |
| V Plugin architecture | no interface change (`spl_*.h` untouched) - PASS |
| VI UI consistency | the same "(206)" message as tar members; no new strings - PASS |

Post-design re-check: unchanged - PASS.

## Project Structure

### Documentation (this feature)

```text
specs/393-cpio-long-name/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/ (cpio393_probe.ps1, mkcpio393.py, result_*.txt, regress_*.txt)
```

No `contracts/`: nothing exposed to plug-ins or other programs changes.

### Source Code

```text
src/plugins/tar/untar.cpp   # ReadArchiveHeader (refusal for cpio, isDir from mode),
                            # IsCpioGroupMember, DoUnpackArchive (refused = not asked for the group)
```

**Structure Decision**: one plug-in source file; the rule stays in `src/common/salpaxheader.h`.

## Complexity Tracking

None.
