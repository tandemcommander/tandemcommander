---
title: Update notification: level choice, Download & Install, silent automatic install
type: improvement
status: in-progress
severity: 4
area: privacy-security
source: manual
who: both
created: 2026-11-08
updated: 2026-11-08
verified: 2026-11-08 1a25a164
effort: L
feature: 421
related: [new-version-check-123-person-steps]
depends-on: []
reason: -
---

# Update notification: level choice, Download & Install, silent automatic install

## Problem

When the new-version notification appears, the user cannot change how updates are handled there: the three update levels of feature 420 (notify me only / download and offer / install automatically when the program closes) are offered only in Settings, where the maintainer found them too hidden while testing 420 with `--updatetest` (2026-11-08). The notification shows only the check-at-startup check box. In addition, the notify-only level's notification (feature 123's classic form) offers only *Download*, which opens the installer's address in the browser; the user then has to find, run and confirm the installer by hand, although the program can download, verify and install it itself (420).

Third (maintainer, same day): at the automatic level the notification only says that the update will install itself when the program closes. That window is redundant - it is in effect the offer level with one button fewer - and the automatic level is not fully automatic, because the update waits for the exit. The maintainer wants the automatic level to show no notification and to start the installation as soon as the installer is downloaded and verified.

## Evidence

At ec0820b4, by reading:

- `src/upddlg.cpp` `CUpdateNoticeDialog::ApplyForm` (~215): the forms `unfClassic` / `unfOffer` / `unfAutomatic` (`src/upddlg.h` ~52); the classic form keeps the template's *Download* / *Remind Me Later* / *Skip This Version*.
- `src/upddlg.cpp` `WM_COMMAND` `IDOK` (~576): on the classic form *Download* only opens `SalUpdInstallerUrl` in the browser (`UpdateCheck_OpenUrl`); `IDC_UPDN_ATSTARTUP` (~645) is the only setting in the window, written at once.
- The level is chosen only in Configuration (`src/dialogs4.cpp` ~870-886, `UpdInstall_GetLevel` / `UpdInstall_SetLevel`, stored value `Update Level`, `src/updinstall.cpp` ~100).
- After a check, `SalUpdAfterCheck` (`src/common/salupdinstall.h` ~72) gives `suacNotify` for level `sulNotify`, so the download path of 420 (`UpdInstall_AfterCheck`, `src/updinstall.cpp` ~1538) is never taken at that level.
- The automatic level: `ShowDownloadedUpdate` (`src/mainwnd3.cpp` ~748) arms the update for the exit (`UpdInstall_Arm(release, SALUPD_ARM_AUTOMATIC)`) and shows the `unfAutomatic` form (OK / Install Now / Skip, `ApplyForm` ~228-249); the installer runs at a normal exit (`SalUpdExitDecision`, `src/updinstall.cpp` ~1788) or at the next start (`UpdInstall_OnStartupComplete` ~1576). An immediate install already exists as *Install Now* (`UpdInstall_InstallNow`).
- Source: the maintainer's requests in the session of 2026-11-08 while testing 420.

## Expected

1. The notification window lets the user change the update level (the same three choices and the same stored value as Settings, written at once like the check-at-startup check box); a change takes effect for the notification on screen where it can (for example, choosing the automatic level on the offer form arms the update the way 420 arms it), and lowering the level drops an automatic arm (`UpdInstall_OnSettingsChanged`).
2. The notify-only form offers *Download & Install*: the program downloads the installer itself with 420's download and verification (published digest, signer pin, version resource), then starts it as *Install Now* does; while it downloads the window shows progress and can be cancelled; a failed download or verification falls back to the browser *Download* with a message.
3. On a copy that the installer did not install (portable copy, build tree; `UpdInstall_IsEligible` is FALSE) neither the level choice nor *Download & Install* pretends to work: the window says that this copy updates only through the browser download.
4. The automatic level shows no notification: when the installer is downloaded and verified, the installation starts at once (as *Install Now*, the program closes and restarts after the update) - but only when nothing can be lost: no file operation, search or plug-in work in progress, no unsaved edit, the program not busy (`CMainWindow::DecideCloseApp`). Otherwise it waits until that is so, and the exit / next-start install of 420 stays as the fall-back. The level's name and description in Settings (and in the notification's level choice) say "installs as soon as it is downloaded". A skipped version is never installed on its own (420 round 4).
5. The probes of 420 cover the new controls and the silent automatic install; translations refreshed; `PRIVACY.md` updated if the wording about when the installer is downloaded changes.

## Approach

Reuse 420's download worker (`UpdiStartDownload`) and the `WM_USER_UPDATEDOWNLOAD_DONE` path; the click is the user's explicit consent, so the metered-connection rule may let it through (decide and record). The level control could be a combo box or a link to a small menu under the buttons; keep the button row width rules of `ApplyForm` (translations). Measure first: which form shows for each level and eligibility with `--updatetest`.

The silent automatic install: decide what the user sees - the program closing on its own under the user's hands is the risk (a click or typing into a window that disappears, an all-users installation raising a UAC prompt out of nowhere; a declined prompt must not repeat at every start - 420's launch count). Options to weigh: start it only when the program has been idle for a while, or after a short non-modal countdown with *Postpone*; a declined or failed launch falls back to the exit install. The 420 contracts (`specs/420-auto-update-install/contracts/`) and the `unfAutomatic` form change accordingly.

## Notes

The trigger was a misreading while testing 420: the maintainer ran the build tree with `--updatetest` and saw only the classic notification at every level, because a copy not installed by the installer is never eligible (420 R5/M8, by design). Point 3 of *Expected* closes that confusion. Severity 4: a usual request, the work-around is Settings and the browser download. A person's part: a real UAC prompt for an all-users update started from *Download & Install* and by the silent automatic install, and the restart on the real desktop. `PRIVACY.md` describes when the installer is downloaded and run - check its wording in the same change.

## Log

- 2026-11-08 — created (source manual)
- 2026-11-08 — extended: the automatic level shows no notification and installs as soon as the installer is verified (maintainer 2026-11-08)
- 2026-11-08 — moved to Next position 1
- 2026-11-08 — verified at 1a25a164: still true at 1a25a164 by reading: upddlg.cpp has no level control, classic form has only browser Download, ShowDownloadedUpdate shows unfAutomatic and arms for the exit
- 2026-11-08 — run started, feature 421
