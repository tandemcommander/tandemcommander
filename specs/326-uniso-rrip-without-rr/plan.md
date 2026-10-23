# Implementation Plan: The ISO plug-in reads Rock Ridge names of images that carry no `RR` entry

**Branch**: `326-uniso-rrip-without-rr` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/326-uniso-rrip-without-rr/spec.md`

## Summary

`CISO9660::ExtractExtFileName` reads a record's Rock Ridge name only when the record's first System
Use entry is `RR`; xorriso (RRIP 1.12) never writes `RR`, so its images list the plain ISO 9660
names. The fix recognises SUSP on the volume by the `SP` entry of the root directory's first record
(read once in `CISO9660::Open`) and, on such a volume, reads the `NM` entries of every record
(after LEN_SKP). A record starting with `RR` keeps working on every volume. The decisions (is this
an `SP` entry / where does a record's entry parsing start / the root record's System Use area) go
into a header-only rule `src/common/salsusp.h` with `saltests` checks; the GUI proof is a new
hidden-desktop probe on xorriso images and on a patched image that carries `RR` but no `SP`.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: none new; the ISO plug-in (`src/plugins/uniso`), header-only rule in `src/common`  
**Storage**: N/A (reads disk images)  
**Testing**: `saltests` (pure rule), hidden-desktop GUI probe (`specs/326-*/probe/iso326_probe.ps1`), feature 322's probe as regression  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (`.spl`)  
**Performance Goals**: one extra sector read per volume open (the root directory's first sector)  
**Constraints**: never read past a record or the sector read; never a cut name (feature 223); plug-in ABI untouched  
**Scale/Scope**: one source file of the plug-in (`iso9660.cpp` / `.h`), one new header, saltests

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency; header-only rule; `build.cmd` unchanged |
| II Backward compatibility | images with `RR`, plain ISO 9660, Joliet, UDF, HFS+ keep their behaviour (FR-003/004, probe rows) |
| III Incremental modernization | small local change in the reader; a pure rule extracted with tests |
| IV Windows commitment | n/a |
| V Plugin architecture preservation | no plug-in interface change; `LAST_VERSION_OF_SALAMANDER` untouched |
| VI UI consistency | no UI string, dialog or menu change - no `.slt` refresh |

Gate: PASS (before and after design).

## Project Structure

### Documentation (this feature)

```text
specs/326-uniso-rrip-without-rr/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/salsusp.md      # the pure rule's contract
├── probe/iso326_probe.ps1, probe/mkimg326.sh, probe/result_*.txt
├── fix-log.md, closing-report.md
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salsusp.h              # NEW: SUSP SP detection, record entry start, root record SU area
src/plugins/uniso/iso9660.h       # CISO9660: SuspVolume, SuspSkip members
src/plugins/uniso/iso9660.cpp     # Open(): read the root's first record; ExtractExtFileName(): use the rule
src/saltests/saltests.cpp         # TestSusp326()
```

**Structure Decision**: the existing plug-in and saltests layout; the rule is header-only because
the plug-in cannot compile a `.cpp` of `src/common` (CLAUDE.md, shared engines), as `salhfscatalog.h`
(feature 322).

## Complexity Tracking

None.
