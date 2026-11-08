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

## Probe and the defect it found

`probe/notice421_probe.ps1` (hidden desktop, 420's fixture server on port 8421, Debug seams; new
Debug seams `TC_UPDATE_PROBE_IDLE_MS` and `TC_UPDATE_PROBE_SILENTLOG`).

- First full run: D 17/17, P/L/R pass, but **every silent install row failed** (A1, A3, A4, A7, L3):
  the decision log showed `close=decline: busy` on every look. Cause: `SalamanderBusy` is set to TRUE
  for the dispatch of **every** message in the main loop (`salamdr1.cpp`, only a few messages are
  exempt) - a `DecideCloseApp()` called from a `WM_TIMER` handler always sees the program busy; 080
  calls it only from `WM_QUERYENDSESSION`, one of the exempt messages. Fix (attempt 1 of the check):
  the timer only sets `UpdateSilentDue`; the decision runs in the idle part of the main loop after
  `CannotCloseSalMainWnd` is cleared (`!SalamanderBusy`), where no command and no modal loop runs.
- Second run: all pass but A4. Diagnosis (decision log, window list, posted About command, CPU):
  the probe's fault - the first instance decided its start-up check only after its start-up was
  complete, after the probe had already removed `Last Attempt`; that instance did the check and
  waited (not the last instance), and the probe then closed it. Fix in the probe: wait 6 s before
  removing the stored attempt. Then A4 passed (the second instance waits while the first runs, and
  installs once it is closed).
- D2 strengthened: the per cent shown must rise monotonically to at least 50 (seen
  0,7,14,...,93,100).
- **Final: 45 PASS / 0 FAIL / 0 NOT DRIVEN, registry restored (identical SHA-256)** -
  `probe/notice421_result.txt`.

The maintainer's own `%LOCALAPPDATA%\Tandem Commander\Updates` held the files of their manual test
of the day (the 0.2.0 installer and its setup log); the probe refuses a non-empty folder. They were moved
to `%TEMP%\tc421_updates_backup` (SHA-256 recorded) for the probe runs and moved back afterwards.

## Translations (stop-rules 2.13)

- Entries (step 0): new strings 14007-14012; changed `IDS_UPDATE_LEVEL_AUTO` (14098); removed
  14152 / 14154; `IDD_UPDATENOTICE`: new controls 6299 (label), 6300 (drop-down), 6301 (button), taller.
- Step 2: `STRINGTABLE:153:14098` set to `english_fallback` in the 8 enabled languages.
- Dry run: 8 unique gaps per language (~660 chars) = the 6 strings, 14098, the label.
- Merge: `DeepL characters sent this run: 5,832`, 0 validation failures; no layout drift outside
  the notification (15 changed rows per language).
- Read-back (step 5) found: the button `Download && &Install` scrambled in every language (dutch
  `&-&&installatie`, hungarian `Letöltés &&& Telepítés`); 14098 still the OLD meaning because 420's
  pin of `IDS_UPDATE_LEVEL_AUTO` won; button names in the hints not matching the buttons (de / nl
  `Herunterladen` / `Downloaden` vs the `Download` button); access-key clashes (hu Cancel `&L` =
  Download, es Cancel `&C` = check box, sk `&n` = Remind Me Later); de progress text with an article;
  fr / es label not the General page's label. All pinned in `translations/ui-overrides.json` with a
  `_feature_421` note list; the pins of the removed `IDS_UPDATE_HINT_AUTO` (cs, hu) dropped.
- Merge again: 0 gaps; read-back clean; `translate.slt --verify` → round-trip byte-exact (298 files).

## Checks

- `build.cmd` → BUILD SUCCEEDED.
- `saltests` → `287240 checks, 0 failed` (420's closing: 287,190).
- Encoding guard → `TOTAL: 0 finding(s)`.
