# Implementation Plan: FTP opened-file lock across two users or ports of one server

**Branch**: `348-ftp-lock-user-port` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/348-ftp-lock-user-port/spec.md`

## Summary

The FTP plug-in's opened-file lock (`CFTPOpenedFiles`, `src/plugins/ftp/operats9.cpp`) decides
"the same server file" in `CFTPOpenedFile::IsSameFile`. Since feature 347 the host is not
compared, but the user (`strcmp`) and the port still are, so two accounts sharing a folder or two
ports of one server are two lock owners and two uploads store one file at once (measured: probe
rows OTHER-USER, OTHER-PORT, ALL-OTHER). The fix drops the user and port terms: the same path
(server type's rule) and the same name (server type's case rule) = maybe the same file, on any
connection - feature 345's "every other connection is maybe the same server" rule applied to the
lock. The conflict table (`IsInConflictWith`) and every caller's answer to a refusal stay as they
are; the parameters stay (no caller changes).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: Salamander plug-in API (`SalamanderGeneral`), FTP plug-in internals
**Storage**: none (in-memory lock list per program instance)
**Testing**: GUI probe on the hidden desktop (`probe/ftp348_probe.ps1` + `probe/ftpmini_hold2.py`,
one server on two ports); regressions: 341's `ftp341_probe.ps1`, 345's `ftp345_probe.ps1`, 347's
`ftp347_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`.spl`)
**Performance Goals**: unchanged (two comparisons less per lock entry)
**Constraints**: no UI text, no stored data, no network change, no plug-in ABI change
**Scale/Scope**: one function in one file (+ comments in `operats.h`)

## Constitution Check

| Principle | Status |
|---|---|
| I. Build reproducibility | PASS - no build change |
| II. Backward compatibility | PASS - no stored data, no ABI; a behaviour change only where two operations could lose a file (a conflicting access is refused, retryable) |
| III. Incremental modernization | PASS - minimal change at one site |
| IV. Windows commitment | PASS |
| V. Plug-in architecture | PASS - plug-in internal; `spl_*.h` untouched |
| VI. UI consistency | PASS - the existing "in use" answers are reused |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/348-ftp-lock-user-port/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/  ftp348_probe.ps1, ftpmini_hold2.py, result_*.txt, regress_*.txt
```

### Source Code (repository root)

```text
src/plugins/ftp/operats9.cpp   CFTPOpenedFile::IsSameFile - drop the user and port terms, comment why
src/plugins/ftp/operats.h      the CFTPOpenedFile fields / IsSameFile comment - identity = path + name
```

**Structure Decision**: plug-in internal change; no new files in `src/`. No `src/common/` header:
the decision is the removal of two terms of a comparison that needs the plug-in's own path rule
(`FTPIsTheSameServerPath`), and the hidden-desktop probe tests it end to end (as 347).

## Complexity Tracking

None.
