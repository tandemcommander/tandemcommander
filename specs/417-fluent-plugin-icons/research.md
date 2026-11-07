# Research - 417 Fluent 2 icons for the plug-ins

## R1 Where to replace: at draw time, not in the plug-in's icon list

- **Decision**: each site that draws a plug-in's identity icon asks a core helper for the set icon first and keeps
  today's code as the fallback.
- **Rationale**: `CPluginData::PluginIcons` is the plug-in's own list, saved to the registry
  (`SALAMANDER_PLUGINS_PLGICONLIST`, `CPlugins::Save`) so that the icon shows without loading the plug-in.
  Replacing entries in it would write set icons into the configuration (FR-010) and make the way back to Classic
  depend on reloading every plug-in. The list is also 16 px (`CreateFromBitmap(bmp, width / 16)`), so
  `ImageList_AddIcon` into a 24 px list scales it; a set icon rendered at the list's size is sharp (FR-006).
- **Alternatives**: a parallel `CIconList` per plug-in rebuilt on a set change (more state, still 16 px); a plug-in
  API to hand over an SVG (ABI change, maintainer-owned, and the shipped plug-ins would all need rebuilding).

## R2 Which plug-in is a shipped one

- **Decision**: its `DLLName` (relative to the plug-ins folder, as `CPlugins::Load` normalizes it) is exactly
  `<id>\<id>.spl` (ASCII case-insensitive) and `<id>` is one of the 31 ids of the tree's plug-ins.
- **Rationale**: every plug-in of the tree has that form (`build\...\plugins\*\*.spl` listed: `ftp\ftp.spl`,
  `regedt\regedt.spl`, ...); a third-party plug-in lives in its own folder, and one outside the plug-ins folder has
  an absolute `DLLName`, which the rule refuses. No signature check (clarification 3): the effect is cosmetic.
- **Alternatives**: the plug-in's name (`CPluginData::Name`, translated, not stable); the version info (needs the
  DLL loaded).

## R3 The directory-line icon of a file system

- **Decision**: replaced for FTP, SFTP, RegEdit, Undelete, Portables and Nethood; kept for Folders and DemoPlug
  (review 1: DemoPlug returns the shell icon of the root of its current path, `src/plugins/demoplug/fs2.cpp`).
- **Rationale**: their `GetFSIcon` return a fixed identity icon (`FTPIcon`, `SFTPIcon`, `IDI_REGEDT`, `IDI_FS`,
  the Portables plug-in icon, Nethood's main icon); Folders returns
  `GetFileIcon(CurrentPIDL)`, the icon of the folder the panel shows (`src/plugins/folders/fs2.cpp`).

## R4 Gray copies

- **Decision**: a set icon's gray copy is made by `CIconList::CreateAsCopy(list, TRUE)` on a one-icon list.
- **Rationale**: the same rule (`GetGrayscaleFromRGB` per pixel, alpha kept, `iconlist.cpp`) as today's
  `PluginIconsGray` (FR-011). The Plugins bar shows only its hot list (`toolbar2.cpp`: `HHotImageList ? ... :`), so
  the gray copy is visible in menus (disabled items) and the gray drive pictures only.

## R5 What rebuilds after a set or theme change

- `ColorsChanged` -> `CMainWindow::OnColorsChanged` rebuilds the drive bars (`RebuildDrives`, which calls
  `AddItemsToChangeDrvMenu`) and the panels' drive icons; the tab strip clears its icon cache on a colour change
  (416). The Plugins bar only gets `OnColorsChanged()` (a new cache bitmap) - its image lists from
  `CreateIconsList` stay; **add `CreatePluginButtons()`** there (FR-015). Menus, the Plugins manager and the
  Disconnect dialog build their lists when opened.

## R6 SFTP without an icon (side finding)

- SFTP's `Connect` never calls `SetBitmapWithIcons` (its `sftp.bmp` is the FTP look-alike): no `PluginIcons`, so
  `IDI_PLUGIN` / `IDI_PLUGINFS` today. Fluent 2: its set icon (R1 works without `PluginIcons`). Classic: kept
  (FR-008). Severity 2, recorded in `fix-log.md`.

## R7 Data

- **Decision**: port `nastroje\gen_fluent_plugins.py` of the study into `tools/brand/fluent-icons/` beside
  `gen_fluent.py` (same package argument and README pin, same palettes / roles / halo / plate as 416 plus
  `greenFill` and `onAccent`), output committed. The study's catalogue data (Czech texts, today's PNGs, the `.js`
  for the pages) stays out of the repository.
- **Deployment**: `build.cmd` copies `iconsets\fluent` with `robocopy /E` (takes the subfolder); the MSBuild
  post-build `!populate_build_dir.cmd` copies folder by folder - add `plugins\` and `plugins\dark\`; the installer
  takes `Release_x64\*` recursively. Licence: the same MIT text, already shipped (`LICENSE-fluent.txt`).
