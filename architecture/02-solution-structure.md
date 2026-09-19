# Solution Structure

**Solution file**: `src\vcxproj\salamand.sln`
**Visual Studio**: 2022 (Format Version 12.00, VS Version 17)
**Total projects**: 75 C++ projects

> **Update (2026-07-16, feature 007 — plugin build policy):** 8 obsolete
> plugins (pak, unarj, unlha, unfat, wmobile, ieviewer, splitcbn, winscp)
> were removed from the repository, dropping 14 projects (7 plugin +
> 7 language) from the solution. Which of the remaining plugins are built
> is controlled by `plugins.cfg` in the repository root.

## Build Configurations

| Configuration | Purpose |
|---------------|---------|
| Debug\|Win32 | Debug build for 32-bit |
| Debug\|x64 | Debug build for 64-bit |
| Release\|Win32 | Release build for 32-bit |
| Release\|x64 | Release build for 64-bit |
| Utils (Release)\|Win32 | Utility tools only, 32-bit |
| Utils (Release)\|x64 | Utility tools only, 64-bit |

## Project Categories

### Core Application (2 projects)

| Project | Path | Output | Description |
|---------|------|--------|-------------|
| salamand | vcxproj/salamand.vcxproj | .exe | Main application executable |
| lang | vcxproj/lang.vcxproj | .slg | English language resources for main app |

salamand depends on lang (build order only, ReferenceOutputAssembly=false).

### Plugins (28 projects)

Each plugin produces a `.spl` file (DLL with Salamander Plugin extension).

#### Archive Plugins

| Project | Path | Output | Description |
|---------|------|--------|-------------|
| 7zip | plugins/7zip/vcxproj/7zip.vcxproj | .spl | 7-Zip archive support |
| tar | plugins/tar/vcxproj/tar.vcxproj | .spl | TAR archive support |
| uncab | plugins/uncab/vcxproj/uncab.vcxproj | .spl | CAB archive extraction |
| unchm | plugins/unchm/vcxproj/unchm.vcxproj | .spl | CHM file extraction |
| undelete | plugins/undelete/vcxproj/undelete.vcxproj | .spl | File undelete from FAT/NTFS |
| uniso | plugins/uniso/vcxproj/uniso.vcxproj | .spl | ISO image extraction |
| unmime | plugins/unmime/vcxproj/unmime.vcxproj | .spl | MIME message extraction |
| unole | plugins/unole/vcxproj/unole.vcxproj | .spl | OLE compound document extraction |
| unrar | plugins/unrar/vcxproj/unrar.vcxproj | .spl | RAR archive extraction |
| zip | plugins/zip/vcxproj/zip.vcxproj | .spl | ZIP archive support (create + extract) |

#### Viewer Plugins

| Project | Path | Output | Description |
|---------|------|--------|-------------|
| mmviewer | plugins/mmviewer/vcxproj/mmviewer.vcxproj | .spl | Multimedia file viewer |
| peviewer | plugins/peviewer/vcxproj/peviewer.vcxproj | .spl | PE (EXE/DLL) file viewer |
| pictview | plugins/pictview/vcxproj/pictview.vcxproj | .spl | Image viewer |

#### File Management Plugins

| Project | Path | Output | Description |
|---------|------|--------|-------------|
| diskmap | plugins/diskmap/vcxproj/diskmap.vcxproj | .spl | Disk space usage visualization |
| filecomp | plugins/filecomp/vcxproj/filecomp.vcxproj | .spl | File comparison |
| folders | plugins/folders/vcxproj/folders.vcxproj | .spl | Folder shortcuts |
| renamer | plugins/renamer/vcxproj/renamer.vcxproj | .spl | Batch file renaming |

#### Utility Plugins

| Project | Path | Output | Description |
|---------|------|--------|-------------|
| automation | plugins/automation/vcxproj/automation.vcxproj | .spl | Scripting/automation (COM-based) |
| checksum | plugins/checksum/vcxproj/checksum.vcxproj | .spl | File checksum calculation |
| checkver | plugins/checkver/vcxproj/checkver.vcxproj | .spl | Version checking |
| dbviewer | plugins/dbviewer/vcxproj/dbviewer.vcxproj | .spl | Database viewer (SQLite) |
| regedt | plugins/regedt/vcxproj/regedt.vcxproj | .spl | Windows Registry editor |

#### Network Plugins

| Project | Path | Output | Description |
|---------|------|--------|-------------|
| ftp | plugins/ftp/vcxproj/ftp.vcxproj | .spl | FTP/FTPS client |
| nethood | plugins/nethood/vcxproj/nethood.vcxproj | .spl | Network neighborhood browser |
| portables | plugins/portables/vcxproj/portables.vcxproj | .spl | Portable devices (MTP/WPD) |

#### Demo Plugins

| Project | Path | Output | Description |
|---------|------|--------|-------------|
| demomenu | plugins/demomenu/vcxproj/demomenu.vcxproj | .spl | Demo: menu extension |
| demoplug | plugins/demoplug/vcxproj/demoplug.vcxproj | .spl | Demo: basic plugin |
| demoview | plugins/demoview/vcxproj/demoview.vcxproj | .spl | Demo: viewer plugin |

### Language Modules (29 projects)

Each plugin and the main app has a corresponding language project
producing an `english.slg` resource-only DLL. These contain no code —
only UI strings, dialogs, and menus.

| Project | For Plugin |
|---------|-----------|
| lang | salamand (main app) |
| lang_7zip | 7zip |
| lang_automation | automation |
| lang_checksum | checksum |
| lang_checkver | checkver |
| lang_dbviewer | dbviewer |
| lang_demomenu | demomenu |
| lang_demoplug | demoplug |
| lang_demoview | demoview |
| lang_diskmap | diskmap |
| lang_filecomp | filecomp |
| lang_folders | folders |
| lang_ftp | ftp |
| lang_mmviewer | mmviewer |
| lang_nethood | nethood |
| lang_peviewer | peviewer |
| lang_pictview | pictview |
| lang_portables | portables |
| lang_regedt | regedt |
| lang_renamer | renamer |
| lang_tar | tar |
| lang_uncab | uncab |
| lang_unchm | unchm |
| lang_undelete | undelete |
| lang_uniso | uniso |
| lang_unmime | unmime |
| lang_unole | unole |
| lang_unrar | unrar |
| lang_zip | zip |

### Shell Extensions (2 projects)

| Project | Path | Output | Description |
|---------|------|--------|-------------|
| salextx86 | vcxproj/shellext/salextx86.vcxproj | .dll | Shell extension (32-bit) |
| salextx64 | vcxproj/shellext/salextx64.vcxproj | .dll | Shell extension (64-bit) |

### Helper Libraries (7 projects)

| Project | Path | Output | Description |
|---------|------|--------|-------------|
| 7za | plugins/7zip/vcxproj/7ZA/7za.dll.vcxproj | .dll | 7-Zip archive engine |
| 7zwrapper | plugins/7zip/vcxproj/7zwrapper/7zwrapper.vcxproj | .dll | 7-Zip wrapper |
| chmlib | plugins/unchm/vcxproj/chmlib/chmlib.vcxproj | .lib | CHM parsing library |
| exif | plugins/pictview/vcxproj/exif/exif.vcxproj | .lib | EXIF metadata library |
| fcremote | plugins/filecomp/vcxproj/fcremote/fcremote.vcxproj | .exe | File comparison remote helper |
| salpvenv | plugins/pictview/vcxproj/salpvenv.vcxproj | .exe | PictView environment helper |
| sqlite | vcxproj/sqlite/sqlite.vcxproj | .dll | SQLite database engine |

### Utility Executables (4 projects)

| Project | Path | Output | Description |
|---------|------|--------|-------------|
| salopen | vcxproj/salopen/salopen.vcxproj | .exe | Open files helper |
| salspawn | vcxproj/salspawn/salspawn.vcxproj | .exe | Process spawning helper |
| tserver | vcxproj/tserver/tserver.vcxproj | .exe | Trace Server (debug messages) |
| translator | vcxproj/translator/translator.vcxproj | .exe | UI translation utility |

### Setup/Install (3 projects)

| Project | Path | Output | Description |
|---------|------|--------|-------------|
| setup | vcxproj/setup/setup.vcxproj | .exe | Installer |
| remove | vcxproj/setup/remove.vcxproj | .exe | Uninstaller |
| sfx7zip | vcxproj/sfx7zip/sfx7zip.vcxproj | .exe | 7-Zip self-extractor |

### Other

| Project | Path | Description |
|---------|------|-------------|
| zip2sfx | plugins/zip/vcxproj/zip2sfx/zip2sfx.vcxproj | ZIP to SFX converter |
| Solution Items | (virtual folder) | Contains .editorconfig |

## Property Sheet Hierarchy

All compiler/linker settings are defined in `.props` files, not in
individual `.vcxproj` files.

### Main Application

```
src/plugins/shared/vcxproj/x86.props  (or x64.props)
  └── src/plugins/shared/vcxproj/root.props
src/vcxproj/sal_base.props
src/vcxproj/sal_debug.props  (or sal_release.props)
```

### Plugins

```
src/plugins/shared/vcxproj/x86.props  (or x64.props)
  └── src/plugins/shared/vcxproj/root.props
src/plugins/shared/vcxproj/plugin_base.props
src/plugins/shared/vcxproj/plugin_debug.props  (or plugin_release.props)
```

### Language Modules

```
src/plugins/shared/vcxproj/x86.props  (or x64.props)
  └── src/plugins/shared/vcxproj/root.props
src/vcxproj/lang_base.props  (main) or src/plugins/shared/vcxproj/lang_base.props  (plugins)
src/vcxproj/lang_debug.props  (or lang_release.props)
```

## Project Dependency Pattern

Most plugins use `ReferenceOutputAssembly=false` — they depend on
their language module and sometimes other projects for build ordering,
but do not link the output assembly. Example:

```
filecomp → fcremote (build order)
filecomp → lang_filecomp (build order)
salamand → lang (build order)
```

## Total Count Summary

| Category | Count |
|----------|-------|
| Core Application | 2 |
| Plugins | 28 |
| Language Modules | 29 |
| Shell Extensions | 2 |
| Helper Libraries | 7 |
| Utility Executables | 4 |
| Setup/Install | 3 |
| Other | 1 (zip2sfx) + 1 (Solution Items) |
| **Total** | **77** (75 C++ projects + 1 virtual + 1 converter) |
