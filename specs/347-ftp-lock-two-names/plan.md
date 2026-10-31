# Implementation Plan: FTP opened-file lock across two names of one server

**Branch**: `347-ftp-lock-two-names` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/347-ftp-lock-two-names/spec.md`

## Summary

The FTP plug-in's opened-file lock (`CFTPOpenedFiles`, `src/plugins/ftp/operats9.cpp`) decides
"the same server file" in `CFTPOpenedFile::IsSameFile` with the host name compared by
`StrICmp`. Two names of one server (`localhost` / `127.0.0.1`) are two lock owners, so two uploads
store one file at once (measured: probe row ALIAS-LOCK). The fix drops the host term from
`IsSameFile`: same user (exact), same port, same path (server type's rule) and same name (server
type's case rule) = maybe the same file, under any host name - feature 341's "maybe the same
server" rule applied to the lock. The conflict table (`IsInConflictWith`) and every caller's
answer to a refusal stay as they are.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: Salamander plug-in API (`SalamanderGeneral`), FTP plug-in internals
**Storage**: none (in-memory lock list per program instance)
**Testing**: GUI probe on the hidden desktop (`probe/ftp347_probe.ps1` + `probe/ftpmini_hold.py`);
regressions: 341's `ftp341_probe.ps1`, 345's `ftp345_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`.spl`)
**Performance Goals**: unchanged (one comparison less per lock entry)
**Constraints**: no UI text, no stored data, no network change, no plug-in ABI change
**Scale/Scope**: one function in one file (+ comment in `operats.h`)

## Constitution Check

| Principle | Status |
|---|---|
| I. Build reproducibility | PASS - no build change |
| II. Backward compatibility | PASS - no stored data, no ABI; a behaviour change only where two operations could lose a file |
| III. Incremental modernization | PASS - minimal change at one site |
| IV. Windows commitment | PASS |
| V. Plug-in architecture | PASS - plug-in internal; `spl_*.h` untouched |
| VI. UI consistency | PASS - the existing "in use" answers are reused |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/347-ftp-lock-two-names/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/  ftp347_probe.ps1, ftpmini_hold.py, result_*.txt
```

### Source Code (repository root)

```text
src/plugins/ftp/operats9.cpp   CFTPOpenedFile::IsSameFile - drop the host term, comment why
src/plugins/ftp/operats.h      the CFTPOpenedFile / IsSameFile comments - identity without the host
```

**Structure Decision**: plug-in internal change; no new files in `src/`. No `src/common/` header:
the decision is one term of a comparison that needs the plug-in's own path rule
(`FTPIsTheSameServerPath`), and the hidden-desktop probe tests it end to end.

## Complexity Tracking

None.
