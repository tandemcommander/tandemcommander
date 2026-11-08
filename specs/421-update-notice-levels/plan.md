# Implementation Plan: Update notification - level choice, Download & Install, silent automatic install

**Branch**: `421-update-notice-levels` | **Date**: 2026-11-08 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/421-update-notice-levels/spec.md`

## Summary

Three changes to feature 420's update flow, all in the core module `salamand`:

1. The notification (`IDD_UPDATENOTICE`, `src/upddlg.cpp`) gets a label + drop-down *When a new
   version is found* (the three levels of Configuration > General). A change is stored at once and
   posted to the main window, which applies it to the window on screen (pure rule
   `SalUpdNoticeLevelChange`).
2. The classic (notify-only) form of an installed copy gets **Download & Install** (default button):
   420's download worker is started for that version with the metered test off, the hint line shows
   the progress, the button turns into *Cancel Download*; when the download ends the main window
   starts the installer through `UpdInstall_InstallNow` (or reports the failure). Not offered when
   the copy is not installed by the installer (hint says why, level choice disabled), the release has
   no verifiable asset, or the installer was refused (pure rule `SalUpdDownloadInstallOffered`).
3. The automatic level no longer shows a form: `ShowDownloadedUpdate` arms the update (420) and
   starts a main-window timer that starts the installer through `UpdInstall_InstallNow` as soon as
   the pure rule `SalUpdSilentInstallDecision` says *now* (automatic plan without an unconfirmed
   launch, last instance, no installer running, `DecideCloseApp() == scadAgree`, 30 s without input
   unless the user asked for the check, at most once per session). The automatic form, its hint and
   its *OK* text are removed; the level's text becomes "Install it automatically as soon as it is
   downloaded". The exit / next-start installation of 420 is untouched.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143, pure WinAPI
**Primary Dependencies**: 420's WinHTTP download worker, verification and launch (`src/updinstall.cpp`); `GetLastInputInfo`; `CMainWindow::DecideCloseApp` (080/088)
**Storage**: unchanged - `Update Level` and the `Install *` values of 420 in `Settings\Update Check`; no new stored value
**Testing**: `saltests` (new pure rules in `src/common/salupdinstall.h`, group `TestUpdateNotice421`); hidden-desktop probe `specs/421-update-notice-levels/probe/notice421_probe.ps1` reusing 420's loopback fixture server (`updserver420.py`) and Debug seams (`TC_UPDATECHECK_URL`, `TC_UPDATECHECK_PRETEND_VERSION`, `TC_UPDATE_PROBE_UNINSTALL`, `TC_UPDATE_PROBE_METERED`, `TC_UPDATE_PROBE_RUNLOG`, `TC_UPDATE_PROBE_LAUNCHFAIL`) plus one new Debug seam for the idle time (`TC_UPDATE_PROBE_IDLE_MS`)
**Target Platform**: Windows 10/11 x64
**Project Type**: desktop application (core module `salamand`)
**Performance Goals**: progress refreshed 4 times a second; the silent-install timer every 5 s (no measurable load)
**Constraints**: never start the installer while something can be lost; never close other instances; the download verification of 420 unchanged; `setup/tandemcommander.iss` unchanged; plug-in ABI unchanged
**Scale/Scope**: one dialog, one Configuration string, ~6 new strings, 3 pure rules

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | no new library or dependency | PASS |
| II. Backward compatibility | stored values unchanged (same `Update Level` meanings); an arm made by 420 (automatic, user, offered) keeps its meaning; the exit / start-up rules unchanged | PASS |
| III. Incremental modernization | decisions as pure rules with saltests; GUI code extends the existing files | PASS |
| IV. Windows commitment | WinAPI only | PASS |
| V. Plugin architecture | no plug-in interface change | PASS |
| VI. UI consistency | the notification keeps its header, dark theme and button layout rules; strings in free slots of the existing bundle (rule 084), translated for every enabled language | PASS |

Re-check after design: unchanged (PASS).

## Project Structure

### Documentation (this feature)

```text
specs/421-update-notice-levels/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/ui.md                 # the notification's forms after 421 (supersedes 420's ui.md table)
├── fix-log.md, closing-report.md
└── probe/ (notice421_probe.ps1, results)
```

### Source Code

```text
src/common/salupdinstall.h   # + SalUpdDownloadInstallOffered, SalUpdNoticeLevelChange, SalUpdSilentInstallDecision
src/saltests/saltests.cpp    # + TestUpdateNotice421
src/updinstall.h/.cpp        # + Download & Install request (start / cancel / take / progress), metered bypass,
                             #   UpdInstall_IsLastInstance / UpdInstall_InstallerRunning wrappers, refused query
src/upddlg.h/.cpp            # level drop-down, Download & Install / Cancel Download, progress, portable hint;
                             #   unfAutomatic removed
src/mainwnd.h, mainwnd3.cpp  # level change and download-done handling, silent install timer (IDT_UPDATEAUTOINSTALL)
src/lang/lang.rc, lang.rh    # IDD_UPDATENOTICE: + IDC_UPDN_LEVELLABEL, IDC_UPDN_LEVEL, IDC_UPDN_DLINSTALL; taller
src/lang/texts.rc2, texts.rh2  # + 6 strings (14007-14012), IDS_UPDATE_LEVEL_AUTO changed, HINT_AUTO / BTN_OK removed
src/consts.h (or where WM_USER_UPDATE* live)  # + WM_USER_UPDATENOTICE_LEVEL, IDT_UPDATEAUTOINSTALL
translations/*/salamand.slt/.origin  # refresh (stop-rules 2.13)
help/src/hh/salamand/othertask_newversion.htm, configuration_gener.htm
PRIVACY.md, CHANGELOG.md
```

**Structure Decision**: extend 420's files; no new source file except the probe.

## Complexity Tracking

None.
