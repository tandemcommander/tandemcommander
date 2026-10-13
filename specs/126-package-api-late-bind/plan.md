# Implementation Plan: The program does not depend on Windows 8 functions to start

**Branch**: `126-package-api-late-bind` (from `125-unc-server-shares`) | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)
**Input**: GitHub issue #6 (`issues/issue_6.md`)

## Summary

`CSalShellOsProbe::GetPackagePath` (`src/common/salshell.cpp`, feature 071) calls two kernel32
functions that exist since Windows 8 / 8.1; as static imports they stop the loader on older
systems before any code runs. They are resolved at run time instead. The lookup itself becomes
a function that takes the two functions as a parameter, so `saltests` can run it with the
functions "absent" and with fakes; the real resolver is checked against what Windows reports
for an installed package.

## Technical Context

**Language/Version**: C++20, MSVC v143
**Primary Dependencies**: `GetModuleHandleW` / `GetProcAddress` (kernel32, always present)
**Storage**: none
**Testing**: `saltests` (`TestPackageApi126`: absent functions, fakes for every branch, the real resolver); `probe/pe_imports.py` (an independent import-table reader: before/after diff, whole Release tree); `probe/package_live.ps1` (the real lookup against `Get-AppxPackage` on this Windows 11); `tools/check_encoding.py`
**Target Platform**: Windows 11 x64 (supported); the change removes a load-time requirement that older Windows cannot meet
**Project Type**: desktop application (shared code under `src/common`)
**Performance Goals**: none - the lookup runs when a preset is located (settings dialog, starting a shell)
**Constraints**: no behaviour change where the functions exist; thread-safe; no new string; plug-in interface untouched
**Scale/Scope**: 2 source files, about 60 lines; about 40 saltests checks

## Constitution Check

| Principle | Verdict |
|-----------|---------|
| I. Build reproducibility | PASS |
| II. Backward compatibility | PASS - behaviour is unchanged where the functions exist |
| III. Incremental modernization | PASS |
| IV. Windows commitment ("all features MUST target Windows 11 and newer") | PASS - no feature is aimed at an older Windows and none is added; an accidental load-time requirement is removed. The support statement is not changed (spec FR-005) |
| V. Plugin architecture preservation | PASS |
| VI. UI consistency | PASS - no UI |

## Stages

| Stage | Content |
|---|---|
| S0 measure | done: imports read by `probe/pe_imports.py` and `dumpbin`; Microsoft's minimum versions; the pre-fix Release executable kept for the diff |
| S1 code | `salshell.h`: `CSalShellPackageApi`, `SalShellResolvePackageApi`, `SalShellPackagePath`; `salshell.cpp`: the lookup through the parameter, the resolver, `GetPackagePath` = both together; `#include <appmodel.h>` dropped |
| S2 tests | saltests `TestPackageApi126`; saltests `--package-path <family>` mode for the live probe; `probe/package_live.ps1` |
| S3 gates | Debug + Release builds; saltests; encoding guard; `pe_imports.py diff` old/new Release executable = exactly the two entries; `pe_imports.py check` on the Release tree = 0; independent review; records |

## Project Structure

```text
src/common/salshell.h, src/common/salshell.cpp   # the change
src/saltests/saltests.cpp                        # TestPackageApi126, --package-path
specs/126-package-api-late-bind/probe/           # pe_imports.py, package_live.ps1, results
```

**Structure Decision**: the existing module; no new file in the build.

## Complexity Tracking

No violations.
