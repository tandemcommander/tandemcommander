# 246 — Quickstart: validating the feature

## Prerequisites

- Debug x64 build: `build.cmd` (from the repository root); `saltests` built with it.
- The administrative share `\\localhost\C$` reachable (it is on the maintainer's machine).
- Free drive letters (the probe picks from W:, V:, U:, T:).
- Back up the product's registry key and restore it afterwards (probes share it).

## 1. Pure rules

```
%OPENSAL_BUILD_DIR%\...\saltests.exe        → exit code 0; TestNetDrive246 checks pass
```

Contract: [contracts/salnetdrive.md](contracts/salnetdrive.md).

## 2. GUI probe (hidden desktop)

`probe/run246.ps1` (run through `tools/run_on_hidden_desktop.ps1`) creates temporary
mappings to folders under `%TEMP%\tc246\` via `\\localhost\C$\…`, names some of them the
way Explorer does (`_LabelFromReg`), starts `tandemcommander.exe` with the drive bar shown,
and reads:

- the Change Drive menu texts (menu item texts read from the owner-drawn menu through the
  probe's text dump, or screenshots checked by an agent),
- the drive bar icons (the bar's image list compared to imageres 31 / 33),
- the tooltip text,

for the matrix: unnamed / named ASCII / named `Archiv Test ž` / Cyrillic / CJK / `&` /
`#` / long path / renamed while running; connected → unavailable (cancel without
updating the profile) → connected again, with a window activation between steps.

Expected outcomes: [contracts/drive-ui-text.md](contracts/drive-ui-text.md); the baseline
build (0.1.10 tree) is the negative control: unnamed texts identical, named drives without
name, stale bar icon after the state change.

Cleanup: every mapping, remembered connection, `MountPoints2` key and folder created is
removed and the removal verified (compare with the snapshot taken before).

## 3. Person steps (cannot be driven here)

- A real SMB/Samba server: map a drive, switch the server off; within Tandem Commander
  activate the window → the drive bar shows the disconnected icon; the menu likewise.
  Switch it on, pick the drive → it opens.
- Keyboard (real Alt+F1 typing) and visual check of the menu on a real desktop.
