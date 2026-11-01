# Implementation Plan: The Documents folder is opened whole, never cut

**Branch**: `386-mydocs-path-whole` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/386-mydocs-path-whole/spec.md`

## Summary

`GetMyDocumentsOrDesktopPath` (`src/shellib.cpp`) cuts the Documents path to the caller's buffer.
The rule "whole path or refused; a too-long Documents is not replaced by the Desktop" moves into a
header-only rule `src/common/salmydocs.h` (`SalDocumentsOrDesktopToU8`, saltests checks); the
helper reads the two folders wide and hands them to the rule, without the 520-byte intermediate
buffer. The long-path capable callers (drive bar / Alt+F1/F2 Documents, Ctrl+;, the wide File
Open / Save fallbacks) get buffers of `SAL_MAX_PATH_UTF8`; the rescue path keeps `MAX_PATH` and
its existing fallback. A Debug-only seam `TC_PROBE_MYDOCS_PATH` lets a hidden-desktop probe name
the Documents folder; it is committed before the fix so the probe measures the defect first.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI (shell `SHGetSpecialFolderLocation`, `SHGetPathFromIDListW`)
**Storage**: N/A (no registry change; the probe seam is an environment variable, Debug only)
**Testing**: `saltests` (rule header), hidden-desktop GUI probe `mydocs386_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand`)
**Performance Goals**: N/A (one shell query per user action, as today)
**Constraints**: a path is never cut (CLAUDE.md); plug-in interface unchanged; no UI strings
**Scale/Scope**: 1 helper, 5 call sites changed, 1 new header, 1 probe

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency, header-only rule; PASS |
| II Backward compatibility | short Documents paths behave as before; the plug-in value `SALCFG_IFPATHISINACCESSIBLEGOTO` keeps its size; PASS |
| III Incremental modernization | local change of one helper and its callers; PASS |
| IV Windows commitment | WinAPI only; PASS |
| V Plug-in architecture | no `spl_*.h` change; PASS |
| VI UI consistency | no new UI; PASS |

Re-check after design: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/386-mydocs-path-whole/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/salmydocs.md      # the rule header and the probe seam
├── probe/mydocs386_probe.ps1   # hidden-desktop probe
├── fix-log.md
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salmydocs.h          # new: SalDocumentsOrDesktopToU8 (rule)
src/shellib.cpp                 # GetMyDocumentsOrDesktopPath uses the rule; Debug seam
src/fileswn0.cpp                # Ctrl+; buffer SAL_MAX_PATH_UTF8
src/fileswn3.cpp                # ChangePathToDrvType buffer SAL_MAX_PATH_UTF8
src/salamdr6.cpp                # SafeGetSaveFileNameW / SafeGetOpenFileNameW initDir SAL_MAX_PATH_UTF8
src/saltests/saltests.cpp       # TestDocumentsPath386
```

**Structure Decision**: core only; the rule header lives in `src/common/` next to the other
"whole or refused" rules (`salsubst.h`, `salshelllink.h`).

## Complexity Tracking

None.
