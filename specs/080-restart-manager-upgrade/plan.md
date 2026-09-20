# Implementation Plan: Upgrading Over a Running Instance (Restart Manager)

**Branch**: `080-restart-manager-upgrade` | **Date**: 2026-09-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/080-restart-manager-upgrade/spec.md`

## Summary

The backlog item said *"the program does not end when the installer asks it
to"*. The baseline (research R1) refuted that: the update over a running 0.1.7
failed because of the windowless helper `salmon.exe`, which the Restart
Manager cannot close; with the helper removed in feature 079 an idle program
closes in about a second and the update succeeds. What is actually wrong:

1. the installer's request runs the **interactive** exit inside the question
   stage — with a file operation running or a plug-in viewer open (the
   everyday state) the installer times out, a **prompt is left on an
   unattended machine**, and the program **exits later by itself**;
2. after a successful update the program is **not started again**;
3. an installation upgraded from 0.1.7 **keeps `salmon.exe`**, and the obvious
   `[InstallDelete]` remedy **re-creates the original failure** (measured).

Technical approach (research R4–R8):

- Recognise the installer's request (`ENDSESSION_CLOSEAPP`, not critical, the
  session not shutting down). **Decide at the question stage** with a pure,
  side-effect-free function over a snapshot of the program's state; **act at
  the instruction stage** by re-entering the existing exit sequence,
  synchronously, under an *unattended* rule: every prompt site in the core
  takes its negative branch without showing anything. Swallow the one
  `WM_CLOSE` the Restart Manager sends after an agreed request.
- `RegisterApplicationRestart` at the end of start-up, update-only flags,
  command line carrying identity (`-t`, `-i`) but no location; state travels
  through the stored configuration.
- Installer: delete the stale helper from `[Code]` at `ssPostInstall`, never
  through a section the Restart Manager learns about.

## Technical Context

**Language/Version**: C++ (`/std:c++latest`), MSVC v143 (VS 2022); Inno Setup 7 Pascal script for the installer step; Windows PowerShell 5.1 for the probes
**Primary Dependencies**: pure WinAPI — `user32` (session messages, window enumeration), `kernel32` (`RegisterApplicationRestart`, available from `_WIN32_WINNT` 0x0600; the product builds with 0x0601); `rstrtmgr.dll` only in the probes. No new third-party dependency
**Storage**: none new. State crosses the restart through the existing per-user configuration (`HKCU\Software\Tandem Commander\0.1`); no new value, no `THIS_CONFIG_VERSION` bump
**Testing**: `saltests` (pure decision function and restart command line; 1427 checks today); `probe/rm_probe.ps1` (the installer's Restart Manager sequence against a running build), `probe/upgrade_probe.ps1` (a real silent installer over a scratch per-user installation), `probe/tc_drive.ps1` (puts one instance into the busy states by posted messages), `probe/rm_protocol_dummy.ps1` (protocol facts); `tools/check_encoding.py` (strict must stay `TOTAL: 0`)
**Target Platform**: Windows 11 (constitution IV); binaries run on Windows 10 1904x+
**Project Type**: desktop application (single Win32 executable + plug-ins) and its Inno Setup installer
**Performance Goals**: answer the request within 5 s (Restart Manager's limit, measured) — target: milliseconds; finish an agreed close within 10 s with the default plug-ins (limit 30 s, measured; today 1.2–1.3 s)
**Constraints**: plug-in interface stays 106, no plug-in rebuilt for the feature; version stays 0.1.8 / build 192; sign-out / shutdown / critical-shutdown paths byte-for-byte untouched in behaviour; no new configuration option; no new UI string is planned (nothing is shown — if one turns out to be needed, the two-stage `.slt` refresh applies); verification must leave the user's machine as found
**Scale/Scope**: one handler in `src/mainwnd3.cpp` (~600 lines, the most delicate function of the program) gets one entry block and one-line guards at ~7 prompt sites reaching into `fileswn2.cpp`, `mainwnd4.cpp`, `plugins1.cpp`; one new pure module in `src/common/`; one call in `src/salamdr1.cpp`; ~25 lines of Pascal in `setup/tandemcommander.iss`; records

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Verdict | Notes |
|---|---|---|
| I. Build Reproducibility | PASS | New sources are added to `salamand.vcxproj` and `saltests.vcxproj` like `saltabs` / `salbugreport`; no build step, no manual action. Probes are developer-side and never invoked by the build. |
| II. Backward Compatibility | PASS with one documented default-on behaviour | Nothing that works today changes for sign-out, shutdown, critical shutdown or the normal exit (scope guard, research R4). The automatic restart after an update is new user-visible behaviour without a program option: it replaces a disappearance, happens only when an installer is run, and is controlled by the installer's existing `/NORESTARTAPPLICATIONS` switch — recorded as a deliberate exception in the manner of feature 078 (spec *Assumptions*). Registry root, configuration format and identity untouched. |
| III. Incremental Modernization | PASS | One commit per concern (pure module + tests; request handling; restart registration; installer step; records). The exit handler is extended, not restructured; no adjacent clean-up. New comments in English. |
| IV. Windows Platform Commitment | PASS | Pure WinAPI, no new dependency. |
| V. Plugin Architecture Preservation | PASS | No change under `src/plugins/shared/`, interface 106. The one place where a plug-in-side signal would give better behaviour (closing viewer windows silently) is **not** taken for exactly this reason and is handed over as follow-up work (research R5). |
| VI. UI Consistency | PASS | No dialog, no control, no visual change. |
| Release Documentation | PASS | User-visible change → `CHANGELOG.md`, section `## [0.1.8] — unreleased`, truthful about the limitation (an open plug-in window or a running operation declines the update). No version bump: 0.1.8 is unreleased and this feature ships inside it (FR-016). |

**Post-design re-check (after Phase 1)**: unchanged — the contracts add no
plug-in surface, no stored value and no UI. No entry in Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/080-restart-manager-upgrade/
├── spec.md              # revised after the baseline (Background, US1.5, US5, FR-021/022)
├── plan.md              # this file
├── research.md          # R1–R9, measured
├── data-model.md        # snapshot, decision, request state, restart command line
├── quickstart.md        # validation scenarios V1–V20 + owed human steps
├── contracts/
│   ├── close-request.md       # what the program does with an installer's request
│   ├── restart-registration.md
│   └── installer-cleanup.md
├── checklists/requirements.md
├── fix-log.md           # running record
├── probe/               # rm_probe, wnd_probe, upgrade_probe, tc_drive, rm_protocol_dummy, config_equivalence
├── REMAINING-WORK.md, closing-report.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
src/
├── common/
│   ├── salcloseapp.h        # NEW  pure: request classification, close decision, restart command line
│   └── salcloseapp.cpp      # NEW
├── saltests/saltests.cpp    # + TestCloseApp (decision table, window filter, command line quoting)
├── precomp.h                # + #include "salcloseapp.h"
├── mainwnd.h                # + DecideCloseApp(), RegisterRestartForUpdates() (request state is file-scope in mainwnd3.cpp)
├── mainwnd3.cpp             # WM_QUERYENDSESSION / WM_ENDSESSION / WM_CLOSE: the two stages, the
│                            #   WM_CLOSE swallow, unattended guards at the handler's prompt sites
├── mainwnd4.cpp             # CloseDetachedFS: unattended guard
├── fileswn2.cpp             # PrepareCloseCurrentPath: unattended guards
├── plugins1.cpp             # CPluginData::Unload: unattended guard
├── consts.h / salamdr1.cpp  # UnattendedClose global; RegisterApplicationRestart after start-up
└── vcxproj/
    ├── salamand.vcxproj           # + salcloseapp.cpp/.h
    └── saltests/saltests.vcxproj  # + salcloseapp.cpp/.h

setup/tandemcommander.iss    # [Code] CurStepChanged(ssPostInstall): remove {app}\utils\salmon.exe

CHANGELOG.md                 # ## [0.1.8] — unreleased
CLAUDE.md, specs/NEXT-WORK.md, specs/072-winget-distribution/REMAINING-WORK.md
help/                        # the page(s) that describe exiting / updating, if any mention applies
```

**Structure Decision**: the feature lives in the core (`src/`), with the
decision logic split out as a pure module under `src/common/` so that it is
covered by `saltests` — the pattern of `saltabs` (078) and `salbugreport`
(079). `src/common/salcloseapp.*` must not include any core header; the core
fills its plain-data snapshot. The installer gets a `[Code]` step only.

## Design in brief

Details are in the contracts; this is the map.

1. **Classification** — `SalIsCloseAppRequest(lParam, sessionShuttingDown)`
   → *not ours* (existing path, untouched) or an installer's request. The
   stage is the program's own knowledge: the message from outside is the
   question stage; the re-dispatch from `WM_ENDSESSION`, marked by the flag
   `CloseAppExecuting`, is the execute stage.
2. **Decision** — `SalCloseAppDecide(const CSalCloseAppSnapshot&)` → agree or
   one of the reasons D1–D8 (research R5). The window filter for D8 is part
   of the pure module.
3. **Query stage** — collect snapshot, decide, remember *agreed* and the
   time, trace the reason, `return TRUE/FALSE`. Nothing else.
4. **Instruction stage** — wParam 0: forget. wParam 1 and *agreed*: arm the
   one-shot `WM_CLOSE` swallow, set `UnattendedClose`, decide again, re-enter
   the handler as the execute stage, clear the flag, `return 0`.
5. **Execute stage** — falls into the existing sequence as a non-critical
   session request; each prompt site reads `UnattendedClose` and abandons
   instead of asking (research R6).
6. **Restart** — `RegisterApplicationRestart(SalRestartCommandLine(...),
   RESTART_NO_CRASH | RESTART_NO_HANG | RESTART_NO_REBOOT)` once, where
   start-up completes.
7. **Installer** — `CurStepChanged(ssPostInstall)`: delete the stale helper
   with a short retry, log the outcome, never fail.

## Verification strategy

- `saltests`: every decision reason, the order of reasons, the window filter
  (caption/tool-window/class rules), classification of lParam combinations
  including the critical and shutting-down cases, and the restart command
  line (no arguments, prefix with spaces, prefix with quotes, icon index,
  both).
- Probes, against the **Release** build of this branch: quickstart V1–V12 —
  idle close + restart, the three measured busy states (modal dialog, file
  operation, plug-in viewer) plus Find searching and internal viewer, the
  *no surprise exit* check, configuration equivalence with a manual exit,
  confirm-on-exit, two instances, `/NORESTARTAPPLICATIONS`, the real installer
  over HEAD and over the published 0.1.7, the stale-file removal.
- Independent review of the diff in `mainwnd3.cpp` by an agent that did not
  write it (the practice that rejected fixes in 069 and 075), with the
  explicit question *"which existing path changed behaviour?"*.
- Gates: full Debug + Release build, `saltests`, `check_encoding.py` strict
  `TOTAL: 0`, no diff under `src/plugins/shared/`, machine state restored and
  verified (research R9).

## Complexity Tracking

No constitution violations to justify.
