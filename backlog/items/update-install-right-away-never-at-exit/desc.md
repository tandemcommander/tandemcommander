---
title: Updates install right away with a restart, never when Tandem Commander closes
type: improvement
status: in-progress
severity: 5
area: privacy-security
source: manual
who: both
created: 2026-11-08
updated: 2026-11-08
verified: 2026-11-08 95dc740e
effort: M
feature: 422
related: []
depends-on: []
reason: -
---

# Updates install right away with a restart, never when Tandem Commander closes

## Problem

Testing 421 on the installed copy (2026-11-08), the maintainer chose the automatic level and the installer did not start while the program ran; the update was installed only when the program was closed (setup log: `/VERYSILENT ... /NORESTARTAPPLICATIONS /ALLUSERS` at 19:48). The automatic level of 421 waits for 30 s without keyboard or mouse input before it starts, which in practice rarely happens while the user works, and 420's install at the exit then takes over. The maintainer does not want installation at exit at all: an update should be installed while the program runs - the program closes, the installer runs with its progress window, and the program starts again.

## Evidence

At 3e16a7b4:

- Idle wait: `SalUpdSilentInstallDecision` (`src/common/salupdinstall.h`, `SALUPD_SILENT_IDLE_MS` 30000) called from `CMainWindow::TrySilentUpdateInstall` (`src/mainwnd3.cpp`).
- Exit install: `UpdInstall_PrepareExit` / `UpdInstall_RunAtExit` (`src/updinstall.cpp`, kind `sulkExit`: `/VERYSILENT /NORESTARTAPPLICATIONS`), decided by `SalUpdExitDecision`; called from `src/salamdr1.cpp` after the main message loop.
- *Install When I Close* button (`IDC_UPDN_INSTALLEXIT`, `IDS_UPDATE_BTN_INSTALLEXIT`, `UpdInstall_ArmByClick`) on the offer form (`src/upddlg.cpp`).
- The question after a failed *Install Now*: `IDS_UPDATE_INSTALL_LATER` "Do you want to install it when you close Tandem Commander?" in `UpdInstall_OnInstallerEnded` (`src/updinstall.cpp`).
- Maintainer's machine: `HKCU\Software\Tandem Commander\Settings\Update Check` after the test - `Update Level 2`, `Install Launches 2`, `Install Confirmed 1`, `Install Test 1`; `%LOCALAPPDATA%\Tandem Commander\Updates\setup-0.2.0.log` shows the exit command line.

## Expected

Maintainer decisions of 2026-11-08 (asked in the session):

1. **Automatic level - install right away**: as soon as the installer is downloaded and verified, the installation starts (as *Install Now*: the program closes, the installer runs with its progress window, the program starts again) without waiting for the user to be idle. It still never starts while something can be lost (no file operation or search running, no modal dialog or menu, no archive edits waiting, no plug-in file system, nothing typed in the command line, no Quick Rename, no other instance, no installer running); then it waits in the running session and starts as soon as that has ended.
2. **No installation at exit, anywhere**: the exit never starts an installer (420's `PrepareExit` / `RunAtExit` exit install is removed); the *Install When I Close* button is removed from the offer form (*Install Now*, *Remind Me Later*, *Skip This Version* remain); the question "install it when you close?" after a failed *Install Now* is removed (the failure is reported; the update stays offered).
3. An update planned by the automatic level that was not installed while the program ran (the program was closed first, Windows shut down) is installed at the next start right away (420's start-up completion: the program closes, installs, starts again).
4. 420's protections stay: the launch count (a plan whose installer ran and did not install it is only offered, never started on its own again), a skipped version is never installed on its own, a copy not installed by the installer never updates itself, one installer at a time, test mode.
5. Manual, `PRIVACY.md`, the 420/421 contracts and the translations updated; probes of 420/421 adjusted (exit rows replaced by rows proving that the exit never starts an installer).

## Approach

Remove the idle condition from the silent decision (keep `DecideCloseApp` + the typing guard + last instance + installer running). Remove the exit route (`UpdInstall_PrepareExit` / `RunAtExit`, `SalUpdExitDecision`, the `sulkExit` launch kind if unused), the button and its strings, the Yes/No question (a failed launch of the automatic plan becomes OFFERED as 421's `SalUpdDeclinedArmKept`). Keep the start-up completion for an automatic plan never launched (susaComplete). An arm of source *user* left by 0.2.x / 420 builds (Install When I Close) is completed at the next start the same way. Measure first on the build: the automatic level with a busy user starts nothing until exit today.

## Notes

Source: the maintainer's report and answers in the session of 2026-11-08 (questions: when to install at the automatic level -> "right away, no waiting"; installation at exit -> "remove completely"). Severity 5: the automatic level does not do what it promises in practice, and the exit install is unwanted. A person's part: the real UAC prompt and the restart on the real desktop for the immediate install and for the start-up completion.

## Log

- 2026-11-08 — created (source manual)
- 2026-11-08 — moved to Next position 1
- 2026-11-08 — maintainer decision 2026-11-08: the automatic level installs right away without an idle wait; installation at exit is removed completely (Install When I Close, the question after a failed Install Now, the automatic fall-back)
- 2026-11-08 — verified at 95dc740e: still true at 95dc740e: probe 421 rows A2/L2 (user busy: nothing starts, the exit installs) and R1 (Install When I Close, exit install); exit route in salamdr1.cpp
- 2026-11-08 — run started, feature 422
