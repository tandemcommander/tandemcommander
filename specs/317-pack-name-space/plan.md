# Implementation Plan: Pack never drops the leading space of a relative archive name

**Branch**: `317-pack-name-space` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/317-pack-name-space/spec.md`

## Summary

`CFilesWindow::Pack` (`src/fileswn7.cpp`) turns the Pack dialog's archive name into a full path with
`SalGetFullName(fileBuf, &errTextID, Is(ptDisk) ? GetPath() : NULL, nextFocus)`. `SalGetFullName`
(`src/salamdr3.cpp`) skips the characters <= ' ' at the start of the name and, for a relative name,
joins `curDir` with the name **from after those characters** unless its last parameter
`allowRelPathWithSpaces` is TRUE. Pack leaves it at the default FALSE, so ` report.zip` became
`<panel path>\report.zip`.

The fix, as feature 316 did for Unpack: pass `allowRelPathWithSpaces = TRUE` with the existing
default `nameBufSize = MAX_PATH` (the size of Pack's `fileBuf`). The joined path then names
` report.zip`, and every later step (the "packed into itself" check, the "add or overwrite?"
question, Overwrite's aside, the packer, the refresh) uses it. No folder is created by Pack, so no
create rule is involved; the program and the ZIP plug-in already write ` abs.zip` for an absolute
name (control row of the measurement).

A name whose last part is only spaces and dots (` ..`, ` .`) is refused after `SalGetFullName`
through the existing error path (`IDS_PATHISINVALID`) - research R4: kept as typed, the ZIP plug-in
would create a file literally named ` ..`. The pure rule lives in `src/common/salpackname.h`
(`SalPackNameIsOnlyDotsAndSpaces`) with saltests checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI only
**Storage**: N/A (no settings change)
**Testing**: hidden-desktop GUI probe `specs/317-pack-name-space/probe/pack317_probe.ps1` (316's
driver, 098's library); 316's and 241's probes as regressions; `saltests` (`TestPackName317`)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (two-panel file manager)
**Performance Goals**: N/A
**Constraints**: no new UI string (the `.slt` refresh is not done by a run); no plug-in ABI change
**Scale/Scope**: one call site (one argument + one refusal), one header-only rule

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no build change - PASS |
| II. Backward compatibility | settings, registry, plug-in ABI untouched; a relative name without leading spaces, an absolute name and an empty entry behave as before - PASS |
| III. Incremental modernization | a one-argument fix at the defective call site - PASS |
| IV. Windows commitment | WinAPI only - PASS |
| V. Plug-in architecture | `CSalamanderGeneral::SalGetFullName` (plug-ins) and the packer interface unchanged - PASS |
| VI. UI consistency | no new message; the name shown is the name used - PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/317-pack-name-space/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
├── probe/pack317_probe.ps1 (+ result_*.txt)
└── tasks.md
```

### Source Code (repository root)

```text
src/fileswn7.cpp                  CFilesWindow::Pack - the SalGetFullName call after CPackDialog,
                                  the refusal of a dots-and-spaces name
src/common/salpackname.h          SalPackNameIsOnlyDotsAndSpaces (header-only pure rule)
src/saltests/saltests.cpp         TestPackName317
src/vcxproj/saltests/saltests.vcxproj   the header listed
```

No other source file changes. `SalGetFullName` itself is not changed (its callers rely on the
trimming).

**Structure Decision**: the change stays at the one consumer that lost the space.

## Complexity Tracking

None.
