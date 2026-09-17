# Implementation Plan: Fix the two product findings of the antivirus review

**Branch**: `077-fix-antivirus-findings` | **Date**: 2026-09-17 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/077-fix-antivirus-findings/spec.md`

## Summary

Two independent, small changes, one commit each, plus their tooling and record:

1. **Ship the Visual C++ runtime application-locally.** `build.cmd` (Release
   only) copies the runtime libraries every shipped module imports
   (`vcruntime140.dll`, `vcruntime140_1.dll`, `msvcp140.dll`, `concrt140.dll`
   today) from the Visual Studio installation it already locates via
   `vswhere` — the redistributable directory is derived from the toolchain's
   own `Microsoft.VCRedistVersion.default.txt`, no hard-coded path — into the
   root of the release tree, then a new stdlib-only Python check
   (`tools/check_runtime_deps.py`) parses the import tables of every shipped
   PE and fails the build if any runtime import is not satisfied inside the
   tree. The installer already packages the tree recursively, so it needs no
   change. The signing sweep learns to leave Microsoft's signature on those
   files (never re-sign a validly Microsoft-signed file) and to refuse a
   runtime file that is not validly Microsoft-signed.
2. **Remove the in-process kernel32 patch.** `PreventSetUnhandledExceptionFilter`
   and its helper are deleted from `src/callstk.cpp`; the application keeps
   registering its top-level exception filter the supported way and, as the
   best-effort replacement the spec allows, re-registers it from the existing
   15-second "newly loaded modules" timer (the same place that already reacts
   to modules loaded into the process). `WriteProcessMemory` and
   `VirtualProtect` disappear from the executable's import table.

Verification is the larger half of the work (the user asked for every change
to be tested at least twice): build twice, import-table proof twice, crash
reporting proven with a debugger-injected fault on the application and on a
plugin module (before the change as harness baseline, after the change twice),
signing sweep twice plus a negative case, packaging through a real silent
install/uninstall twice, and the automated test suite twice. The literal
"clean Windows without the runtime" start is not reachable from this
non-elevated session (no Windows Sandbox, no Hyper-V permission) and is
recorded as an owed human step with the evidence chain that substitutes for
it — see [research.md](research.md) R7 and [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143 14.40.33807 (VS 2022 Community); Windows batch (`build.cmd`); Windows PowerShell 5.1 (`sign_release.ps1`, must stay 5.1-compatible, ASCII only); Python 3.13/3.14 stdlib only (build-mandatory since feature 052)
**Primary Dependencies**: Visual C++ 2015–2022 redistributable files from the VS installation (`VC\Redist\MSVC\<ver>\x64\Microsoft.VC143.CRT`); `signtool.exe` (Windows SDK); Inno Setup 7 (installer, unchanged); `cdb.exe` 10.0.26100 (Windows SDK Debuggers) for the crash proof
**Storage**: N/A (no configuration, no registry change)
**Testing**: `saltests.exe` (Debug tree, 1353 checks at baseline); `dumpbin /imports` + `/dependents`; a committed probe directory `specs/077-fix-antivirus-findings/probe/` (crash injection driver, loaded-module origin check, signing negative case); Windows Defender scan of the result as a sanity gate
**Target Platform**: Windows 11 x64 (stated); binaries run on any Windows 10 build (no import newer than Vista, verified in 076 §5.1)
**Project Type**: desktop application + release tooling
**Performance Goals**: none new; the runtime copy adds ~1.1 MB to the tree and installer; the re-registration call runs once per 15 s on the main thread (microseconds)
**Constraints**: no manual build step, no absolute paths in build scripts (constitution I, Technical Constraints); no plugin ABI change (interface 106); no config migration; `sign_release.ps1` stays Windows PowerShell 5.1 + ASCII; the archived published installer in `setup/output` must not be overwritten by test builds (same version string) — moved aside before packaging tests and restored after
**Scale/Scope**: 25 shipped PE modules, 216 signable files (with the four runtime files: 220 candidates, 216 signed by the project, 4 exempt); 2 source files, 1 build script, 1 signing script, 1 new Python tool, 4 documents

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Result |
|---|---|---|
| I. Build Reproducibility | Runtime files copied by the single build command from a path derived from the located toolchain; build fails loudly if absent; no manual copy, no hard-coded absolute path | PASS (design: `VS_INSTALL` from `vswhere` + `VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt`) |
| II. Backward Compatibility | No user-visible behaviour change except that the program now starts where it could not; crash reporting parity required and tested; plugin ABI untouched; `HKCU\Software\Tandem Commander\0.1` untouched | PASS |
| III. Incremental Modernization | Two minimal changes, one commit each, no refactor of adjacent code (`callstk.cpp` keeps its structure; only the patch and its helpers go) | PASS |
| IV. Windows Platform Commitment | Pure WinAPI; toolchain VS 2022; no new third-party dependency (the runtime is Microsoft's, redistribution licensed) | PASS |
| V. Plugin Architecture Preservation | No interface change; app-local runtime limitation for third-party plugin authors documented in `architecture/06-plugin-architecture.md` (FR-015) | PASS |
| VI. UI Consistency | No UI change | PASS |
| Release Documentation | Changelog entry drafted in `fix-log.md`; version/build bump deferred to the ship gate (as 075); no config move | PASS |
| Development Workflow | Single concern per commit → separate commits for (a) runtime shipping + signing exemption + check tool, (b) patch removal + re-registration, (c) records/docs; build verification and `clang-format` on touched C++ | PASS |

Post-design re-check (after Phase 1): unchanged — no violation, Complexity
Tracking stays empty.

## Project Structure

### Documentation (this feature)

```text
specs/077-fix-antivirus-findings/
├── spec.md              # feature specification
├── plan.md              # this file
├── research.md          # Phase 0: decisions R1–R11
├── data-model.md        # Phase 1: runtime-library set, signing classification, filter state
├── quickstart.md        # Phase 1: validation scenarios (each run twice)
├── contracts/
│   ├── runtime-deployment.md   # build.cmd step + check_runtime_deps.py CLI
│   └── signing-exemption.md    # sign_release.ps1 classification amendment (amends 050 §1)
├── probe/               # committed test drivers (created during implementation)
│   ├── crash_inject.ps1        # cdb-driven fault injection, detach before dispatch
│   ├── check_loaded_crt.ps1    # proves the running process loads the CRT from the app dir
│   └── sign_exempt_negative.ps1 # tampered runtime file must fail the sweep
├── fix-log.md           # running record (created during implementation)
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
src/
├── callstk.cpp          # remove PreventSetUnhandledExceptionFilter(+Aux, MyDummy…); add re-assert helper
├── callstk.h            # declare the helper (one line)
└── bugreprt.cpp         # AddNewlyLoadedModulesToGlobalModulesStore(): call the helper (15 s timer, main thread)

build.cmd                # Release: new :copy_vc_runtime step after :populate_runtime / before :clean_release_tree,
                         # then python tools\check_runtime_deps.py <OUT_DIR> (fails build on unsatisfied CRT import)
tools/
├── check_runtime_deps.py        # NEW: stdlib PE import-table closure check (static + delay-load imports)
└── codesign/sign_release.ps1    # exempt validly Microsoft-signed files; runtime names must be Microsoft-valid

architecture/
├── 03-build-pipeline.md         # "Populate Build Directory": the CRT step is now part of build.cmd
└── 06-plugin-architecture.md    # note for plugin authors: app-local runtime precedence (FR-015)
specs/050-code-signing/contracts/signing-cli.md   # §1 amended: Microsoft-signed exemption
specs/076-avast-false-positive-review/review-report.md  # §3.2/§3.3 marked implemented by 077
specs/NEXT-WORK.md, CLAUDE.md, CHANGELOG (draft only, in fix-log.md)
```

**Structure Decision**: the feature touches the existing single-project layout
only; no new project, no new directory outside `tools/` and the feature's own
`specs/077-…/probe/` (the committed-probe pattern of feature 075).

## Complexity Tracking

No constitution violations — table intentionally empty.

## Phase 0 — research summary

All unknowns resolved in [research.md](research.md): runtime source path
(R1), runtime set derivation (R2), import parser (R3), signing exemption rule
(R4), replacement for the patch (R5), crash-proof method under a debugger's
constraints (R6), clean-machine substitute evidence (R7), Debug builds (R8),
installer/packaging test and archive protection (R9), version/changelog (R10),
import-table proof (R11).

## Phase 1 — design summary

- [data-model.md](data-model.md): three conceptual entities — *Runtime
  Library Set*, *Signing Classification* (five states), *Top-Level Filter
  Registration* (ours / foreign / re-asserted).
- [contracts/runtime-deployment.md](contracts/runtime-deployment.md): build
  step semantics, messages, exit codes; `check_runtime_deps.py` CLI.
- [contracts/signing-exemption.md](contracts/signing-exemption.md): amended
  per-file classification, summary line, `-VerifyOnly` semantics.
- [quickstart.md](quickstart.md): nine validation scenarios, each with the
  "run twice" rule and expected outcomes, plus the owed human step.
