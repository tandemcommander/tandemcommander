# Implementation Plan: the external unpacker's walk and the temporary-folder cleanups never go through a link

**Branch**: `249-temp-walks-junctions` | **Date**: 2026-10-19 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/249-temp-walks-junctions/spec.md` (backlog item `temp-dir-walks-follow-junctions`)

## Summary

`PackUniversalUncompress` (`src/pack1.cpp`) locates the extracted subfolder of the archive path by
taking the first directory it finds at every level of its temporary folder - a junction too - and
then moves that folder's content into the target (measured: a junction's target emptied into the
target, probe row UNPACK FAIL). The walk now asks, for every directory it would enter, feature 197's
link decision `DeleteAsDirLink` (fail closed; cloud placeholders are folders); a link refuses the
whole unpack before anything is moved: `IDS_PACKERR_GENERAL` ("System error: %1") with
`<path>: <system text of ERROR_REPARSE_POINT_ENCOUNTERED>`, the temporary folder removed by 212's
`RemoveTemporaryDir` (the link as a link), `FALSE` to the caller. The self-extractor's own
`_RemoveTemporaryDir` (`selfextr.cpp`, not built) removes a reparse directory as an entry instead of
walking it (source fix, syntax-checked). Feature 212's start-up sweep is driven by the probe (row
SWEEP).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143; the self-extractor is legacy C++ with ANSI calls
**Primary Dependencies**: WinAPI only; core facade `SalFindFirstFile` / `SalConvertFindDataW`, `DeleteAsDirLink` (`consts.h`, feature 197), `RemoveTemporaryDir` (`salamdr3.cpp`, feature 212)
**Storage**: N/A (no registry or stored-data change)
**Testing**: hidden-desktop GUI probe `probe/tempjunction249_probe.ps1` (rows SWEEP, PLAIN, UNPACK); `saltests` unchanged (the decision used is `SalDeleteAsDirLinkDecision`, already checked)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `tandemcommander.exe`)
**Performance Goals**: one attribute / reparse-tag read per archive-path level (only for directories carrying a reparse point)
**Constraints**: no new UI strings (the `.slt` refresh is not done by a run); UTF-8 paths; never cut a path (the message is composed on the heap)
**Scale/Scope**: one function in `src/pack1.cpp`, one in `src/plugins/zip/selfextr/selfextr.cpp`

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no build change; `build.cmd` as before |
| II Backward compatibility | every archive without a link on the archive path unpacks as before (row PLAIN); no config or ABI change |
| III Incremental modernization | a local guard reusing 197's decision; no rewrite |
| IV Windows commitment | WinAPI reparse attributes |
| V Plugin architecture | no plug-in interface change (`selfextr.cpp` is not a plug-in module and is not built) |
| VI UI consistency | an existing message (`IDS_PACKERR_GENERAL`) through the archivers' error handler |

Gate: PASS (no violations). Re-checked after design: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/249-temp-walks-junctions/
├── spec.md, plan.md, research.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md (at the end)
├── checklists/requirements.md
└── probe/tempjunction249_probe.ps1, result_before.txt, result_after.txt
```

### Source Code (repository root)

```text
src/pack1.cpp                              PackUniversalUncompress: the archive-path walk refuses a link
src/plugins/zip/selfextr/selfextr.cpp      _RemoveTemporaryDir: a reparse directory removed, not walked
```

**Structure Decision**: the two existing functions only; no new header (the pure decision is
`SalDeleteAsDirLinkDecision` in `src/common/salreparse.h`, already under `saltests`). No data
model or external contract changes - `data-model.md` and `contracts/` are not produced.

## Complexity Tracking

None.
