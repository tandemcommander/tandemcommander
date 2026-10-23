# Implementation Plan: Unpack never drops the leading space of a relative target

**Branch**: `316-unpack-subdir-space` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/316-unpack-subdir-space/spec.md`

## Summary

`CFilesWindow::Unpack` (`src/fileswn7.cpp`) turns the dialog's target into a full path with
`SalGetFullName(path, &errTextID, curDir, nextFocus)`. `SalGetFullName` (`src/salamdr3.cpp`) skips
the characters <= ' ' at the start of the name and, for a relative name, joins `curDir` with the
name **from after those characters** unless its last parameter `allowRelPathWithSpaces` is TRUE.
Unpack leaves it at the default FALSE, so ` ssss` became `<archive folder>\ssss`.

The fix: pass `allowRelPathWithSpaces = TRUE` (with the existing default `nameBufSize = MAX_PATH`,
the size of Unpack's `path` buffer). The joined path then names ` ssss`; the following
`CheckAndCreateDirectory(path, NULL, TRUE, NULL, 0, newDir, FALSE, TRUE)` - `manualCrDir = TRUE` -
already refuses to create a component that starts with a space (ERROR_INVALID_NAME, "Error Creating
Directory", the dialog again), and an existing ` ssss` folder is used as it is (the attributes check
returns before any creation). `SalParsePath` (Copy/Move) already passes TRUE for disk/archive
panels - the same convention.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI only
**Storage**: N/A (no settings change)
**Testing**: hidden-desktop GUI probe `specs/316-unpack-subdir-space/probe/unpack316_probe.ps1`
(098's library, 315's driver); 315's probe as a regression; `saltests` run (no new pure rule)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (two-panel file manager)
**Performance Goals**: N/A
**Constraints**: no new UI string (the `.slt` refresh is not done by a run); no plug-in ABI change
**Scale/Scope**: one call site, one argument

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no build change - PASS |
| II. Backward compatibility | settings, registry, plug-in ABI untouched; a relative target without leading spaces, an absolute target and an empty target behave as before - PASS |
| III. Incremental modernization | a one-argument fix at the defective call site - PASS |
| IV. Windows commitment | WinAPI only - PASS |
| V. Plug-in architecture | `CSalamanderGeneral::SalGetFullName` (plug-ins) unchanged - PASS |
| VI. UI consistency | existing messages only; the same refusal as the absolute entry - PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/316-unpack-subdir-space/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
├── probe/unpack316_probe.ps1 (+ result_*.txt)
└── tasks.md
```

### Source Code (repository root)

```text
src/fileswn7.cpp     CFilesWindow::Unpack - the SalGetFullName call after CUnpackDialog
```

No other source file changes. `SalGetFullName` itself is not changed (25+ callers rely on its
trimming).

**Structure Decision**: the change stays at the one consumer that lost the space.

## Complexity Tracking

None.
