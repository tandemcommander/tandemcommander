# Implementation Plan: Updates install right away, never at exit

**Branch**: `422-install-now-not-at-exit` | **Date**: 2026-11-08 | **Spec**: [spec.md](spec.md)

## Summary

1. `SalUpdSilentInstallDecision` loses its idle parameters: *now* when the plan is the automatic
   level's, never launched since planned or confirmed, honoured, eligible, the last instance, no
   installer running, the close rule agrees and nothing is typed. `SALUPD_SILENT_IDLE_MS`,
   `UpdInstall_SilentIdleNeededMs`, the seam `TC_UPDATE_PROBE_IDLE_MS` and the "user asked" flag are
   removed. The notification blocks the silent install only while its level list is open
   (`UpdateNotice_IsChoosing`).
2. The exit install is removed: `UpdInstall_PrepareExit` / `UpdInstall_RunAtExit` (and their calls in
   `salamdr1.cpp`), `SalUpdExitDecision`, the launch kind `sulkExit` (`SalUpdBuildInstallerArgs` keeps
   only the *now* command line), `UpdiExitNotNormal` / `UpdiExitHeld`.
3. *Install When I Close* is removed: `IDC_UPDN_INSTALLEXIT` (dialog, layout), `IDS_UPDATE_BTN_INSTALLEXIT`,
   `UpdInstall_ArmByClick`, `UpdInstall_CheckReady`, `UpdInstall_ExitArmAvailable`,
   `SalUpdExitArmAvailable`, the forced reshow of round 4.
4. `UpdInstall_OnInstallerEnded`: the plan from before is restored (420 round 4), an automatic plan is
   kept OFFERED (`SalUpdDeclinedArmKept`), the failure is reported with OK only;
   `IDS_UPDATE_INSTALL_LATER` removed; `UpdiConfirmArm` remains only where a start fails before anything
   ran (420 round 6) - check its callers.
5. The start-up completion (`susaComplete`) and the launch-count protection (`susaOffer`, used-up
   launches) stay; the lock-out trap (maintainer) is proven by probe rows: kill after the silent launch /
   after the start-up completion's launch, then start again two or three times (with a check): no
   installer, the offer.

## Technical Context

C++20, WinAPI, MSVC v143; saltests; hidden-desktop probe `specs/422-install-now-not-at-exit/probe/install422_probe.ps1`
(derived from 421's, same fixture server and seams). No new stored value; the meaning of the stored
plan stays (sources user / automatic / offered).

## Constitution Check

I-VI PASS: no new dependency; stored values unchanged (an old user plan is completed at the next start);
pure rules tested; WinAPI; no plug-in change; strings removed from existing bundles (no bundle removed),
translations refreshed.

## Structure

`src/common/salupdinstall.h`, `src/saltests/saltests.cpp`, `src/updinstall.h/.cpp`, `src/upddlg.h/.cpp`,
`src/mainwnd.h`, `src/mainwnd3.cpp`, `src/salamdr1.cpp`, `src/lang/lang.rc/.rh`, `src/lang/texts.rc2`,
`src/texts.rh2`, `help/src/hh/salamand/*.htm`, `PRIVACY.md`, translations, contracts note.
