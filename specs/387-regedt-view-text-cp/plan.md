# Implementation Plan: Registry Editor View of a text value keeps the whole text on a multi-byte code page

**Branch**: `387-regedt-view-text-cp` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/387-regedt-view-text-cp/spec.md`

## Summary

`ExportValueData` (`src/plugins/regedt/fs3.cpp`) converts a text value for the viewer into a
space of one byte per UTF-16 unit and writes that many bytes. A new header-only rule
`SalRegViewTextToCodePageAlloc` in `src/common/salregfind.h` counts the code-page bytes of all
units (reusing `SalRegFindTextToCodePage`, feature 278), allocates exactly that, converts whole,
and returns the byte count - or tells the caller to write the UTF-16 data unchanged (conversion
impossible / nothing to convert) or that memory is low. `ExportValueData` writes the returned
bytes and count; the short-write check becomes `WriteFile(...) && written == size`.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: Win32 (`WideCharToMultiByte`, registry, file API); none new
**Storage**: the viewer's temporary file in the core's disk cache (unchanged)
**Testing**: `saltests` (`src/saltests/saltests.cpp`) with explicit code pages 65001 / 932 / 1250
**Target Platform**: Windows 11+, x64
**Project Type**: plug-in of a desktop application (`regedt.spl`)
**Performance Goals**: one extra `WideCharToMultiByte` sizing call per F3 - negligible
**Constraints**: header-only rule (plug-ins cannot compile a `.cpp` from `src/common`); no new UI
string; single-byte code pages must give byte-identical output
**Scale/Scope**: one function in one plug-in, one header rule, one test function

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency, no build change - PASS |
| II Backward compatibility (0.1.0) | the viewer copy on single-byte code pages is byte-identical; the switch keeps its meaning; no ABI change - PASS |
| III Incremental modernization | a local fix with a tested pure rule - PASS |
| IV Windows commitment | Win32 only - PASS |
| V Plug-in architecture preservation | no change to `spl_*.h` or `LAST_VERSION_OF_SALAMANDER` - PASS |
| VI UI consistency | no UI text or dialog changes; existing error messages reused - PASS |

Standing rules touched: "a path or name is never cut / refuse" (the text is converted whole or
not at all, never partially); `LoadStr` code page (not touched); encoding guard
(`WideCharToMultiByte(CP_ACP, ...)` of a registry *value* for the viewer's code-page export is
the switch's documented purpose, already present - check `tools/check_encoding.py --strict`).

Post-design re-check: unchanged - PASS.

## Project Structure

### Documentation (this feature)

```text
specs/387-regedt-view-text-cp/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/requirements.md
├── fix-log.md
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salregfind.h          # + SalRegViewTextToCodePageAlloc (header-only rule)
src/plugins/regedt/fs3.cpp       # ExportValueData uses it; write-length check
src/saltests/saltests.cpp        # + TestRegViewTextToCodePage387
```

**Structure Decision**: the rule joins `salregfind.h` because it reuses
`SalRegFindTextToCodePage` and the header is already included by `regedt`'s `precomp.h` and by
`saltests`.

## Complexity Tracking

None.
