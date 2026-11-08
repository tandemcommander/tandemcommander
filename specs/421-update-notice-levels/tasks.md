# Tasks: Update notification - level choice, Download & Install, silent automatic install

**Input**: `specs/421-update-notice-levels/` (spec.md, plan.md, research.md, data-model.md, contracts/ui.md, quickstart.md)
**Tests**: saltests for the pure rules and a hidden-desktop probe are required by the project (stop-rules §2.5, §2.7).

## Phase 1: Setup

- [ ] T001 Create `specs/421-update-notice-levels/fix-log.md` with the measurement at 1a25a164 (by reading) and the decisions of research.md

## Phase 2: Foundational (pure rules, resources, worker hooks)

- [ ] T002 Add `SalUpdDownloadInstallOffered`, `SalUpdNoticeLevelChange`, `SalUpdSilentInstallPlanned`, `SalUpdSilentInstallDecision` to `src/common/salupdinstall.h`
- [ ] T003 Add `TestUpdateNotice421` (all branches of the four rules, negative controls) to `src/saltests/saltests.cpp` and register it
- [ ] T004 Extend the download worker in `src/updinstall.cpp` / `src/updinstall.h`: per-request metered bypass, progress counters, cancel of a running download, the Download & Install request (start / cancel / take / is-requested), `UpdInstall_IsRefused`, `UpdInstall_InstallerRunning`, `UpdInstall_IsLastInstance`; Debug seam `TC_UPDATE_PROBE_IDLE_MS`
- [ ] T005 Add strings 14007-14012, change `IDS_UPDATE_LEVEL_AUTO`, remove `IDS_UPDATE_HINT_AUTO` / `IDS_UPDATE_BTN_OK` in `src/lang/texts.rc2` and `src/texts.rh2`
- [ ] T006 Extend `IDD_UPDATENOTICE` in `src/lang/lang.rc` (+ ids in `src/lang/lang.rh`): level label + drop-down, Download & Install button, taller window
- [ ] T007 Add `WM_USER_UPDATENOTICE_LEVEL` and `IDT_UPDATEAUTOINSTALL` next to `WM_USER_UPDATENOTICE_FORM` / `IDT_UPDATENOTICE` in `src/consts.h`

## Phase 3: User Story 1 - Download & Install (P1)

**Independent test**: probe rows D1-D8.

- [ ] T008 [US1] Classic form: Download & Install button (default) when offered, hint `IDS_UPDATE_HINT_DLI`; click → request; progress timer → hint `IDS_UPDATE_DLI_PROGRESS`, button `Cancel Download`; cancel / Remind Me Later / Skip / destroy drop the request in `src/upddlg.cpp`
- [ ] T009 [US1] `OnUpdateDownloadDone` in `src/mainwnd3.cpp`: a taken request → `UpdInstall_InstallNow` on success (window closed when started), `IDS_UPDATE_DLI_FAILED` and the first state on failure
- [ ] T010 [US1] A verified installer already present → InstallNow at once (no download) in `src/upddlg.cpp` / `src/updinstall.cpp`

## Phase 4: User Story 4 - Silent automatic install (P1)

**Independent test**: probe rows A1-A7.

- [ ] T011 [US4] `ShowDownloadedUpdate` in `src/mainwnd3.cpp`: at the automatic level with a planned silent install → no form (close our classic form), start the wait; else the offer form
- [ ] T012 [US4] The wait timer in `src/mainwnd3.cpp`: evaluate `SalUpdSilentInstallDecision` every 5 s with `DecideCloseApp`, last input, last instance, installer running; *now* → `UpdInstall_InstallNow`; *never* → stop; once per session per version
- [ ] T013 [US4] Remove the automatic form (`unfAutomatic`) from `src/upddlg.h` / `src/upddlg.cpp` and its users in `src/mainwnd3.cpp`

## Phase 5: User Story 2 - Level choice in the notification (P2)

**Independent test**: probe rows L1-L7.

- [ ] T014 [US2] Drop-down filled from `IDS_UPDATE_LEVEL_*`, selected = stored level, enabled by eligibility + check box; change → `UpdInstall_SetLevel`, `UpdInstall_OnSettingsChanged`, post `WM_USER_UPDATENOTICE_LEVEL` in `src/upddlg.cpp`
- [ ] T015 [US2] `WM_USER_UPDATENOTICE_LEVEL` handler in `src/mainwnd3.cpp` applying `SalUpdNoticeLevelChange` (flow / classic / automatic)
- [ ] T016 [US2] Layout: the new rows span the button row like the other texts (`ApplyForm`) in `src/upddlg.cpp`

## Phase 6: User Story 3 - Copy not installed by the installer (P2)

**Independent test**: probe row P1.

- [ ] T017 [US3] Not eligible → no Download & Install, drop-down disabled, hint `IDS_UPDATE_HINT_PORTABLE` in `src/upddlg.cpp`

## Phase 7: Polish & cross-cutting

- [ ] T018 Build, saltests, encoding guard
- [ ] T019 Probe `specs/421-update-notice-levels/probe/notice421_probe.ps1` (rows L, D, P, A, R) on the hidden desktop; results in `probe/result_after.txt`
- [ ] T020 Translations: two-stage `.slt` refresh of `salamand` (stop-rules §2.13), pins, `slt --verify`, `build.cmd full`
- [ ] T021 Manual: `help/src/hh/salamand/othertask_newversion.htm`, `configuration_gener.htm`
- [ ] T022 `PRIVACY.md` (notify level: downloads on Download & Install; automatic level: installs as soon as downloaded) and 420's contract note in `specs/420-auto-update-install/contracts/ui.md` pointing to 421
- [ ] T023 `CHANGELOG.md` entry under `## [Unreleased]`

## Dependencies

Phase 2 before all stories. US1 and US4 both use T004; US2 (T015) uses the flows of US1/US4; US3 is small and independent. Polish last.

## Parallel opportunities

T002/T003 with T005/T006 (different files). Within stories the files overlap (`upddlg.cpp`, `mainwnd3.cpp`) - sequential.

## Implementation strategy

MVP = Phase 2 + US1 + US4 (the maintainer's two main requests); then US2, US3, polish.
