# Fix log - 421 update notification: level choice, Download & Install, silent automatic install

Backlog item `update-level-and-download-install-in-notification`. Branch `421-update-notice-levels`,
started from `main` at 1a25a164.

## Measurement before (1a25a164)

By reading (the item's *Evidence*, all still true at HEAD):

- `src/upddlg.cpp` `CUpdateNoticeDialog::ApplyForm`: three forms (classic / offer / automatic); the
  classic form has only *Download* (browser), *Remind Me Later*, *Skip This Version*; the only setting
  in the window is the check box `IDC_UPDN_ATSTARTUP`.
- The level is changed only on Configuration > General (`src/dialogs4.cpp`, `IDC_UPDATELEVEL`).
- `SalUpdAfterCheck` gives `suacNotify` for `sulNotify` - the notify-only level never downloads.
- `ShowDownloadedUpdate` (`src/mainwnd3.cpp`) at level 2 arms the update for the exit and shows the
  `unfAutomatic` form (OK / Install Now / Skip); the installer runs only at a normal exit or at the next
  start.
- On the maintainer's machine the installed copy (`C:\Program Files\Tandem Commander`, 0.2.0 of
  2026-10-25) predates 420; the 420 build in `build\tandemcommander\Release_x64` run with `--updatetest`
  is not eligible (no uninstall entry names its folder) and so shows the classic form at every level -
  the misreading that started the item.

## Decisions (research.md)

- R1 silent install moment: `SalUpdSilentInstallDecision` - automatic plan without an unconfirmed
  launch, last instance, no product installer running, `DecideCloseApp() == scadAgree`, 30 s without
  input (not after a check the user asked for), once per session per version.
- R2 launch: `UpdInstall_InstallNow` for both new routes (the tested route of 420).
- R3 Download & Install downloads also on a metered connection (a click).
- R4 level change on the open window: `SalUpdNoticeLevelChange`.
- R5 strings 14007-14012 (bundle 875), `IDS_UPDATE_LEVEL_AUTO` changed, `IDS_UPDATE_HINT_AUTO` /
  `IDS_UPDATE_BTN_OK` removed; the automatic form removed.

## Implementation

- `src/common/salupdinstall.h`: `SalUpdDownloadInstallOffered`, `SalUpdNoticeLevelChange`,
  `SalUpdSilentInstallPlanned`, `SalUpdSilentInstallDecision` (+ `SALUPD_SILENT_IDLE_MS`).
- `src/saltests/saltests.cpp`: `TestUpdateNotice421` (+50 checks).
- `src/updinstall.*`: per-request metered bypass, progress counter, cancel of a download, the Download &
  Install request, wrappers (refused, installer running, last instance, verified), the idle seam
  `TC_UPDATE_PROBE_IDLE_MS` (Debug only).
- `src/upddlg.*`: level drop-down, Download & Install / Cancel Download with progress, portable hint,
  `unfAutomatic` removed.
- `src/mainwnd.h`, `src/mainwnd3.cpp`: silent install wait (`IDT_UPDATEAUTOINSTALL`), the request taken
  at the end of the download, `WM_USER_UPDATENOTICE_LEVEL`.
- `src/lang/lang.rc/.rh`, `src/lang/texts.rc2`, `src/texts.rh2`, `src/consts.h`.

## Checks

- `build.cmd` → BUILD SUCCEEDED.
- `saltests` → `287240 checks, 0 failed` (420's closing: 287,190).
