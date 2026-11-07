# Fix log - 417 Fluent 2 icons for the plug-ins; Appearance group renamed to Icon style

Backlog item `fluent-2-icons-for-the-plug-ins-appearance-group-renamed-to`. HEAD0 `e5d4552e` (main = 416 merged).

## Measurement before (step 3, on main)

- Build: `build\tandemcommander\Debug_x64` of 416 (the tree of main).
- Script `probe\measure_plugins.ps1` on the hidden desktop
  (`tools\run_on_hidden_desktop.ps1`), registry backed up / restored (SHA-256 identical):
  "Show Plugins Bar" = 1, "Toolbar Icon Set" 0 (Fluent 2) vs 1 (Classic), Theme Mode 0 / 1; the rows of the
  top rebar captured with PrintWindow (row 0 menu, 1 Plugins bar, 2 drive bar, 3 top toolbar), result
  `probe\result_measure_before.txt`, captures `probe\captures_measure\`.
- Result, both themes: **Plugins bar Fluent 2 vs Classic 242 px** - only the 416 drop-down chevrons; every
  plug-in icon is the same old bitmap. Drive bar 3723 / 3836 px - only the drive icons; the plug-in
  file-system buttons (FTP, Desktop = Folders, Portables, RegEdit, SFTP, Undelete) are the same. Top toolbar
  1057 px (the 416 set). The gap is present.
- Side finding: **SFTP has no icon at all** - its `Connect` (`src/plugins/sftp/sftp.cpp`) calls
  `SetChangeDriveMenuItem` / `SetPluginIcon(0)` but never `SetBitmapWithIcons`, so `PluginIcons` stays
  NULL: the Plugins bar and the Plugins manager show `IDI_PLUGIN`, the drive bar `IDI_PLUGINFS` (visible in
  `captures_measure\t0_set1_bar1.png` / `_bar2.png`). Severity 2. In Fluent 2 the set icon covers it; in
  Classic it is kept (FR-008: Classic pixel-identical; the bitmap it would hand over is the FTP look-alike).

## Sites (enumerated at HEAD0, grep `PluginIcons`, `PluginIconIndex`, `ChDrvMenuFSItemIconIndex`,
   `IDI_PLUGIN`, `IDI_PLUGINFS`, `GetFSIcon(`)

| Site | File | Today |
|---|---|---|
| Plugins bar, Plugins menu + submenus, plug-in lists in menus, View With, Plugins manager | `CPlugins::CreateIconsList` (`src/plugins2.cpp`); users `src/toolbar8.cpp`, `src/mainwnd3.cpp` (4 pairs), `src/dialogs5.cpp`; the "has an icon" checks `src/plugins2.cpp` (`PluginSubmenuIconIndex`, `PluginIconIndex`), `src/fileswn5.cpp` | `PluginIcons[PluginIconIndex]` 16 px scaled, else `IDI_PLUGIN` |
| Change Drive menu, drive bars | `CPlugins::AddItemsToChangeDrvMenu` (`src/plugins2.cpp`) | `PluginIcons[ChDrvMenuFSItemIconIndex]` (+ gray), else `IDI_PLUGINFS` |
| Tab of a plug-in FS | `src/tabwnd.cpp` (`SAL_TAB_KIND_PLUGINFS`, cache `PluginIcon[]`) | same index, else `IDI_PLUGINFS` |
| Directory line of a plug-in FS | `CFilesWindow::UpdateDriveIcon` (`src/fileswn3.cpp`) | `GetFSIcon`, else `IDI_PLUGINFS` |
| Drive list row of the open FS | `src/drivelst.cpp` | `GetFSIcon`, else `IDI_PLUGINFS` |
| Disconnect dialog FS rows | `src/dialogs6.cpp` | `GetFSIcon`, else `CONNECTION_ICON_PLUGIN` (`IDI_PLUGINFS`) |

Not in scope (the plug-ins' own lists): `CPluginData::CreateImageList` (a plug-in's own menu-item icons,
`src/plugins1.cpp`), the FS item icons (`pitFromPlugin`, `GetSimplePluginIcons`, `GetPluginIcon`).

`GetFSIcon` of the shipped FS plug-ins: FTP `FTPIcon`, SFTP `SFTPIcon`, RegEdit `IDI_REGEDT`, Undelete
`IDI_FS`, Portables its plug-in icon, Nethood its main icon - identity icons; **Folders**: the shell icon of
the current folder (`src/plugins/folders/fs2.cpp`) - kept (FR-003).

## Analyze (speckit-analyze)

Round 1: CRITICAL 1 (D1: no formatting gate - constitution *Development Workflow*), MEDIUM 3 (E1 FR-010 had no
measurement; E2 the switch rows did not cover the directory line; B1 CLASSIC-EQ parts unnamed), LOW 3 (E3 SC-003
not tested; U1 the second FS-row site of the Disconnect dialog; E4 the gray rule not tested on its own). Fixed in
tasks.md: T022 clang-format check; T021 rows CACHE, SWITCH with the directory line, CLASSIC-EQ parts; T007
pairwise-different files; T015 both sites. E4 accepted: the set icon's gray copy goes through
`CIconList::CreateAsCopy(.., TRUE)`, the very code of today's `PluginIconsGray`.
