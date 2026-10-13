# Implementation Plan: From a server name to its shared folders

**Branch**: `125-unc-server-shares` (from `124-regedt-key-text`) | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)
**Input**: GitHub issue #5 (`issues/issue_5.md`)

## Summary

`\\server\` in Change Directory ends in "A share name is missing" because the core gives an
incomplete UNC path only to a Network plug-in and none ships. The core gets a fallback for
exactly that branch: it reads the server's folder shares on a worker thread (cancellable wait
window), offers them in a popup menu under the directory line, and continues the ordinary path
change with `\\server\<chosen share>`. The plug-in policy (`nethood=off`) is not touched; what
enabling the plug-in would need is recorded for the maintainer.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: Win32 `NetShareEnum` / `NetApiBufferFree` (netapi32 - already linked for `CShares`), `WNetOpenEnumW` / `WNetEnumResourceW` (mpr - already linked); the core's `CMenuPopup`, safe wait window, `SalNameCompareOrdinalCI`
**Storage**: none
**Testing**: `saltests` for the pure rules (`src/common/saluncserver.h`); GUI probe on the hidden desktop `probe/unc_probe.ps1` (before / after / with the plug-in / close while open), owner-drawn menu read by capture + text recognition; `tools/check_encoding.py`; Release string search for the seam names
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core)
**Performance Goals**: the main thread never blocks on the network: quiet for 400 ms, then a cancellable wait window
**Constraints**: no new or changed string; plug-in interface untouched; a name is never cut; `PRIVACY.md` in the same change; nothing terminated by force
**Scale/Scope**: 1 new header, about 250 lines in 4 core files, about 60 saltests checks

## Constitution Check

| Principle | Verdict |
|-----------|---------|
| I. Build reproducibility | PASS - no new dependency, project or build step (the header is included, no new `.cpp`) |
| II. Backward compatibility | PASS - no configuration or format change; behaviour changes only where an error box was the only outcome |
| III. Incremental modernization | PASS - new code follows the current rules (UTF-8, ordinal name order, refuse instead of cut) |
| IV. Windows commitment | PASS - Win32 networking API only |
| V. Plugin architecture preservation | PASS - a Network plug-in, when present, keeps priority; the interface is untouched |
| VI. UI consistency | PASS - the list is the same menu, in the same place, as the directory history; existing texts |

Re-checked after design: unchanged.

## Stages

| Stage | Content |
|---|---|
| S0 measure | done: `probe/unc_measure_v019.txt`, `probe/unc_measure_with_nethood_plugin.txt`; plug-in audit (research R2) |
| S1 rules | `src/common/saluncserver.h`: `SalUncServerOfPath`, `SalUncShareOffered`, `SalUncShareHidden`, `SalUncShareCompare`, `SalUncBuildSharePath`, `SalUncMenuText`; saltests `TestUncServer125` |
| S2 reading | `src/shares.cpp` + `src/salamand.h`: `CUncSharesJob` (reference-counted), `StartUncSharesJob`, the worker (NetShareEnum, WNet fallback, Debug seam) |
| S3 the choice | `src/fileswnb.cpp` + `src/fileswnd.h`: `CFilesWindow::PickServerShare` - wait with the safe wait window, menu under the directory line, result codes |
| S4 integration | `src/fileswn3.cpp` `ChangeDir`: the fallback in the incomplete-UNC branch |
| S5 claims | `PRIVACY.md` bullet; `CHANGELOG.md`; `specs/NEXT-WORK.md` (the plug-in decision with its price) |
| S6 tests and gates | saltests; Debug + Release builds; encoding guard; Release string search for `TC_PROBE_UNC`; probe rows on the fixed build, on 0.1.9 and on a build with the plug-in; independent review; records |

## Project Structure

```text
src/common/saluncserver.h   # new, header-only pure rules
src/shares.cpp              # CUncSharesJob + worker (next to CShares, which already uses NetShareEnum)
src/salamand.h              # declarations
src/fileswnb.cpp            # CFilesWindow::PickServerShare (next to OpenDirHistory)
src/fileswnd.h              # declaration
src/fileswn3.cpp            # ChangeDir: the fallback branch
src/saltests/saltests.cpp   # TestUncServer125
PRIVACY.md, CHANGELOG.md, specs/NEXT-WORK.md, specs/FEATURE-HISTORY.md

specs/125-unc-server-shares/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
├── contracts/probe-seam.md
└── probe/   # unc_probe.ps1, measurements, results, shots/
```

**Structure Decision**: no new translation unit (nothing to add to `salamand.vcxproj`); the
rules are a header so that `saltests` compiles them.

## Complexity Tracking

No violations.
