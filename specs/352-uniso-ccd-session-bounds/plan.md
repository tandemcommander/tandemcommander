# Implementation Plan: A damaged CloneCD .ccd never makes the ISO plug-in write or read outside its tables

**Branch**: `352-uniso-ccd-session-bounds` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/352-uniso-ccd-session-bounds/spec.md`

## Summary

`CISOImage::ReadSessionCCD` (`src/plugins/uniso/img.cpp`) indexes its four per-session tables
(`pointMin`, `pointMax`, `extents`, `extentsEnd`, one element per `[Session n]` section) with
`entry->Session - 1` unchecked (the session stored in a `BYTE`), loops over the `[Session n]` count
while reading the split list `Session[i]`, loops over the split list while reading `extents[i]`, and
the section parsers count a row whether its `sscanf` succeeded or not. Fix:

1. Pure rules in `src/common/salisotrack.h` (header-only, 351's header) with `saltests` checks:
   - `SalIsoCcdReadInt(value, hex, out)` - the reading `sscanf("%d" / "%x")` gave a valid value
     (leading blanks, a sign, `0x` for hex, then digits; trailing text ignored), but "no number" and
     a value outside 32 bits fail;
   - `CSalIsoCcdFields` - a section's needed rows: each must appear once and parse;
   - `SalIsoCcdSessionIndex(session, sections)` - the table row of an entry's session, -1 outside
     1..sections;
   - `SalIsoCcdSplitSection(split, sections)` - the table row of a track split, -1 when the `.ccd`
     has fewer sections; `SalIsoCcdLayoutTrusted(sections, splits)` - they agree.
2. `img.cpp`: the three section parsers use the rules (FR-002); `CCDEntry::Session` becomes `int`;
   `CCD` gets a `Refused` flag set wherever the `.ccd` is refused with `IDS_CCD_BAD_FORMAT`;
   `ReadSessionCCD` checks every entry's session before building anything (FR-001, refused), runs
   the sector-format loop over the split list, takes a split's extents only from an existing table
   row (else 0), marks `ListingLeftOut` incomplete when the layout is not trusted (FR-004) and when
   the `.ccd` was refused (FR-003). A missing `.ccd` is not `Refused` (FR-006).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: none new  
**Storage**: N/A  
**Testing**: `saltests` (`TestIsoCcdBounds_352`); hidden-desktop probe `probe/iso352_probe.ps1`
(images by `probe/img352.py` from 334's `mkimg334.sh` seeds), Debug; regressions: the probes of
351 and 334  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (uniso)  
**Performance Goals**: N/A  
**Constraints**: plug-in ABI unchanged; header-only rule without CRT dependencies (uniso includes
`src/common` headers as `../../common/...`); no UI string (the existing `IDS_CCD_BAD_FORMAT` text)  
**Scale/Scope**: one reader file, one header, one test function

## Constitution Check

| Principle | Status |
|---|---|
| I. Build reproducibility | No new dependency. PASS |
| II. Backward compatibility | A valid `.ccd` is read as before (FR-005; C-M1, C-M1M1, 351's probe). PASS |
| III. Incremental modernization | Bounds and parse rules as a pure header with tests. PASS |
| IV. Windows commitment | Unchanged. PASS |
| V. Plugin architecture | No change to `spl_*.h`, no ABI change. PASS |
| VI. UI consistency | No new text, dialog or menu - no `.slt` refresh. PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/352-uniso-ccd-session-bounds/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
├── checklists/requirements.md
└── probe/ (iso352_probe.ps1, img352.py, result_*.txt)
```

### Source Code (repository root)

```text
src/common/salisotrack.h       # + SalIsoCcdReadInt, CSalIsoCcdFields, SalIsoCcdSessionIndex,
                               #   SalIsoCcdSplitSection, SalIsoCcdLayoutTrusted
src/plugins/uniso/img.cpp      # parsers, CCD::Refused, ReadSessionCCD bounds and marks
src/saltests/saltests.cpp      # TestIsoCcdBounds_352
```

**Structure Decision**: the existing uniso plug-in and its existing rule header.

## Complexity Tracking

None.
