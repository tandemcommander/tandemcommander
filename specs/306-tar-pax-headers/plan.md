# Implementation Plan: The tar plug-in applies PAX extended headers

**Branch**: `306-tar-pax-headers` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/306-tar-pax-headers/spec.md`

## Summary

The tar plug-in's header reader (`CArchive::ReadTarHeader`, `src/plugins/tar/untar.cpp`) skips
`x` / `g` headers. It will read their data (bounded at 1 MiB) like a GNU long name, parse the
records with a new header-only rule file `src/common/salpaxheader.h`, keep the global values in
the `CArchive` object (reset at the first header of every pass) and the member's values for the
current header chain, and apply `path`, `size` and `mtime` to the member. A PAX path with a
component over 255 UTF-16 units is ignored as a member and reported once (listing, whole-archive
unpack) with the system's "file name too long" text and the path. `saltests` checks the parser.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; the plug-in's `SalamanderGeneral` services
**Storage**: N/A
**Testing**: `saltests` (pure rules), hidden-desktop probe `specs/306-tar-pax-headers/probe/pax306_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`tar.spl`; also serves .deb / .rpm payloads through the same reader)
**Performance Goals**: no measurable change; one extra heap buffer per extended header
**Constraints**: plug-in ABI unchanged; no new UI strings; header-only shared code (the plug-in cannot compile `src/common/*.cpp`)
**Scale/Scope**: one reader function, one header, one probe

## Constitution Check

| Principle | Status |
|---|---|
| I Build reproducibility | PASS - no new dependency, plain header |
| II Backward compatibility | PASS - archives without PAX headers take the unchanged code path (FR-008); plug-in ABI untouched |
| III Incremental modernization | PASS - a local change in the reader |
| IV Windows commitment | PASS |
| V Plugin architecture preservation | PASS - no interface change |
| VI UI consistency | PASS - existing message texts and box style |

Standing rules touched: names are UTF-8 (the PAX path is UTF-8 by the standard and passes the
plug-in's existing `ConvertNameToU8` boundary); a path is never cut (refusal, FR-006); pure
decisions in `src/common/` with `saltests` (FR-009). Post-design re-check: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/306-tar-pax-headers/
├── plan.md  research.md  data-model.md  quickstart.md  contracts/salpaxheader.md
├── fix-log.md  tasks.md  checklists/requirements.md
└── probe/   pax306_probe.ps1, mkpax306.py, result_*.txt
```

### Source Code (repository root)

```text
src/common/salpaxheader.h        new: record parser, value parsers, precedence, component check
src/plugins/tar/tar.h            SCommonHeader: MTimeFrac, NameFromPax; CArchive: GlobalPax, report flags
src/plugins/tar/untar.cpp        ReadTarHeader: x / g branch, apply values; ReadArchiveHeader: refusal,
                                 100-ns fraction; ListArchive / UnpackWholeArchive: report flag
src/saltests/saltests.cpp        TestPaxHeader306
```

**Structure Decision**: the existing plug-in and test projects; no project file changes beyond
what including a header needs (none - `untar.cpp` already includes `../../common/salmaskname.h`).

## Complexity Tracking

None.
