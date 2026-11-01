---
title: Change Drive menu and drive bar have no WSL item for the Linux distributions
type: feature
status: in-progress
severity: 3
area: panels-ui
source: manual
who: both
created: 2026-11-01
updated: 2026-11-01
verified: 2026-11-01 30268b7c
effort: M
feature: 374
related: []
depends-on: []
reason: -
---

# Change Drive menu and drive bar have no WSL item for the Linux distributions

## Problem

A user who works with WSL has no quick way to open the Linux file systems. The Change Drive menu (Alt+F1 / Alt+F2) and the drive bar list drives, Documents, cloud storages and Network. Nothing in them leads to `\\wsl.localhost`, the root Explorer shows as the *Linux* node. The user has to type `\\wsl.localhost\<distro>` in Change Directory. Wanted: a WSL entry, shown only when the computer has WSL distributions, with a fitting icon, that opens `\\wsl.localhost` (or one distribution) directly.

## Evidence

All by reading at de1e2dd7; nothing measured in the program.
- `src/drivelst.cpp:2797-2869`, `CDrivesList::BuildData`: the optional groups of the list. Cloud storages are behind `Configuration.ChangeDriveCloudStorage` (L2799). OneDrive gives the pattern for several targets (L2818-2852): with more than one storage the drive bar gets one drop-down button `drvtOneDriveMenu` (L2829-2834), and the Alt+F1 menu gets one item per storage (`drvtOneDrive`, `drvtOneDriveBus`, L2835-2852). Network (`drvtNeighborhood`) is behind `Configuration.ChangeDriveShowNet` and the NoNetHood policy (L2863-2869).
- The options are declared at `src/cfgdlg.h:400-401`, defaulted at `src/dialogs4.cpp:472-473`, shown at `src/dialogs5.cpp:3373-3374` (`IDC_CHD_SHOWNET`, `IDC_CHD_SHOWCLOUDSTORAGE`), saved and loaded at `src/mainwnd2.cpp:2151-2155` and `:3815-3819`, and imported at `src/cfgimport.cpp:1506-1507`. A WSL option would touch the same places.
- Item types are in `src/drivelst.h:69-70`. Executing them: `CFilesWindow::ChangeDrive` in `src/fileswn3.cpp:2730-2757` and `CDriveBar::Execute` in `src/toolbar6.cpp:168-173`. Cloud items change the path straight away (`ChangePathToDrvType`, fileswn3.cpp:2735). Network does not open a path: it opens the folder picker `GetTargetDirectory` (fileswn3.cpp:2746-2756). A WSL item would change the path directly, like the cloud items.
- `src/` has no reference to WSL, `Lxss`, `wsl.localhost` or `wsl$` (Grep at de1e2dd7).
- `\\wsl.localhost` itself gives no share list today (error 53 skips the `WNetOpenEnumW` fallback), measured in `wsl-localhost-offers-no-share-list`. With the provider fallback, `WNetOpenEnumW` lists `\\wsl.localhost\docker-desktop` and `\\wsl.localhost\Ubuntu` from the *Plan 9 Network Provider* (measured there on 2026-11-01).

## Expected

On a computer with at least one WSL distribution, the Alt+F1 / Alt+F2 menu and the drive bar show a WSL entry with an icon. Choosing it opens `\\wsl.localhost` (or the chosen distribution) in the panel. On a computer without WSL the entry is absent. Building the list does not start WSL or its VM and does not add a noticeable delay to Alt+F1 (measured before and after). An option on the Change Drive page of the configuration hides the entry, saved and imported like `ChangeDriveShowNet`. The new texts are in every enabled language (two-stage `.slt` refresh done).

## Log

- 2026-11-01 — created (source manual)
- 2026-11-01 — moved to Next position 89
- 2026-11-01 — moved to Next position 3
- 2026-11-01 — verified at 30268b7c: still present at 30268b7c: BuildData adds no WSL entry, src has no Lxss/wsl.localhost reference outside 372/373; machine has Ubuntu and docker-desktop in HKCU Lxss
- 2026-11-01 — run started, feature 374
