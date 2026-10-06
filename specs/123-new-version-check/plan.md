# Implementation Plan: New Version Check

**Branch**: `123-new-version-check` | **Date**: 2026-10-06 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/123-new-version-check/spec.md`

## Summary

The program learns the latest stable release from GitHub's public "latest
release" record (one HTTPS GET, 7 KB) and tells the user in three places: a
designed notification window after start-up (at most one request in 24 hours,
on by default), a *Check for New Version* command in the Help menu, and a
status line in the About dialog.

Technical approach, decided in [research.md](research.md):

- **Pure rules** (version order, a small strict JSON reader, release
  validation, the throttle decision) in `src/common/salupdcheck.{h,cpp}`,
  covered by `saltests`.
- **One worker thread with WinHTTP** in the core (`src/updcheck.{h,cpp}`),
  `winhttp.dll` delay-loaded so a start with the check off loads nothing new.
- **The program never opens an address taken from the network.** Both
  addresses it offers (installer, release notes) are *constructed* from the
  validated version; the answer only has to confirm that exactly that
  installer asset exists.
- **State in its own registry subkey**, written at once and read fresh by every
  instance (not part of the save-on-exit configuration), so a choice made in
  the notification holds for other instances.
- **The notification is a modeless window** that declares itself closable for
  an installer's update (feature 088's window property) and never takes the
  keyboard from a user who is working.

Detecting a Windows Package Manager installation stays out of scope, as in the
spec (the maintainer's question of 2026-10-06 was answered with options and
left undecided; a marker written by the installer can be added later without
touching this design — see research R12).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143 (VS2022)  
**Primary Dependencies**: pure WinAPI; **WinHTTP** (system DLL, new for the core — today only `mdview.spl` uses it); no new vendored library, no NuGet  
**Storage**: Windows Registry, new subkey `HKCU\Software\Tandem Commander\0.1\Update Check` (see [contracts/stored-state.md](contracts/stored-state.md)); no `THIS_CONFIG_VERSION` bump  
**Testing**: `saltests` for the pure rules (currently 17,498 checks); a GUI probe on the hidden desktop (`tools/run_on_hidden_desktop.ps1`) against a local fixture server through a Debug-only seam; real-endpoint smoke test  
**Target Platform**: Windows 11+ x64 (binaries run from `_WIN32_WINNT=0x0601`)  
**Project Type**: desktop application (core of the two-panel file manager)  
**Performance Goals**: no measurable change of start-up time (SC-002); notification within 10 s of the main window (SC-001); manual check answers within 15 s (SC-006)  
**Constraints**: start-up path does no network or DLL load on the UI thread; exit never waits for the network; nothing from the answer is displayed except a validated version and date; plug-in interface stays 107  
**Scale/Scope**: 2 new source pairs (~900 lines), 2 new dialogs, 1 menu command, 1 configuration check box, 1 About line, ~18 new strings × 8 languages, 1 help topic, `PRIVACY.md` + `CHANGELOG.md`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment | Status |
|---|---|---|
| I. Build Reproducibility | No new dependency to fetch or install: WinHTTP ships with Windows and its import library with the SDK. `tools/check_runtime_deps.py` concerns the VC runtime only; `winhttp.dll` is a system module (verify the checker stays green). | PASS |
| II. Backward Compatibility | **Default-on behaviour change** — the constitution asks for opt-in. Deliberate exception, see Complexity Tracking. No configuration migration: a new subkey that 0.1.8 and older never read (probe: an older version started with the subkey present, FR-026). Plug-in ABI untouched (interface 107). | PASS with documented exception |
| III. Incremental Modernization | New code in new files; touched legacy files get only the hooks (menu entry, command case, About line, one check box). | PASS |
| IV. Windows Platform Commitment | WinAPI + WinHTTP only. | PASS |
| V. Plugin Architecture Preservation | Implemented in the core, not as a plug-in: it lives in the Help menu, the About dialog, the configuration and the start-up sequence, and must work with every plug-in disabled. No plug-in interface change. | PASS (justified) |
| VI. UI Consistency | Both dialogs are `DIALOGEX` with `DS_SHELLFONT`, `FONT 8, "MS Shell Dlg"`, standard themed buttons, check box and the house `CHyperLink`. The notification's header band is painted like the About dialog's (the same brand artwork, wordmark and accent line; `AboutAndEvalDlgCreateBkgnd` precedent) — a painted background, not restyled standard controls. Larger heading text uses the dialog's own font scaled, no foreign typeface. No manifest, no `InitCommonControlsEx` change. | PASS |
| Release Documentation | `CHANGELOG.md` entry under `## [Unreleased]` (Added), stating default-on and how to turn it off. No version bump in this feature. | PASS |
| Privacy statement rule (`CLAUDE.md`, Key Facts) | New network communication → `PRIVACY.md` updated **in the same change**, validity line included; claim map in `fix-log.md`. | PASS (task) |

**Post-design re-check (after Phase 1)**: unchanged. The design added no
dependency, no interface change and no migration; the one exception stays the
default-on behaviour.

## Project Structure

### Documentation (this feature)

```text
specs/123-new-version-check/
├── plan.md              # This file
├── spec.md              # Feature specification (clarified 2026-10-06)
├── source-analysis.md   # Measured comparison of version sources (pre-plan)
├── research.md          # Phase 0: decisions R1–R13
├── data-model.md        # Phase 1: entities, states, transitions
├── quickstart.md        # Phase 1: validation guide
├── contracts/
│   ├── update-source.md # The request and what is accepted from the answer
│   ├── stored-state.md  # Registry values and the cross-instance rules
│   └── ui.md            # Notification window, manual check, About line, option
├── checklists/
│   └── requirements.md
├── probe/               # Created during implementation (fixture server, GUI probe)
├── fix-log.md           # Running record, created during implementation
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
src/
├── common/
│   ├── salupdcheck.h        # NEW  pure rules: version, JSON reader, release
│   └── salupdcheck.cpp      #      validation, throttle decision (no I/O, no UI)
├── updcheck.h               # NEW  core service: stored state, worker thread,
├── updcheck.cpp             #      WinHTTP request, orchestration, cancel
├── upddlg.h                 # NEW  CUpdateNoticeDialog (modeless notification),
├── upddlg.cpp               #      CUpdateCheckingDialog (manual-check wait)
├── salamdr1.cpp             # EDIT start the automatic check when start-up is complete
├── mainwnd.h                # EDIT WM_USER_UPDATECHECK_DONE, IDT_UPDATENOTICE
├── mainwnd3.cpp             # EDIT CM_HELP_CHECKVERSION, result message, deferred show,
│                            #      unattended close closes the notification
├── menu4.cpp                # EDIT Help menu item
├── resource.rh2             # EDIT CM_HELP_CHECKVERSION
├── logo.cpp, dialogs.h      # EDIT About dialog: status line + link
├── dialogs4.cpp, cfgdlg.h   # EDIT General page: check box (reads/writes the stored state)
├── lang/
│   ├── lang.rc, lang.rh     # EDIT IDD_UPDATENOTICE, IDD_UPDATECHECKING, IDD_ABOUT,
│   └── texts.rc2            #      IDD_CFGPAGE_GENERAL, menu string, messages
├── saltests/saltests.cpp    # EDIT new test group for salupdcheck
└── vcxproj/
    ├── salamand.vcxproj(.filters)          # EDIT new files, winhttp.lib, /DELAYLOAD:winhttp.dll
    └── saltests/saltests.vcxproj           # EDIT salupdcheck.cpp

translations/<8 languages>/salamand.slt     # two-stage refresh; pins in ui-overrides.json
help/src/hh/salamand/                       # NEW topic + edit configuration_gener.htm
PRIVACY.md, CHANGELOG.md, CLAUDE.md         # same change
tools/check_encoding.py                     # only if a rule needs the new identifiers
```

**Structure Decision**: single existing project (`salamand.vcxproj`). The split
follows the house pattern of features 080, 084 and 092: decisions that can be
tested without Windows state go to `src/common/sal*.{h,cpp}` (compiled into the
core and into `saltests`), everything that touches the network, the registry or
a window stays in the core.

## Design in brief

Detail is in the Phase 1 documents; this is the map.

1. **Start-up** (`salamdr1.cpp`, after `RegisterRestartForUpdates()`):
   `UpdateCheck_OnStartupComplete()` reads the stored state (registry only, no
   DLL load), asks the pure throttle rule, and — if a check is due — claims it
   under a named mutex and starts the worker thread. Nothing else happens on
   the UI thread.
2. **Worker**: one WinHTTP GET with fixed timeouts → bytes → pure parser →
   `CSalUpdRelease` or an error class → stored state updated → result posted to
   the main window (`WM_USER_UPDATECHECK_DONE`). Cancel = closing the request
   handle from the UI thread.
3. **Main window**: on a "newer, not skipped" start-up result it shows the
   notification as soon as the main window is enabled and no menu is open
   (retry on a 1 s timer otherwise); activation only when the user is not in
   the middle of something ([contracts/ui.md](contracts/ui.md) § Showing).
4. **Manual command**: same worker with the manual flag (no throttle, skipped
   version ignored), a small wait dialog with Cancel after 500 ms, then always
   an answer.
5. **About dialog**: reads the stored state when it opens; one extra line with
   a `CHyperLink` (download, or *Check now* = posts the manual command).
6. **General configuration page**: one check box bound to the stored state.

## Verification strategy

| Layer | What | How |
|---|---|---|
| Pure rules | version parse/order, JSON reader (escapes, nesting, depth, truncation, garbage), release validation, constructed addresses, throttle incl. clock in the future | `saltests`, incl. the saved real 0.1.8 record as a fixture and a mutation sweep over it |
| Request | status classes, size cap, timeouts, no redirect followed, no cookies, no authentication on a 401 challenge, headers sent | fixture server `probe/updserver.py` (logs every request) through the Debug-only seam; negative control as in feature 085 |
| Behaviour | SC-001…SC-008: notification, silence on every failure, 0 requests when off, ≤ 1 request per day over 20 starts, two instances at once, skip / later / turn off, exit during a check | `probe/updcheck_probe.ps1` on the hidden desktop, registry backup/restore of the whole product key |
| Update compatibility | notification open while an installer closes the program | feature 080's `rm_probe.ps1` with the notification open |
| Older version | 0.1.8 started with the new subkey present | probe row with the published 0.1.8 build |
| Real endpoint | request accepted by GitHub, "up to date" for 0.1.8, time to answer | one manual-command run against `api.github.com` (Debug and Release) |
| Design | SC-009: 100 / 150 / 200 %, light and dark, 8 languages, keyboard | screenshots from the probe + the maintainer's acceptance (person step) |
| Privacy | SC-010 | claim map in `fix-log.md`, each `PRIVACY.md` sentence against the fixture server's request log and the code |

Two independent reviews are planned (the practice of features 075–121): one
of the network and parsing code with a refute-first brief, one of the UI and
the cross-instance rules.

## Risks

- **First outbound connection of the signed core binary** — antivirus engines
  may weigh it (features 076/077). Mitigation: delay-loaded WinHTTP, a plain
  documented API host, one scan of the Release build before the next release.
- **Rate limit on shared addresses** (60/h, `304` counts — measured). Mitigated
  by one request per user per day; failure is silent. If it proves a problem,
  research R1 names the fallback.
- **GitHub changes the record's shape.** The reader needs five fields; anything
  unexpected is "could not check", never a wrong notification.
- **Translations**: adding strings breaks `build.cmd full` for all languages
  until the two-stage `.slt` refresh runs (project memory); DeepL drifts to the
  informal register for de/fr/nl/es → pins.
- **Hidden-desktop limits**: no real keyboard; the "does not steal the
  keyboard" rule needs a person's pass (quickstart § G).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Principle II: behaviour change is on by default instead of opt-in | The maintainer's explicit requirement; the purpose is that users who never look for updates learn about fixes for data-loss defects (features 096–113 fixed a dozen present in every release). An opt-in check reaches almost none of them. | Opt-in (off by default) was considered and rejected by the maintainer in the feature description and again in clarification Q1. The exception is bounded: one option turns it off, the notification itself offers that option, and `PRIVACY.md` + `CHANGELOG.md` disclose it in the same change. Precedent: panel tabs, feature 078. |
