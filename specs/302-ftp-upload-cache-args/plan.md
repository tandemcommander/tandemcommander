# Implementation Plan: FTP panel Create Directory and Quick Rename update the upload listing cache

**Branch**: `302-ftp-upload-cache-args` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/302-ftp-upload-cache-args/spec.md`

## Summary

`CControlConnectionSocket::CreateDir` and `::QuickRename` (`src/plugins/ftp/ctrlcon5.cpp`) report
their change to `UploadListingCache` with `(hostBuf, userBuffer, portBuf, ...)`, but
`CUploadListingCache::ReportCreateDirs` / `ReportRename` take `(user, host, port, ...)`; the
cache's `FindServer` then finds no server and the report is dropped. The fix passes
`(userBuffer, hostBuf, portBuf, ...)` at the four calls. A hidden-desktop probe with 215's
`ftpmini.py` shows the visible case (F7 with an absolute path outside the panel folder while an
upload is open: the next upload sends `MKD` for an existing folder) before / after, and keeps the
item's rename row (before the fix the uploaded `b.txt` replaced the renamed file without the question).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; FTP plug-in (`src/plugins/ftp`)
**Storage**: N/A (in-memory cache only, lives while an upload operation exists)
**Testing**: hidden-desktop GUI probe (`specs/302-ftp-upload-cache-args/probe/`), 215's
`ftpmini.py` test server; existing FTP probes 224 / 277 / 288 as regressions. No `saltests`
rule: the defect is the argument order at four call sites inside the plug-in, not a pure decision
(the cache's lookup itself is unchanged and lives in the plug-in, which `saltests` does not link).
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (plug-in DLL `ftp.spl`)
**Performance Goals**: N/A
**Constraints**: no change to the plug-in interface, UI strings, stored data or network traffic
other than the corrected one (an upload no longer sends a needless `MKD`)
**Scale/Scope**: 4 call sites in one file

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency, no build change - PASS |
| II. Backward compatibility | no ABI, registry, configuration or file-format change - PASS |
| III. Incremental modernization | a minimal fix at the defective sites - PASS |
| IV. Windows commitment | unchanged - PASS |
| V. Plug-in architecture | the plug-in interface is untouched (internal FTP plug-in class) - PASS |
| VI. UI consistency | no UI change - PASS |

CLAUDE.md standing rules touched: none of the text / name / path rules (names and paths are
passed through unchanged); *Never lose the user's data* - the fix makes the upload's existence
check more accurate (no new overwrite path). Post-design re-check: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/302-ftp-upload-cache-args/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
├── checklists/requirements.md
├── probe/ftp302_probe.ps1 (+ result_*.txt)
└── tasks.md
```

No `contracts/`: nothing external changes (internal class of the FTP plug-in).

### Source Code (repository root)

```text
src/plugins/ftp/ctrlcon5.cpp   # CreateDir: 2 calls of ReportCreateDirs; QuickRename: 2 calls of ReportRename
```

**Structure Decision**: one source file of the FTP plug-in; the probe reuses
`specs/098-long-path-overruns/probe/fix_probe_lib.ps1` and
`specs/215-ftp-long-name-command/probe/ftpmini.py` like `ftp288_probe.ps1`.

## Complexity Tracking

None.
