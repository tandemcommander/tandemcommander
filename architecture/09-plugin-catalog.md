# Plugin Catalog by Purpose

Analysis of all 36 plugin directories under `src/plugins/` (35 buildable
projects in `salamand.sln` + WinSCP, which has no `.vcxproj`). Descriptions
are the user-facing strings from each plugin's English language resources
(`lang.rc2`); capability flags are taken from each plugin's
`SetBasicPluginData()` call in source. See
[06-plugin-architecture.md](06-plugin-architecture.md) for what the
`FUNCTION_xxx` flags mean and how plugins are loaded.

> **Update (2026-07-16, feature 007 — plugin build policy):** this
> catalog is the analysis that motivated the plugin policy and is kept
> as a historical record. Since then, **8 plugins were removed from the
> repository entirely** (pak, unarj, unlha, unfat, wmobile, ieviewer,
> splitcbn, winscp) and **10 more are disabled in the default build**
> via `plugins.cfg` (automation, checkver, demomenu, demoplug, demoview,
> mmviewer, nethood, unchm, unmime, unole). A default build therefore
> ships 18 plugins. See `specs/007-plugin-build-policy/` and
> [10-plugin-maintenance-outlook.md](10-plugin-maintenance-outlook.md).

## Summary

| Category | Count | Plugins |
|----------|-------|---------|
| Archivers (full read/write) | 3 | zip, 7zip, pak |
| Archivers (extract-only) | 8 | tar, unarj, uncab, unchm, unlha, unmime, unole, unrar |
| Disk image browsers | 2 | uniso, unfat |
| File viewers | 5 | pictview, ieviewer, mmviewer, peviewer, dbviewer |
| File tools | 5 | filecomp, renamer, checksum, splitcbn, diskmap |
| Network / remote access | 3 | ftp, winscp, nethood |
| Portable devices | 2 | wmobile, portables |
| System & integration | 5 | regedt, undelete, folders, automation, checkver |
| SDK examples | 3 | demoplug, demoview, demomenu |
| **Total** | **36** | |

Integration models used by the categories:

- **Archiver plugins** (`spl_arc.h`) present archive contents as a panel
  directory and handle pack/unpack. Extract-only plugins declare
  `FUNCTION_PANELARCHIVERVIEW | FUNCTION_CUSTOMARCHIVERUNPACK`; full
  archivers add `FUNCTION_PANELARCHIVEREDIT | FUNCTION_CUSTOMARCHIVERPACK`.
- **Viewer plugins** (`spl_view.h`) declare `FUNCTION_VIEWER` and open files
  in their own window (F3/Alt+F3).
- **File system plugins** (`spl_fs.h`) declare `FUNCTION_FILESYSTEM` and
  mount a virtual path (e.g. `ftp:`, `reg:`, `net:`) into a panel.
- **Menu/tool plugins** declare no panel integration — they only add
  commands to the Plugins menu (optionally `FUNCTION_DYNAMICMENUEXT`).

---

## Archivers — full read/write (3)

Create, modify, and extract archives; contents browsable directly in a panel.

| Plugin | Description | Extensions | Notes |
|--------|-------------|------------|-------|
| **zip** | Create, browse, and extract ZIP archives. | `zip;pk3;pk4;jar` | Also builds `zip2sfx` (self-extractor converter); one of the default plugins registered on first run. |
| **7zip** | Create, browse, and extract 7-Zip archives; browse and extract RAR (RAR 1.5–4, RAR5; read-only, feature 087). | `7z`, `rar` | Uses the bundled 7-Zip 26.03 engine (`7za.dll`, built from `src/plugins/7zip/7za`, 7z + RAR handlers only; local patches in `TC-PATCHES.md`). |
| **pak** | Browse and extract Quake PAK archives. | `pak` | Despite the description, declares full edit/pack flags (read/write). |

## Archivers — extract-only (8)

Browse and unpack existing archives; no packing support
(`FUNCTION_PANELARCHIVERVIEW | FUNCTION_CUSTOMARCHIVERUNPACK`).

| Plugin | Description | Extensions | Notes |
|--------|-------------|------------|-------|
| **tar** | Browse and extract Unix archives. | `tar;tgz;taz;tbz;gz;bz;bz2;z;rpm;cpio;deb` | Also declares `FUNCTION_VIEWER`; default plugin on first run. |
| **unarj** | Browse and extract ARJ archives. | `arj` | |
| **uncab** | Browse and extract CAB archives. | `cab` | Windows Cabinet format. |
| **unchm** | Browse and extract CHM files. | `chm` | Compiled HTML Help; uses bundled `chmlib`. |
| **unlha** | Browse and extract LHA archives. | `lzh;lha;lzs` | |
| **unmime** | Browse and extract MIME/Base64, UU/XXEncode, yEncode and BinHex files. | `eml;b64;uue;xxe;hqx;ntx;cnm` | E-mail message/encoding decoder. |
| **unole** | Browse and extract OLE Compound files. | `ole` | OLE structured storage (old Office document containers). |
| **unrar** | Browse and extract RAR archives. | `rar` | Requires `unrar.dll` (not in repo — missing dependency). |

## Disk image browsers (2)

Archiver-style plugins whose "archive" is a disk/medium image.

| Plugin | Description | Extensions | Notes |
|--------|-------------|------------|-------|
| **uniso** | Browse and extract CD/DVD ISO image files. | `iso;isz;nrg;bin;img;pdi;cdi;cif;ncd;c2d;dmg` | Also declares `FUNCTION_VIEWER`. |
| **unfat** | Browse and extract FAT 12, 16, and 32 disk images. | `ima` | Floppy/FAT volume images. |

## File viewers (5)

Standalone viewer windows for specific file formats (`FUNCTION_VIEWER`).

| Plugin | Description | Notes |
|--------|-------------|-------|
| **pictview** | Fast image viewer and converter. | Thumbnails, EXIF (bundled `exif` lib), TWAIN scanning. Since feature 006 runs on the built-in Windows WIC engine (no proprietary `PVW32Cnv.dll`); encoder-backed features disabled. |
| **ieviewer** | Lightweight HTML and XML viewer based on Internet Explorer. | Also renders Markdown via bundled cmark-gfm; default plugin on first run. |
| **mmviewer** | Display information about multimedia files such as MP3, OGG, WAV, etc. | Tag/metadata viewer (WMA parser included), not a media player. |
| **peviewer** | Display information about Portable Executable files such as EXE, DLL, etc. | Headers, sections, imports/exports. |
| **dbviewer** | Display dBase, FoxPro and CSV database files. | Tabular data viewer (DBF/CSV). |

## File tools (5)

Commands invoked from the Plugins menu that operate on selected files;
no panel or viewer integration.

| Plugin | Description | Notes |
|--------|-------------|-------|
| **filecomp** | Visual comparison of two text or binary files. | Includes `fcremote` helper executable for launching comparisons from a second Salamander instance. |
| **renamer** | Powerful batch renamer with real-time preview. | Pattern- and regex-based bulk renaming. |
| **checksum** | SFV, MD5, SHA-1, SHA-256, and SHA-512 checksum verifier and calculator. | |
| **splitcbn** | Split and combine files. | Splits files to media-sized chunks and rejoins them. |
| **diskmap** | Displays a treemap of files on your disk. | Visual disk-space usage map. |

## Network / remote access (3)

Virtual file systems for remote hosts (`FUNCTION_FILESYSTEM`).

| Plugin | Description | FS name | Notes |
|--------|-------------|---------|-------|
| **ftp** | Transfer files and directories over FTP. | `ftp` | FTPS (SSL) requires OpenSSL — missing dependency, not in repo. |
| **winscp** | SFTP/SCP client based on WinSCP. | `winscp` | **Special case**: source present but no `.vcxproj`, not in solution; x86-only (excluded on x64 via `IsPluginUnsupportedOnX64`); requires Embarcadero RTL to build. |
| **nethood** | Provides access to computers on the network. | `net` | Network Neighborhood browser (UNC shares). |

## Portable devices (2)

Virtual file systems for external devices.

| Plugin | Description | FS name | Notes |
|--------|-------------|---------|-------|
| **wmobile** | Access files on your Windows Mobile device. | `CE` | Uses RAPI/ActiveSync; legacy Windows CE devices. |
| **portables** | Manage portable devices. | `pd` | Windows Portable Devices API (MTP/PTP: phones, cameras, players). |

## System & integration (5)

Windows system access and Salamander housekeeping.

| Plugin | Description | Integration | Notes |
|--------|-------------|-------------|-------|
| **regedt** | Browse, view, and modify Windows Registry. | FS `reg` | Registry mounted as a panel file system, with search. |
| **undelete** | Recovers files deleted from FAT or NTFS partitions. | FS `del` | Data-recovery browser over raw volumes. |
| **folders** | Browse folders such as Desktop, Control Panel, Recycle Bin, etc. | FS `fld` | Shell namespace (virtual folders) in a panel. |
| **automation** | Automates common tasks using scripts. | Dynamic menu | COM/Active Scripting host (e.g. VBScript/JScript) driving Salamander. |
| **checkver** | Check for updates of Open Salamander and plugins. | Menu | Online version check. |

## SDK examples (3)

Reference implementations for plugin authors; not end-user functionality.

| Plugin | Description | Demonstrates |
|--------|-------------|--------------|
| **demoplug** | This plugin should help you to make your own plugins. | Everything at once: archiver (`dmp`), viewer, file system (`dfs`), menu, configuration. |
| **demoview** | This plugin should help you to make your own viewer plugin. | Minimal viewer (`FUNCTION_VIEWER` + configuration). |
| **demomenu** | This plugin should help you to make your own menu extension plugin. | Minimal menu extension (declares no capability flags). |

---

## Capability flag matrix

Flags declared in each plugin's `SetBasicPluginData()` call
(`src/plugins/<name>/…`). Legend: **AV** = PANELARCHIVERVIEW,
**AE** = PANELARCHIVEREDIT, **CP** = CUSTOMARCHIVERPACK,
**CU** = CUSTOMARCHIVERUNPACK, **CF** = CONFIGURATION,
**LS** = LOADSAVECONFIGURATION, **VW** = VIEWER, **FS** = FILESYSTEM,
**DM** = DYNAMICMENUEXT.

| Plugin | AV | AE | CP | CU | CF | LS | VW | FS | DM |
|--------|----|----|----|----|----|----|----|----|----|
| 7zip | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | | | |
| automation | | | | | ✔ | ✔ | | | ✔ |
| checksum | | | | | ✔ | ✔ | | | |
| checkver | | | | | ✔ | ✔ | | | |
| dbviewer | | | | | ✔ | ✔ | ✔ | | |
| demomenu | | | | | | | | | |
| demoplug | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | (✔)¹ |
| demoview | | | | | ✔ | ✔ | ✔ | | |
| diskmap | | | | | | ✔ | | | |
| filecomp | | | | | ✔ | ✔ | | | |
| folders | | | | | | | | ✔ | |
| ftp | | | | | ✔ | ✔ | | ✔ | |
| ieviewer | | | | | | ✔ | ✔ | | |
| mmviewer | | | | | | ✔ | ✔ | | |
| nethood | | | | | ✔ | ✔ | | ✔ | |
| pak | ✔ | ✔ | ✔ | ✔ | | | | | |
| peviewer | | | | | ✔ | ✔ | ✔ | | |
| pictview | | | | | ✔ | ✔ | ✔ | | |
| portables | | | | | | | | ✔ | |
| regedt | | | | | ✔ | ✔ | | ✔ | |
| renamer | | | | | ✔ | ✔ | | | |
| splitcbn | | | | | ✔ | ✔ | | | |
| tar | ✔ | | | ✔ | | ✔ | ✔ | | |
| unarj | ✔ | | | ✔ | ✔ | ✔ | | | |
| uncab | ✔ | | | ✔ | ✔ | ✔ | | | |
| unchm | ✔ | | | ✔ | | | | | |
| undelete | | | | | ✔ | ✔ | | ✔ | |
| unfat | ✔ | | | ✔ | | | | | |
| uniso | ✔ | | | ✔ | ✔ | ✔ | ✔ | | |
| unlha | ✔ | | | ✔ | | | | | |
| unmime | ✔ | | | ✔ | ✔ | ✔ | | | |
| unole | ✔ | | | ✔ | ✔ | ✔ | | | |
| unrar | ✔ | | | ✔ | ✔ | ✔ | | | |
| winscp | | | | | ✔ | | | ✔ | |
| wmobile | | | | | | ✔ | | ✔ | |
| zip | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | | | |

¹ demoplug declares `FUNCTION_DYNAMICMENUEXT` only when built with
`ENABLE_DYNAMICMENUEXT`.

Plugins with no flags at all (demomenu) or only configuration flags
(checksum, checkver, diskmap, filecomp, renamer, splitcbn, automation)
integrate purely through menu items registered in `Connect()`.

## Build / dependency caveats

- **unrar** needs `unrar.dll` (RARLAB), **ftp** needs OpenSSL for FTPS,
  **winscp** needs the Embarcadero RTL — none of these ship in the repo
  (see [04-dependencies.md](04-dependencies.md)).
- **pictview** historically depended on the proprietary `PVW32Cnv.dll`;
  since feature 006 it decodes through Windows WIC in-process.
- Default plugins registered on a fresh install (no registry data):
  **zip**, **tar**, **pak**, **ieviewer**; everything else is auto-installed
  via `plugins.ver` / `.spl` discovery.
