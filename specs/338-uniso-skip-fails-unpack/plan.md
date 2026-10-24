# Implementation Plan: ISO plug-in - a whole unpack with a skipped file keeps the image

**Branch**: `338-uniso-skip-fails-unpack` | **Date**: 2026-10-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/338-uniso-skip-fails-unpack/spec.md`

## Summary

`CPluginInterfaceForArchiver::UnpackWholeArchive` (uniso) succeeds unless the user cancels: `ExtractAllItems`
drops every per-file result but Cancel, the readers return "OK" for a silent read error, and a file written
over by a same-name record of the same unpack is never noticed. The change: (1) every reader reports a file
it did not write whole as not extracted (`SalIsoFileUnpackResult`); (2) `ExtractAllItems` keeps a tally -
any file not extracted whole, any folder not created, any file written over one this unpack wrote - and the
whole unpack fails on it (`SalIsoWholeUnpackSucceeded`); (3) files the unpack wrote are remembered by their
file-system identity (`CSalIsoWrittenFiles`, keys from `salsamefile.h`), checked when a target already
exists. Pure rules in the header-only `src/common/salisounpack.h` with saltests; probe `iso338_probe`.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: Win32 only; `src/common/salsamefile.h` (header-only identity), the plug-in's
`splunicode.h` (`SplU8ToWExtAlloc`)
**Storage**: N/A (nothing stored)
**Testing**: `saltests` (pure rules), hidden-desktop probe `probe/iso338_probe.ps1` (+ regressions of 330 / 337)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application - archive plug-in `uniso.spl`
**Performance Goals**: at most one attribute query per file and one identity read per written file (no
quadratic work: identities in hash sets)
**Constraints**: plug-in ABI unchanged; no UI string; header-only rules (uniso compiles no `src/common` .cpp)
**Scale/Scope**: images of up to hundreds of thousands of files

## Constitution Check

| Principle | Status |
|---|---|
| I. Build reproducibility | PASS - no new dependency; one new header |
| II. Backward compatibility | PASS - plug-in interface unchanged; intact images unpack and are deleted as before; only failed unpacks change their result |
| III. Incremental modernization | PASS - local changes at the five readers and the whole-unpack loop |
| IV. Windows commitment | PASS - Win32 identity API (`GetFileInformationByHandle[Ex]`) via `salsamefile.h` |
| V. Plug-in architecture | PASS - the core's rule (delete only after success) unchanged; the plug-in reports truthfully |
| VI. UI consistency | PASS - no dialog or text changes |

Post-design re-check: unchanged (PASS).

## Project Structure

### Documentation (this feature)

```text
specs/338-uniso-skip-fails-unpack/
├── plan.md, research.md, data-model.md, quickstart.md, fix-log.md
├── checklists/requirements.md
├── probe/ (iso338_probe.ps1, img338.py, mkimg338.sh, result_*.txt)
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salisounpack.h          # NEW: result codes, per-file result, whole-unpack decision, written-files set
src/plugins/uniso/isoimage.h       # static_asserts UNPACK_* == SAL_ISO_UNPACK_*; ExtractAllItems tally parameter
src/plugins/uniso/isoimage.cpp     # ExtractAllItems: tally of results, UnpackDir result, twin check
src/plugins/uniso/uniso.cpp        # UnpackWholeArchive: success only by SalIsoWholeUnpackSucceeded
src/plugins/uniso/iso9660.cpp      # UnpackFile: SalIsoFileUnpackResult(ret, bFileComplete)
src/plugins/uniso/rawfs.cpp        # same
src/plugins/uniso/udf.cpp          # same
src/plugins/uniso/xdvdfs.cpp       # same
src/plugins/uniso/hfs.cpp          # same + extents shorter than the size + a listed record that is not a file
src/saltests/saltests.cpp          # TestIsoWholeUnpack_338
```

**Structure Decision**: plug-in-local change plus one header-only rule file shared with saltests (the
project's pattern since 052 / 115).

## Complexity Tracking

None.
