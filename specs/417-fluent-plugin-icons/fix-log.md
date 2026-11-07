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
Round 2: CRITICAL 0, HIGH 0, MEDIUM 0; E4 (LOW) accepted as above.

## Implementation

### Data (T002-T005)

- `tools/brand/fluent-icons/gen_fluent_plugins.py`: port of the study's generator (package argument like
  `gen_fluent.py`, `--help`, English, no study-only data). The package of the study
  (`%LOCALAPPDATA%\TandemIconStudy\vendor\fluent-1.1.344\pkg.tgz`) hashes to the README's sha512
  (`rasjaq4h...lJYoQ==`); `gen_fluent.py` regenerates 416's 95 + 95 files byte-identical from it (only the line
  ends of `LICENSE-fluent.txt` differ), so it is the pinned package.
- `python -I tools\brand\fluent-icons\gen_fluent_plugins.py <package>` -> 33 + 33 files in
  `src/res/iconsets/fluent/plugins[\dark]`, `diff -r` against the approved study files: **identical**.
- README section "Plug-in icons (feature 417)"; `!populate_build_dir.cmd` copies the two folders (robocopy is not
  recursive there); `build.cmd`'s `robocopy /E` and the installer's recursive `[Files]` entry already take them.
- Trap (CLAUDE.md, 123): a Bash here-document turned `\b` / `\f` of a README command line and of two code comments
  into control bytes; fixed with a byte-level script, `fix_ctl.py`-style check finds none left. Scripts are written
  with the editor from here on.

### Code (T006-T018)

- `saliconset.h`: one path builder `SalIconSetBuildPathIn` (folder NULL = refused) behind `SalIconSetBuildPath`
  (unchanged results, tested) and the new `SalIconSetBuildPluginPath`; `SalIconSetPluginIdAt` (31 ids),
  `SalIconSetPluginId`, `SalIconSetPluginFSIconIsIdentity`, `SalIconSetPluginFolder` (NULL in Classic),
  `SAL_ICONSET_NAME_PLUGIN` / `_PLUGINFS`.
- `svg.cpp`: `LoadSetSVGImage(..., plugin)` reads the set's plug-in folder; `CreateSetIconFromFolder` shared by
  `CreateSetSVGIcon` (unchanged) and the new `CreateSetPluginSVGIcon` (active set; Classic has no folder -> NULL).
- `salamdr1.cpp`: `CreatePluginSetIcon` (Fluent 2 only, known id, Folders excluded for FS icons, gray copy through
  `CIconList::CreateAsCopy(.., TRUE)`), `CreatePluginSetDefaultIcon`, `PluginHasSetIcon` (UTF-8 path,
  `SalGetFileAttributes`).
- Sites: `CPlugins::CreateIconsList` (set icon, else today's icon, else the Fluent default or `IDI_PLUGIN`), the
  two "has an icon" tests of `plugins2.cpp` and View With (`fileswn5.cpp`), `AddItemsToChangeDrvMenu` (+ gray,
  default FS icon), the plug-in FS tab (`tabwnd.cpp`, the cache is cleared on every colour change, line 198),
  `UpdateDriveIcon` (`fileswn3.cpp`), the open-FS drive-list row and the Disconnect dialog's GetFSIcon rows, its
  default `CONNECTION_ICON_PLUGIN`.
- **Site found while implementing** (not in the enumeration of step 3): the open / detached FS items of the Change
  Drive menu and of the Disconnect dialog come from `GetChangeDriveOrDisconnectItem` (`drivelst.cpp`,
  `dialogs6.cpp`), whose icon FTP sets to its `FTPIcon` and SFTP to NULL - the set icon replaces it there too
  (identity rule: Folders returns no item).
- `mainwnd1.cpp`: `OnColorsChanged` rebuilds the Plugins bar (`CreatePluginButtons`).
- Classic review (T017): every helper returns NULL unless Fluent 2 is active, so each site runs its previous code
  unchanged; the only Classic-visible change is the extra `CreatePluginButtons` on a colour change, which rebuilds
  the same lists. `PluginIcons` / `SaveIconList` are not touched.
- `lang.rc`: `" &Icon style "` (the access key stays `I`; the page's other keys: F, H, c, S, p, m, o, T, u, l).

### Checks so far

- `.\build.cmd` (Debug x64): BUILD SUCCEEDED; the 6 warnings of the log are in `salamdr2.cpp` / `zip.cpp`
  (not touched).
- `saltests`: **286940 checks, 0 failed** (416: 285482). `TestPluginIcons417` worst silhouettes: light toolbar
  2.56 (DiskMap @16), highlight 2.12 (RegEdit @16); dark toolbar 3.23, highlight 2.14 (DiskMap @16); worst
  coverage 22 %; 66 files.
- Negative controls: `plugins\ftp.svg` removed and `plugins\dark\zip.svg` emptied -> `saltests` 4 failed
  ("missing", "does not parse"); `plugins\dark\sftp.svg` removed and an `extra.svg` added -> `check_iconset.py`
  2 problems. Restored; 0 / 0.
- `check_iconset.py`: 95 + 95 toolbar files, 33 plug-in icons, 0 problems (it now excludes the plug-in defaults
  from the toolbar names).
