# Implementation Plan: Pack refuses an archive name the file system would not keep as typed

**Branch**: `318-pack-name-trailing-dot` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/318-pack-name-trailing-dot/spec.md`

## Summary

`CFilesWindow::Pack` (`src/fileswn7.cpp`), after `CPackDialog` returns OK, turns the archive name
into a full path with `SalGetFullName(..., TRUE)` and then refuses only a last part made of spaces
and dots (`SalPackNameIsOnlyDotsAndSpaces`, 317) through the existing error path
(`errTextID = IDS_PATHISINVALID`, the message box titled Pack, `goto _PACK_AGAIN`). Every other name
goes to the packer, and the ZIP plug-in creates it through `\\?\`, so `report.` / `report.zip ` /
`CON.zip` are written literally.

The fix widens that one refusal: a new header-only pure rule
`SalPackNameIsNotKeptAsTyped(fullName)` in `src/common/salpackname.h` - TRUE when the last part
(after the last `\`) is not empty and ends with `.` or ` `, or is a reserved device name (research
R2) - replaces `SalPackNameIsOnlyDotsAndSpaces` at the call site. 317's rule is a strict subset
(a last part of only spaces and dots ends with one of them), so the old function is removed and its
16 saltests checks are carried over to the new rule (research R3). Same message, same dialog-again
route, no new string.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI only
**Storage**: N/A (no settings change)
**Testing**: `saltests` (`TestPackName318`, replacing `TestPackName317`); hidden-desktop GUI probe
`specs/318-pack-name-trailing-dot/probe/pack318_probe.ps1` (317's driver, 098's library); 317's
probe as a regression
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (two-panel file manager)
**Performance Goals**: N/A (one string scan per OK)
**Constraints**: no new UI string (the `.slt` refresh is not done by a run); no plug-in ABI change;
names are UTF-8 (WTF-8) - the rule reads bytes and compares only ASCII letters and the two-byte
UTF-8 superscript digits
**Scale/Scope**: one call site, one header-only rule

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no build change (the header is already listed in `saltests.vcxproj`) - PASS |
| II. Backward compatibility | settings, registry, plug-in ABI untouched; every name the rule does not name behaves as before (control rows) - PASS |
| III. Incremental modernization | widens an existing refusal at its one call site - PASS |
| IV. Windows commitment | follows Windows' own name rules (trailing dots/spaces, reserved names) - PASS |
| V. Plug-in architecture | `CSalamanderGeneral::SalIsValidFileNameComponent` and the packer interface unchanged - PASS |
| VI. UI consistency | the existing message of the same dialog, the dialog again - PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/318-pack-name-trailing-dot/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
├── probe/pack318_probe.ps1 (+ result_*.txt)
└── tasks.md
```

### Source Code (repository root)

```text
src/fileswn7.cpp             CFilesWindow::Pack - the refusal after SalGetFullName uses the new rule
src/common/salpackname.h     SalPackNameIsNotKeptAsTyped (replaces SalPackNameIsOnlyDotsAndSpaces)
src/saltests/saltests.cpp    TestPackName318 (317's checks carried over + the new cases)
```

**Structure Decision**: the existing files of feature 317; no new file in `src/`.

## Complexity Tracking

No violations.
