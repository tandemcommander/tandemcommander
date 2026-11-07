---
title: Fluent 2 icons for the plug-ins; Appearance group renamed to Icon style
type: feature
status: open
severity: 5
area: panels-ui
source: manual
who: both
created: 2026-11-07
updated: 2026-11-07
verified: 2026-11-07 e5d4552e
effort: L
feature: -
related: []
depends-on: []
reason: -
---

# Fluent 2 icons for the plug-ins; Appearance group renamed to Icon style

## Problem

Feature 416 made **Fluent 2** the default icon set for the toolbar, menus, drive bar and `..`, but the
**plug-in icons stay as they were** (416's recorded limit "plug-in icons stay"):
- they are 16 px bitmaps from 1997-2010 with a magenta key (no alpha, except Portables, DiskMap, Undelete),
  stretched and blurred at 125-200 %;
- they have no Dark variant (the Dark adaptation does not touch them);
- 9 of the 31 plug-ins have no icon of their own and show the generic plug (`src/res/plugin.ico`): of the
  shipped ones DBViewer, PEViewer, TAR and UnCAB;
- CodeView, MdView and DemoView share one bitmap, FTP and SFTP share one.

Next to the Fluent 2 toolbar the Plugins bar, the Plugins menu, the Plugins manager, the Change Drive menu,
the drive bars and the tabs look like another program.

The maintainer wants: when the user chooses **Fluent 2** in Configuration > Appearance, the plug-in icons
are Fluent 2 too. The Appearance group is then about all icons, so its label changes from
**"Toolbar icons"** to a general name, **"Icon style"**.

## Evidence

At 9fd7cfb4, by reading:
- **The set and its files:** `src/common/saliconset.h` (`SalIconSetFolder`, `SalIconSetBuildPath`,
  `SalIconSetChooseSource`); loader `LoadSetSVGImage` / `CreateSetSVGIcon` in `src/svg.cpp` (an HICON from
  `iconsets\fluent\<Name>.svg`, the Dark variant from `iconsets\fluent\dark\` used verbatim);
  `GetActiveIconSet`, `Configuration.ToolbarIconSet` stored as "Toolbar Icon Set" (`src/mainwnd2.cpp`).
- **Where the core draws a plug-in's icon** (every site takes `CPluginData::PluginIcons` - a 16 px
  `CIconList` from the plug-in's `SetBitmapWithIcons` / `SetIconListForGUI`, cached in the registry as
  `SALAMANDER_PLUGINS_PLGICONLIST`, `src/plugins2.cpp` `Load` / `Save`):
  - `CPlugins::CreateIconsList` (`src/plugins2.cpp`, "HIMAGELIST CPlugins::CreateIconsList(BOOL gray)"):
    `PluginIcons[PluginIconIndex]`, else `IDI_PLUGIN`. Used by the Plugins bar (`CPluginsBar::CreatePluginButtons`,
    `src/toolbar8.cpp`), the Plugins menu and its plug-in submenus (`src/mainwnd3.cpp`, the
    `Plugins.CreateIconsList(FALSE)` / `(TRUE)` pairs; `src/plugins2.cpp` `mi.ImageIndex = (p->PluginSubmenuIconIndex != -1) ? orderIndex : -1`),
    the plug-in lists in menus (`mii.ImageIndex = (data->PluginIconIndex != -1) ? orderIndex : -1`), the
    View With menu (`src/fileswn5.cpp`, `plugin->PluginIconIndex != -1`) and the Plugins manager
    (`src/dialogs5.cpp`, `Plugins.CreateIconsList(FALSE)`).
  - The Change Drive menu and the drive bars (`src/plugins2.cpp`, `p->PluginIcons->GetIcon(p->ChDrvMenuFSItemIconIndex, TRUE)`,
    else `IDI_PLUGINFS`), the tab of a plug-in file system (`src/tabwnd.cpp`, the same index, else `IDI_PLUGINFS`).
  - The icon of an opened plug-in file system in the directory line (`src/fileswn3.cpp`,
    `GetPluginFS()->GetFSIcon(destroyIcon)`, else `IDI_PLUGINFS`), the active-FS row of the drive list
    (`src/drivelst.cpp`) and the FS list of `src/dialogs6.cpp`. FTP, SFTP, RegEdit, Undelete, Portables and
    Nethood return their own identity icon there; **Folders returns the shell icon of its current folder**
    (`src/plugins/folders/fs2.cpp`, `GetFSIcon`) - that one carries information and must stay.
- **No rebuild on a set change:** `CMainWindow::OnColorsChanged` (`src/mainwnd1.cpp`) calls only
  `PluginsBar->OnColorsChanged()`; the bar's image lists come from `CreatePluginButtons`.
- **DLL names:** every plug-in shipped with the program is `<id>\<id>.spl` relative to the plug-ins folder
  (`CPlugins::Load` normalizes it, `src/plugins2.cpp`; e.g. `ftp\ftp.spl`, `regedt\regedt.spl`).
- **The Appearance group:** `IDD_CFGPAGE_APPEARANCE`, `GROUPBOX " Toolbar &icons ",IDC_ICONSET_GROUP`
  (`src/lang/lang.rc:1291`).
- **Design** (maintainer's study, 2026-11-07, outside the repository,
  `C:\Users\pavel\AppData\Local\TandemIconStudy\`): `pluginy.html` (catalogue, mock-ups, rationale),
  `nastroje\gen_fluent_plugins.py` (generator: plug-in -> Fluent glyph, colour role, badge; the same palettes,
  roles, paper / halo rules as `tools/brand/fluent-icons/gen_fluent.py`; own drawings: the 7-Zip "7" tile and
  the RegEdit cube block), `novy-design-fluent\plugins\*.svg` + `plugins\dark\*.svg` (33 + 33 files: 31
  plug-ins + `_plugin` / `_pluginfs` defaults). The maintainer approved the design, the RegEdit icon after
  three rounds (a block of cubes facing the viewer, the front top-right cube missing, two tilted cubes flying
  in; Fluent 2 brand-ramp blues).

## Expected

- **Fluent 2 active** (the default):
  - every plug-in shipped with the program shows its Fluent 2 icon wherever the core draws the plug-in's
    icon: Plugins bar, Plugins menu and its submenus, plug-in lists in menus, View With, Plugins manager,
    Change Drive menu, drive bars, tabs, and the directory line of its file system (except Folders, which
    keeps the shell icon of its current folder);
  - a shipped plug-in that has no icon today (DBViewer, PEViewer, TAR, UnCAB, …) gets its Fluent 2 icon;
  - a third-party plug-in keeps its own icon; one without an icon gets the Fluent 2 default plug-in icon
    (and the default file-system icon) instead of the old plug;
  - the icons are rendered at the image list's size (sharp at 100-200 %); the Dark theme uses the
    hand-made Dark variants verbatim;
  - a missing or unusable set file falls back to today's icon of that plug-in (never an empty slot).
- **Classic active:** every plug-in icon is pixel-identical to today.
- The switch on OK / Apply (and a theme switch, and an imported configuration) rebuilds the plug-in icons
  at once, without a restart - the Plugins bar included.
- Nothing about plug-ins changes: the plug-in interface, the plug-ins' own windows and toolbars, the icon
  cache in the registry (set icons are never stored there; going back to Classic gives exactly today's icons).
- **Configuration > Appearance:** the group label reads **"Icon style"** (the access key stays where it
  works); the stored value keeps its name "Toolbar Icon Set" (configuration compatibility). All enabled
  languages get the new label through the two-stage `.slt` refresh in the run.
- **Legibility** as in 416: no plug-in icon disappears on the bar, on the menu highlight or on the Change
  Drive highlight, in Light and Dark.
- **Evidence:** a hidden-desktop probe captures the Plugins bar, a drive bar with plug-in file systems, the
  Plugins manager, a plug-in file system's directory line and tab, in both sets x both themes, with Classic
  compared against the build of `main`; pure rules (plug-in id from the DLL name, which plug-ins' FS icon is
  their identity, the file path) get `saltests` checks; every set file is rasterized and measured like
  416's files.

## Approach

1. Bring the study's generator into `tools/brand/fluent-icons/` (plug-in part beside `gen_fluent.py`, sharing
   its palettes), output `src/res/iconsets/fluent/plugins/<id>.svg` and `plugins/dark/<id>.svg`; extend
   `check_iconset.py` and the README; deploy the folder (build.cmd and `!populate_build_dir.cmd`; the
   installer already takes the build folder recursively).
2. Pure rules in `src/common/saliconset.h`: the plug-in id from a DLL name (`<id>\<id>.spl`, known ids only,
   anything else = no set icon), whether a plug-in's FS icon is its identity, the plug-in file path.
3. One core helper that gives a plug-in's set icon at a size (and its grey copy), used by the sites above
   before their current code; the Classic set and every miss fall through to today's code unchanged.
4. Rebuild the Plugins bar's image lists in `OnColorsChanged`.
5. Rename the group label; `.slt` refresh.

## Notes

- Not maintainer-owned: no new stored value, no plug-in interface change, no network; the installer takes the
  new folder through its existing recursive `[Files]` entry (as 416's `iconsets\fluent\`). `PRIVACY.md` is not
  affected - confirm in the record.
- The grey copies (disabled menu items, Change Drive grey icons) keep today's rule (`CIconList::CreateAsCopy`
  grayscale), applied to the set icon.
- Files for the plug-ins that are `off` in `plugins.cfg` are generated and shipped too (cheap; ready when one
  is enabled); shipping a plug-in stays the maintainer's.

## Log

- 2026-11-07 — created (source manual)
- 2026-11-07 — moved to Next position 1
- 2026-11-07 — verified at e5d4552e: still present at e5d4552e: hidden-desktop capture, Plugins bar Fluent 2 vs Classic differ only in the 416 chevrons (242 px), plug-in FS icons on the drive bar identical
