# Implementation Plan: Desktop view column headers show the shell's names correctly

**Branch**: `248-folders-column-names` | **Date**: 2026-10-19 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/248-folders-column-names/spec.md`

## Summary

The Folders plug-in reads each shell column name as UTF-16 (`StrRetToBufW`) and stores it as
UTF-8 (`SplWToU8`) in `CShellColumn::Name`; `SetupView` copies that into `CColumn::Name`, which the
core (an MBCS build) draws and measures with the `A` GDI functions - UTF-8 bytes shown as code page
1250 give "Typ poloĹľky". Per the maintainer's decision the fix stays in the plug-in:
`GetShellColumns` converts the UTF-16 name to the Windows code page without best-fit, cut at a
whole character when it does not fit (header-only rule `SalWToCodePageWhole`,
`src/common/salcpfit.h`, added after the first review) into the same field. Cell texts (UTF-8, interface 104), the plug-in
interface and the core do not change.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI (shell `IShellFolder2` / `IShellDetails`, `StrRetToBufW`, `WideCharToMultiByte`)
**Storage**: N/A
**Testing**: build (`build.cmd`), encoding guard, `saltests` (`TestCpFit248`), GUI probe `probe/folders248_probe.ps1` (OCR of the header line on the hidden desktop)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, plug-in DLL (`folders.spl`)
**Performance Goals**: N/A (one conversion per column per listing set-up)
**Constraints**: plug-in interface unchanged (`spl_com.h`, `LAST_VERSION_OF_SALAMANDER`); `CColumn::Name` is `COLUMN_NAME_MAX` (30) bytes
**Scale/Scope**: one function in `src/plugins/folders/fs1.cpp`

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | no new dependency, no project change | PASS |
| II. Backward compatibility | plug-in ABI and the core untouched; column names return to the encoding upstream used | PASS |
| III. Incremental modernization | a one-function change; no rewrite | PASS |
| IV. Windows commitment | WinAPI only | PASS |
| V. Plugin architecture preservation | interface append-only rule not touched (nothing changes) | PASS |
| VI. UI consistency | plug-in column names in the same encoding as every other column name | PASS |

Re-check after design: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/248-folders-column-names/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
├── probe/folders248_probe.ps1
└── tasks.md
```

No `contracts/`: the feature changes no interface (the plug-in interface is explicitly out of
scope by the maintainer's decision).

### Source Code (repository root)

```text
src/plugins/folders/
├── fs1.cpp      # CPluginDataInterface::GetShellColumns - the conversion (the only code change)
└── folders.h    # CShellColumn::Name - comment: code page
src/common/salcpfit.h       # SalWToCodePageWhole - the pure rule (header-only, usable by plug-ins)
src/saltests/saltests.cpp   # TestCpFit248
```

**Structure Decision**: the behaviour change is confined to the Folders plug-in; the rule it uses
lives in a header under `src/common/` with `saltests` checks (stop-rules §2.5). The core's
behaviour does not change (nothing in the core includes the header).

## Complexity Tracking

None.
