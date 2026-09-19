# Implementation Plan: Remove the salmon.exe Crash Reporter

**Branch**: `079-remove-salmon-crash-reporter` | **Date**: 2026-09-19 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/079-remove-salmon-crash-reporter/spec.md`

## Summary

Remove the out-of-process crash reporter `salmon.exe` (project, sources,
launcher, shared-memory protocol, dialog template, 41 strings, translations,
tooling references, documentation) from the build and the shipped product,
because antivirus engines flag it and it has not delivered a memory dump in
any release. The main application keeps writing its own text bug report; it
takes over the two duties the helper performed for it — naming the report
(creating the folder on demand) and telling the user where the report is —
through a message box shown from the existing bug-report thread, then
terminates with the same exit code. The inter-instance process-list record
keeps its layout (the helper's PID slot becomes a reserved zero). No version
bump, no plugin ABI change, no configuration change. Verified by full Debug
and Release builds, `saltests`, a crash-injection probe derived from feature
077 (now asserting the message and the exit code), a start-up probe (stale
reports, fresh registry), the signing sweep, the runtime-dependency checker
and a repository grep. Details and rationale: [research.md](research.md).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143 (VS 2022); Windows
Batch + PowerShell 5.1 for build/probe scripts; Python 3.14 for the
translation tooling and checkers
**Primary Dependencies**: pure WinAPI (`SHGetFolderPathW`,
`CreateDirectoryW`, `CreateFileW`, `MessageBoxW`); no new third-party code;
DeepL via the existing `tools/translate` package (developer-side only)
**Storage**: report files under `%LOCALAPPDATA%\Tandem Commander\`;
registry key `HKCU\Software\Tandem Commander\Bug Reporter` is no longer
read or written (left in place on users' machines)
**Testing**: `saltests.exe` (baseline 1405 checks; new `TestBugReport079`),
`build.cmd full` / `build.cmd full release` (includes `check_encoding.py`
and the `.slt` import for 8 languages), `tools/check_runtime_deps.py`,
`tools/codesign/sign_release.ps1`, two PowerShell probes under
`specs/079-…/probe/` (crash injection via cdb; start-up scenarios)
**Target Platform**: Windows 11+, x64 (Win32 configurations kept buildable)
**Project Type**: desktop application (WinAPI), MSBuild solution
**Performance Goals**: start-up no slower than today (one process fewer);
crash path: report within the existing 6 s budget, message shown, exit
**Constraints**: version stays 0.1.8 / build 192; plugin interface 106
untouched; `THIS_CONFIG_VERSION` untouched; `CProcessListItem` layout
untouched; crash code uses the minimum of library calls (raw WinAPI, static
buffers); constitution III — only code the removal touches is modernised
**Scale/Scope**: ~30 files removed (≈5.5 k lines), ~25 files edited, 2 files
added (`src/common/salbugreport.*`), 2 probe scripts, 8 translation sources
regenerated

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|-----------|------------|
| I. Build Reproducibility | PASS — one project fewer in the solution; the generated solution filter follows the `.sln`; a stale-output cleanup line is added to `build.cmd` so existing output trees converge without a manual delete; no manual steps. |
| II. Backward Compatibility | PASS with documented deprecation — the helper is removed deliberately (spec Background); user-visible behaviour of a crash is preserved (text report, closing message, exit code 1) and improved (no blocking start-up prompt, folder created on demand). Configuration, registry root and version untouched; the inter-instance record layout is preserved so 0.1.8 and this build coexist. The `Bug Reporter` key is simply no longer touched. |
| III. Incremental Modernization | PASS — changes are confined to the removal and the two duties taken over; the two hardening guards in `HandleException` sit in lines being rewritten and are justified in research R2; no adjacent refactoring. |
| IV. Windows Platform Commitment | PASS — pure WinAPI, no new dependencies. |
| V. Plugin Architecture Preservation | PASS — no `src/plugins/shared/` interface change (only the base-address table line for the removed project); plugin crashes keep producing the same report. |
| VI. UI Consistency | PASS — the closing message is a standard message box with the product caption; no new dialog template, no process-wide visual change. |
| Release Documentation | PASS — `CHANGELOG.md` gains an `[Unreleased]` section (Removed/Changed); no version bump by explicit instruction, so the bump rule is not triggered. |

**Post-design re-check (after Phase 1)**: unchanged — the design adds one
pure helper file in `src/common/` (house precedent 071/078), one build
cleanup line, two strings; nothing new to justify. No Complexity Tracking
entries.

## Project Structure

### Documentation (this feature)

```text
specs/079-remove-salmon-crash-reporter/
├── spec.md              # feature specification
├── plan.md              # this file
├── research.md          # Phase 0: inventory and decisions R1–R11
├── data-model.md        # Phase 1: crash report, process-list record, report-thread handshake
├── quickstart.md        # Phase 1: validation guide (builds, tests, probes, greps)
├── contracts/
│   ├── crash-report.md          # file location, name, content, message, exit code
│   └── process-list-record.md   # inter-instance shared record layout (compatibility)
├── probe/                       # created in implementation
│   ├── crash_inject.ps1         # derived from 077, asserts message + exit code
│   └── startup_probe.ps1        # stale reports / fresh registry scenarios
├── fix-log.md                   # running record (created in implementation)
├── checklists/requirements.md
└── tasks.md                     # /speckit-tasks output
```

### Source Code (repository root)

```text
src/
├── callstk.cpp / callstk.h      # HandleException, ThreadBugReportF, CreateBugReportFile: in-process naming,
│                                #   folder creation, closing message, MessageDone handshake, guards
├── salamdr1.cpp                 # WinMain wrapper: drop SalmonInit/SetSLG/CheckBugs; host EnableExceptionsOn64
├── tasklist.cpp / tasklist.h    # CProcessListItem: SalmonPID -> Reserved1; drop HSalmonProcess, Break foregrounding, dead BugReportPath
├── consts.h                     # drop extern BugReportPath
├── texts.rh2                    # drop IDS_SALMON_*; add IDS_BUGREPORT_SAVED / IDS_BUGREPORT_NOTSAVED
├── lang/lang.rc, lang.rh        # drop IDD_SALMON_MAIN (+DESIGNINFO), IDD_/IDC_SALMON_*
├── lang/texts.rc2               # drop IDS_SALMON_* strings; add the two new strings
├── common/salbugreport.h/.cpp   # NEW: SalFormatBugReportName (pure, unit-tested)
├── saltests/saltests.cpp        # NEW TestBugReport079
├── salmoncl.cpp / salmoncl.h    # DELETED
├── salmon/                      # DELETED (whole directory)
├── vcxproj/salamand.sln         # drop the salmon project + 10 configuration lines
├── vcxproj/salamand.vcxproj(.filters)   # drop salmoncl.*; add common/salbugreport.*
├── vcxproj/saltests/saltests.vcxproj    # add common/salbugreport.cpp
├── vcxproj/salmon/              # DELETED (whole directory)
└── plugins/shared/baseaddr_x64.txt, baseaddr_x86.txt   # drop the salmon line

tools/
├── check_encoding.py            # drop "salmon/" exclusion
├── brand/gen_icons.py, brand/README.md   # drop salmon.ico
└── salbreak/tasklist.h, tasklist.cpp     # mirror rename of the reserved field

build.cmd                        # stale utils\salmon.exe/.pdb cleanup
translations/<8 enabled>/salamand.slt     # regenerated (two-stage refresh)
architecture/01-project-overview.md, 02-solution-structure.md
CLAUDE.md, CHANGELOG.md
help/src/hh/salamand/othertask_tasklist.htm, dlgboxes_tasks.htm
```

**Structure Decision**: single MSBuild solution; the feature is a removal
plus a small in-process replacement, so no new module beyond the pure
helper in `src/common/` (house precedent for unit-tested rules).

## Design Outline

1. **In-process crash path** (`callstk.cpp`) — see
   [contracts/crash-report.md](contracts/crash-report.md) and
   [data-model.md](data-model.md):
   - `HandleException`: guard against re-entry on the handling thread; build
     the report folder (`SHGetFolderPathW` + `\Tandem Commander`,
     `CreateDirectoryW`), the file name (`SalFormatBugReportName` + suffix
     probe), hand both to `CTBRData`; signal `Event`; wait `EventProcessed`
     (6 s); if answered, wait `MessageDone` (no limit); else write inline and
     show the message inline; `TerminateProcess(…, 1)`.
   - `ThreadBugReportF`: write the report, show the existing special notices,
     signal `EventProcessed`, show the closing message (`MessageBoxW`,
     `MB_OK | MB_ICONERROR | MB_SETFOREGROUND | MB_TOPMOST`), signal
     `MessageDone`.
   - Message text: `LoadStrW(IDS_BUGREPORT_SAVED / _NOTSAVED)` formatted with
     the wide path; hard-coded English when `HLanguage == NULL`.
2. **Start-up** (`salamdr1.cpp`): `EnableExceptionsOn64()` then
   `WinMainCRTStartup()`; the two later helper calls disappear.
3. **Removal**: files, projects, resources, strings, tooling references,
   base addresses, build cleanup, docs (research R8–R10).
4. **Translations**: two-stage refresh for the 8 enabled languages (R8).
5. **Verification**: [quickstart.md](quickstart.md).

## Complexity Tracking

No constitution violations; table intentionally empty.
