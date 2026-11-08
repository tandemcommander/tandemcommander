# Fix log - 422 updates install right away with a restart, never at exit

Backlog item `update-install-right-away-never-at-exit` (maintainer decisions 2026-11-08). Branch
`422-install-now-not-at-exit`, from `main` at 95dc740e.

## Measurement before (95dc740e)

- Probe 421 on the same code (3e16a7b4): A2 / L2 - level 2 with the user working: nothing starts while
  the program runs, the exit installs (`exit|... /VERYSILENT ... /NORESTARTAPPLICATIONS`); R1 - *Install
  When I Close*, then the exit install.
- The maintainer's machine after the test: `Install Launches 2`, `Install Confirmed 1`, setup log of
  19:48 with the exit command line `/VERYSILENT ... /NORESTARTAPPLICATIONS /ALLUSERS`.

## Maintainer requirements during the run (2026-11-08)

1. "A logical trap": the automatic install started, its installer closed the program, the user cancelled
   it and started the program again - it must NOT start again (the user would be locked out). Spec US4 /
   FR-007, probe group T.
2. Help > Check for New Version at the automatic level must always show the notification with the
   install option, never install on its own; the full automatic install only after the start-up check.
   Spec FR-009, probe A7 / A8 (also the About box's *Check now*, and a level chosen in the notification).

## Implementation

- `src/common/salupdinstall.h`: `SalUpdSilentInstallDecision` without the idle parameters;
  `SALUPD_SILENT_IDLE_MS`, `SalUpdExitDecision`, `SalUpdExitArmAvailable`, the launch kind `sulkExit`
  removed; `SalUpdNoticeLevelChange`: offer + automatic = stored only (`sulchAutomatic` removed).
- `src/updinstall.*`: `UpdInstall_PrepareExit` / `UpdInstall_RunAtExit` (and the exit state),
  `UpdInstall_CheckReady`, `UpdInstall_ArmByClick`, `UpdInstall_ExitArmAvailable`, `UpdiConfirmArm`,
  `UpdInstall_SilentIdleNeededMs` (+ seam `TC_UPDATE_PROBE_IDLE_MS`) removed; `UpdInstall_OnInstallerEnded`
  reports with OK only and keeps an automatic plan OFFERED (`SalUpdDeclinedArmKept`).
- `src/salamdr1.cpp`: the two exit calls removed.
- `src/mainwnd3.cpp`: `ShowDownloadedUpdate(..., userAsked)` - the automatic install only for the
  background check; a flow the user started (Help, About, the notification's level) shows the offer and
  ends a waiting silent install of that version (`UpdateSilentLeaveToUser`); `TrySilentUpdateInstall`
  without idle; the level choice offer -> automatic only stores it.
- `src/upddlg.cpp`, `src/lang/lang.rc/.rh`, `src/lang/texts.rc2`, `src/texts.rh2`: *Install When I Close*
  (`IDC_UPDN_INSTALLEXIT`, `IDS_UPDATE_BTN_INSTALLEXIT`) and `IDS_UPDATE_INSTALL_LATER` removed.
- Manual (General page, new-version page), `PRIVACY.md`, notes in the 420 / 421 UI contracts.

## The lock-out trap - why it holds

The launch is counted before the installer starts (`UpdInstall_InstallNow` arms source *user* with
Launches+1, ConfirmedAt unchanged). An installer that closes the program and is cancelled leaves
`Launches > ConfirmedAt`: the start decides `susaOffer` (marked offered), `SalUpdSilentInstallPlanned` is
FALSE for it, and a new check finds it not plannable (`SalUpdAutomaticArmUsable` keeps an offered plan
offered). saltests: the trap group in `TestUpdateNotice421`; probe T1 (silent install), T2 (start-up
completion), T3 negative control (the count reset by hand: it IS started - the count is the protection).

## Checks

- `build.cmd` / `build.cmd full` → BUILD SUCCEEDED.
- `saltests` → `287230 checks, 0 failed` (421: 287,248; the exit-decision and exit-arm checks removed,
  the trap checks added).
- Probe `probe/install422_probe.ps1` (hidden desktop, 420's fixture server on port 8422):
  **58 PASS / 0 FAIL / 0 NOT DRIVEN**, registry restored identical (`probe/install422_result.txt`).
  - Probe iterations: group F's copy did not open while command-line text was set, and later opened in
    the inactive panel (the active panel depends on activation with two instances) - the file is now in
    both panels and a second instance holds the install while the copy is set up. T1's start without a
    due check shows no window (the offered update is announced by the next check, as 420 does) - the
    spec's wording was made exact.
- Translations: 0 gaps; the merge removed exactly the button row and the two strings in every enabled
  language (3 rows each); pins of the removed strings dropped (`_feature_422`); `slt --verify`
  byte-exact.
- Encoding guard → `TOTAL: 0 finding(s)`.

The maintainer's own `%LOCALAPPDATA%\Tandem Commander\Updates` files were moved to
`%TEMP%\tc422_updates_backup` (SHA-256 recorded) for the probe runs and are moved back at the end.
