# Implementation Plan: Pack refuses an archive name whose last part holds a colon

**Branch**: `319-pack-name-colon` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/319-pack-name-colon/spec.md`

## Summary

`CFilesWindow::Pack` (`src/fileswn7.cpp`), after `CPackDialog` returns OK, turns the archive name
into a full path with `SalGetFullName(..., TRUE)` and refuses, through the existing error path
(`errTextID = IDS_PATHISINVALID`, the message box titled Pack, `goto _PACK_AGAIN`), a last part
that `SalPackNameIsNotKeptAsTyped` (318) names - unless a file of exactly that name exists. A `:`
outside the drive prefix passes, and NTFS reads `report:zip.zip` as a stream of `report`.

The fix adds one header-only pure rule `SalPackNameHasStreamColon(fullName)` to
`src/common/salpackname.h` - TRUE when the last part (after the last `\` or `/`, the drive prefix
`X:` at the start skipped) holds a `:` - and refuses it at the same call site **unconditionally**
(not gated by `FileExists`: an existing stream is refused too, spec Clarifications). Same message,
same dialog-again route, no new string; saltests checks the rule.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI only
**Storage**: N/A (no settings change)
**Testing**: `saltests` (`TestPackName319`); hidden-desktop GUI probe
`specs/319-pack-name-colon/probe/pack319_probe.ps1` (318's driver with stream-aware snapshots,
098's library); 318's probe as a regression
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (two-panel file manager)
**Performance Goals**: N/A (one string scan per OK)
**Constraints**: no new UI string (the `.slt` refresh is not done by a run); no plug-in ABI change;
names are UTF-8 (WTF-8) - `:` (0x3A) is never a byte of a multi-byte UTF-8 sequence, so a byte scan
is exact
**Scale/Scope**: one call site, one header-only rule

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no build change (the header is already used by `saltests` and the core) - PASS |
| II. Backward compatibility | settings, registry, plug-in ABI untouched; every name without a colon in its last part behaves as before (control rows, 318's probe) - PASS |
| III. Incremental modernization | one more condition at the existing refusal - PASS |
| IV. Windows commitment | follows Windows' naming rules (`:` is reserved outside the drive prefix) - PASS |
| V. Plug-in architecture | packer interface and plug-ins unchanged - PASS |
| VI. UI consistency | the existing message of the same dialog, the dialog again - PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/319-pack-name-colon/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
├── probe/pack319_probe.ps1 (+ result_*.txt)
└── tasks.md
```

### Source Code (repository root)

```text
src/fileswn7.cpp             CFilesWindow::Pack - the refusal after SalGetFullName also on SalPackNameHasStreamColon
src/common/salpackname.h     SalPackNameHasStreamColon (new)
src/saltests/saltests.cpp    TestPackName319 (new checks)
```

**Structure Decision**: the existing files of features 317 / 318; no new file in `src/`. No
`contracts/` - nothing other code or plug-ins rely on changes.

## Complexity Tracking

No violations.
