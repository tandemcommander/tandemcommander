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

## Review 1 (refute-first agent)

| # | Finding | Done |
|---|---|---|
| M1 | A click's install (Install Now after Help > Check at the automatic level, Download & Install) whose installer ended without installing while the program ran dropped the plan; the next background check re-planned it and the silent install started it again on its own - reproduced (row Z1) | `SalUpdArmAfterInstallerFailed`: the launched plan is kept OFFERED with its count (an automatic plan offered, another restored plan as it is); saltests incl. a negative control; probe T4 (the reviewer's Z1) PASS |
| N1 | `--updatetest` re-installs after a killed test install | accepted: a test plan launched counts as done; the switch never reaches a restart, a user cannot be locked out |
| N2 | A launch that fails to start retries at the next starts (1 message each), capped at 3 | accepted: no process ran, the program was never closed |
| N3 | The launch count was not verified before the installer starts | `UpdiLaunch` stores Launches+1, reads it back, and refuses to start the installer otherwise |
| N4 | A newer release gets one automatic attempt after a cancelled older one | accepted: per version, no loop |
| N5 | Remind Me Later on a user's check while a background plan exists: the next start installs it (FR-006) | accepted: as specified |
| N6 | Spec assumption (level list) vs code (notification in the foreground) | the code's rule is the safer one - kept; T003's `UpdateNotice_IsChoosing` was not needed |
| N7 | Stale comments mentioning the exit / Install When I Close | refreshed |
| N8 | FEATURE-HISTORY | written at closing |

After review 1: saltests `287236 / 0 failed`; probe **59 PASS / 0 FAIL**.

## Review 2 (refute-first agent, fresh)

No MUST. Both maintainer requirements verified route by route (silent install, start-up completion; Help,
About, the level choice), with a negative control in a worktree (M1 reverted + the offer rule disabled:
`287054 checks, 9 failed`).

| # | Finding | Done |
|---|---|---|
| S1 | Without the idle wait, an open Find window (typed criteria, the results of a finished search) is closed by the installer - `DecideCloseApp` lets an idle Find window go; reproduced (row Z1) | an open Find window holds the automatic install like command-line text; probe F4 (the reviewer's Z1): held, starts after Find is closed - PASS; manual / `PRIVACY.md` list it |
| N1 | Turning the check off (offered plan and file deleted) or deleting the installer from outside gives one more automatic attempt later | accepted: a user action resets it, no loop |
| N2 | Probe X1 could never fail (every launch reads "now") | `QuitChecked` counts any installer started by an exit |
| N3 | Stale comments | refreshed (`salupdinstall.h`, `updinstall.cpp/.h`, `upddlg.h`) |
| N4 | The review-1 section of this log was not committed yet | committed with this round |

After review 2: saltests `287236 / 0 failed`; probe **61 PASS / 0 FAIL / 0 NOT DRIVEN**.

The maintainer's own `%LOCALAPPDATA%\Tandem Commander\Updates` files were moved to
`%TEMP%\tc422_updates_backup` (SHA-256 recorded) for the probe runs and are moved back at the end.
