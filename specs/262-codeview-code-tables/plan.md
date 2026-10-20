# Implementation Plan: Code Viewer decodes single-byte files with the product's conversion tables

**Branch**: `262-codeview-code-tables` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/262-codeview-code-tables/spec.md`

## Summary

The Code Viewer gets the built-in viewer's conversion tables: its Encoding menu appends every table
`EnumConversionTables` hands out (five existing entries first), choosing one re-decodes the open file
(bytes through the 256-byte table, then the system code page - what the built-in viewer draws), the
status bar names it, F8 / Shift+F8 cycle through the whole list, and the chosen table's name is kept
in the plug-in's settings (`DefaultConvert`) and applied to later single-byte files. The pure parts
(table pass, display name, cycling, menu-id mapping, which table a file gets) go into a header-only
rule `src/common/salcodetable.h` checked by `saltests`, including the real CP852 -> CP1250 table on
the corpus line.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI; the plug-in services `EnumConversionTables`,
`CSalamanderRegistryAbstract` (both existing, unchanged)
**Storage**: one REG_SZ value `DefaultConvert` under the codeview plug-in's own settings key, stored
as UTF-8 (the registry facade is UTF-8, feature 004/066); empty = system code page
**Testing**: `saltests` (header rule), codeview `run_tests.cmd` (unchanged web harness), build;
GUI rows on the hidden desktop only if a probe can read the decoded text - see research R6
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, plug-in
**Performance Goals**: one extra pass over at most `ViewerLimitMB` bytes (default 20 MB) - linear,
in place over the read buffer, no extra copy
**Constraints**: no plug-in ABI change, no new UI strings, no core change, files decoding correctly
today unchanged with no remembered table
**Scale/Scope**: `src/common/salcodetable.h` (new), `src/saltests/saltests.cpp`,
`src/plugins/codeview/{intake.h,intake.cpp,viewer.h,viewer.cpp,config.cpp,codeview.h,codeview.cpp}`

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I Build reproducibility | no new dependency, vendored nothing, header-only rule | PASS |
| II Backward compatibility | default (no stored name) = today's decode; new registry value only added, older builds ignore it; five menu entries keep their ids 4000-4004 | PASS |
| III Incremental modernization | uses the existing plug-in services as they are (B-5 decision untouched) | PASS |
| IV Windows commitment | WinAPI only | PASS |
| V Plug-in architecture | no change to `spl_*.h`, `LAST_VERSION_OF_SALAMANDER` | PASS |
| VI UI consistency | the same list, order and separators as the built-in viewer's Convert menu; no new strings | PASS |

Re-check after Phase 1: PASS (design adds no interface, no string, no core change).

## Project Structure

### Documentation (this feature)

```text
specs/262-codeview-code-tables/
├── plan.md  research.md  data-model.md  quickstart.md
├── contracts/encoding-menu.md
├── fix-log.md  (running log)
└── tasks.md   (speckit-tasks)
```

### Source Code (repository root)

```text
src/common/salcodetable.h          new: header-only rule (table pass, display name, cycle, menu ids, table choice)
src/saltests/saltests.cpp          TestCodeTable262()
src/plugins/codeview/intake.h/.cpp CvLoadFile(..., const char* ansiTable, ...) applies the table to a single-byte result
src/plugins/codeview/viewer.h/.cpp table list per window, menu, status bar, select / cycle, remembering
src/plugins/codeview/codeview.h/.cpp remembered name + its critical section (any viewer thread)
src/plugins/codeview/config.cpp    load / save DefaultConvert (UTF-8 <-> code-page bytes)
```

**Structure Decision**: plug-in change plus one shared header-only rule, the project's pattern for
pure decisions in plug-ins (CLAUDE.md: header-only for projects that cannot compile `src/common` .cpp).

## Complexity Tracking

No violations.
