# Plugin Architecture

## Plugin System Overview

Open Salamander uses a DLL-based plugin architecture where each plugin is a dynamically loaded library that communicates with the host application through a well-defined C++ abstract interface (virtual method tables).

### File Types

- **`.spl` (Salamander Plugin Library)** -- The compiled plugin DLL. Despite the custom extension, these are standard Windows DLLs built as `ConfigurationType=DynamicLibrary`. The extension is set via `<TargetExt>.spl</TargetExt>` in the shared property sheets.
- **`.slg` (Salamander Language)** -- Resource-only DLLs containing localized strings, dialogs, and other UI resources. Each plugin has a corresponding `lang_<plugin>` project that produces the `.slg` file.

### Dual-Project Pattern

Every plugin consists of two Visual Studio projects:

| Project | Output | Purpose |
|---------|--------|---------|
| `<name>.vcxproj` | `<name>.spl` | Plugin code and logic |
| `lang_<name>.vcxproj` | `lang_<name>.slg` | Localized resources (strings, dialogs) |

This separation allows shipping multiple language packs without recompiling plugin code. The plugin loads its language module at startup via `CSalamanderPluginEntryAbstract::LoadLanguageModule()`, which searches for an `.slg` file matching the current Salamander UI language.

---

## Plugin API Headers

All plugin API headers reside in `src/plugins/shared/` and form the Open Salamander SDK. They use 4-byte structure packing (`#pragma pack(4)`) to ensure binary compatibility regardless of project settings.

| Header | Purpose |
|--------|---------|
| `spl_base.h` | Core plugin interface. Defines `CPluginInterfaceAbstract` (the main interface every plugin must implement), `CSalamanderPluginEntryAbstract` (passed to the entry point), FUNCTION_xxx capability flags, LOADINFO_xxx constants, and safe memory/string wrappers. |
| `spl_com.h` | Common types and the directory abstraction. Defines `CQuadWord` (64-bit file sizes), `CSalamanderDirectoryAbstract` (directory tree representation), and the `SalamanderVersion` global. |
| `spl_gen.h` | General-purpose Salamander services via `CSalamanderGeneralAbstract`. Provides message boxes, file operations, path manipulation, clipboard, progress dialogs, password manager, viewer helpers, and hundreds of utility methods available to all plugin types. |
| `spl_arc.h` | Archiver plugin interface. Defines `CPluginInterfaceForArchiverAbstract` with methods for listing archive contents, extracting, packing, deleting, and unpacking files within archives. |
| `spl_view.h` | Viewer plugin interface. Defines `CPluginInterfaceForViewerAbstract` with the `ViewFile()` method for opening files in custom viewer windows, including file locking and cache integration. |
| `spl_menu.h` | Menu extension interface. Defines `CSalamanderBuildMenuAbstract` for plugins that add items to the Salamander menu (menu items, submenus, icons, hotkeys). |
| `spl_fs.h` | File system plugin interface. Defines `CPluginFSInterfaceAbstract` and `CSalamanderForViewFileOnFSAbstract` for plugins that implement virtual file systems (FTP, network shares, etc.) with disk-cache support. |
| `spl_gui.h` | GUI toolkit interface. Defines window messages (WM_USER+200..399 range), toolbar messages, and abstractions for menus, toolbars, and other UI elements that plugins can use. |
| `spl_thum.h` | Thumbnail loader interface. Defines `CSalamanderThumbnailMakerAbstract` for plugins that generate thumbnail previews, with support for image transformations (rotation, mirroring) and progressive loading. |
| `spl_file.h` | Safe file operations interface. Defines `CSalamanderSafeFileAbstract` providing error-handled file I/O (open, create, read, write, seek) with automatic retry/skip/cancel dialogs and handle recovery on network failures. |
| `spl_crypt.h` | Cryptography interface. Provides AES encryption and SHA1 hashing via Salamander's built-in libraries. Defines key/salt/MAC length macros for AES modes 1-3. |
| `spl_zlib.h` | ZLIB compression interface. Simplified wrapper around zlib for deflate/inflate operations, exposed as `CSalZLIB` with standard flush modes and error codes. |
| `spl_bzip2.h` | BZIP2 compression interface. Simplified wrapper around bzip2 for compress/decompress operations with standard action types and error codes. |
| `spl_vers.h` | Version information. Defines `VERSINFO_SALAMANDER_MAJOR` (currently 5), minor version numbers, platform strings (`x86`/`x64`), and macros for generating version strings in both plugin code and `.rc` resource files. |

### Key Interfaces and Capability Flags

A plugin declares its capabilities via `FUNCTION_xxx` flags passed to `SetBasicPluginData()`:

```
FUNCTION_PANELARCHIVERVIEW   0x0001  -- Can list archive contents in a panel
FUNCTION_PANELARCHIVEREDIT   0x0002  -- Can modify archive contents
FUNCTION_CUSTOMARCHIVERPACK  0x0004  -- Custom packing support
FUNCTION_CUSTOMARCHIVERUNPACK 0x0008 -- Custom unpacking support
FUNCTION_CONFIGURATION       0x0010  -- Has a configuration dialog
FUNCTION_LOADSAVECONFIGURATION 0x0020 -- Persists configuration to registry
FUNCTION_VIEWER              0x0040  -- Provides a file viewer
FUNCTION_FILESYSTEM          0x0080  -- Implements a virtual file system
FUNCTION_DYNAMICMENUEXT      0x0100  -- Adds dynamic menu items
```

Based on these flags, Salamander calls the corresponding `GetInterfaceForXxx()` methods on `CPluginInterfaceAbstract`:
- `GetInterfaceForArchiver()` returns `CPluginInterfaceForArchiverAbstract*`
- `GetInterfaceForViewer()` returns `CPluginInterfaceForViewerAbstract*`
- `GetInterfaceForMenuExt()` returns `CPluginInterfaceForMenuExtAbstract*`
- `GetInterfaceForFS()` returns `CPluginFSInterfaceAbstract*`
- `GetInterfaceForThumbLoader()` returns `CPluginInterfaceForThumbLoaderAbstract*`

---

## Plugin Build Configuration

### Property Sheet Hierarchy

Each plugin `.vcxproj` imports a chain of MSBuild property sheets. For example, the ZIP plugin (Debug|Win32) imports:

```
x86.props                    -- Platform-specific settings (ShortPlatform macro)
  plugin_base.props          -- Common plugin settings (output dir, .spl extension, etc.)
    plugin_debug.props       -- Debug-specific settings (no optimization, ASLR disabled)
  zip.props                  -- Plugin-specific overrides
```

Release builds substitute `plugin_release.props` for `plugin_debug.props`.

### plugin_base.props -- Common Settings

Defined in `src/plugins/shared/vcxproj/plugin_base.props`:

- **Output directory**: `$(OPENSAL_BUILD_DIR)tandemcommander\$(Configuration)_$(ShortPlatform)\plugins\$(ProjectName)\`
- **Target extension**: `.spl`
- **Compiler flags**: `/MP` (multi-process compilation), `/J` (default char is unsigned)
- **Include path**: `..\..\shared` (the shared plugin SDK headers)
- **Preprocessor**: `_MT;WIN32;_WINDOWS;_USRDLL`
- **Precompiled header**: `precomp.h`
- **Linker**: Links `comctl32.lib`, references `..\$(ProjectName).def` for module definition
- **Manifest generation**: Disabled (`GenerateManifest=false`, `EmbedManifest=false`)
- **Import library**: Ignored (`IgnoreImportLibrary=true`) since plugins are loaded dynamically

### plugin_debug.props -- Debug Settings

- **Optimization**: Disabled
- **Preprocessor**: `_DEBUG;TRACE_ENABLE;MHANDLES_ENABLE;_CRTDBG_MAP_ALLOC;_ALLOW_RTCc_IN_STL`
- **Runtime library**: MultiThreadedDebugDLL (`/MDd`)
- **Smaller type check**: Enabled
- **ASLR disabled**: `<RandomizedBaseAddress>false</RandomizedBaseAddress>`
- **Fixed base address**: Loaded from `baseaddr_$(ShortPlatform).txt` keyed by project name

### plugin_release.props -- Release Settings

- **Optimization**: MaxSpeed (`/O2`), intrinsic functions, function-level linking
- **Preprocessor**: `NDEBUG`
- **Runtime library**: MultiThreadedDLL (`/MD`)
- **ASLR enabled**: `<RandomizedBaseAddress>true</RandomizedBaseAddress>`
- **Link-time code generation**: Enabled (whole-program optimization)
- **COMDAT folding and reference elimination**: Enabled
- **Code signing**: Post-build step runs `sign_with_retry.cmd` on the output

### Visual C++ Runtime (application-local, feature 077)

The Release tree ships `vcruntime140.dll`, `vcruntime140_1.dll`,
`msvcp140.dll` and `concrt140.dll` next to `tandemcommander.exe`
(`build.cmd release` copies them from the Visual Studio installation that
built the product; see `03-build-pipeline.md`). Because the loader searches
the application directory first and a DLL name already loaded is reused
process-wide, **every plugin runs on the shipped runtime, never on a
system-wide copy, even a newer one**. Consequences for plugin authors:

- build plugins with a toolset **no newer than the shipped runtime**
  (14.40 for 0.1.x; the exact version is the file version of the tree's
  `vcruntime140.dll`). A plugin that needs a newer `msvcp140.dll` export
  fails to load even on a machine that has the newer redistributable
  installed;
- a plugin must not ship its own copy of these DLLs in `plugins\<name>\`
  (ignored for the already-loaded names, and it could shadow the
  application's copy for others);
- `tools\check_runtime_deps.py` fails the build if a shipped plugin imports
  a runtime DLL that is not in the tree root (for example
  `msvcp140_atomic_wait.dll`); add the file to the list in
  `src\vcxproj\copy_vc_runtime.cmd` in that case.

### Module Definition (.def) Files

Each plugin has a `.def` file (e.g., `src/plugins/zip/zip.def`) that controls DLL exports:

```
LIBRARY ZIP.SPL

EXPORTS SalamanderPluginEntry
EXPORTS SalamanderPluginGetReqVer
```

Every plugin must export:
- **`SalamanderPluginEntry`** -- The main entry point called by Salamander after loading the DLL. Receives a `CSalamanderPluginEntryAbstract*` and must return a `CPluginInterfaceAbstract*`.
- **`SalamanderPluginGetReqVer`** -- Returns the minimum Salamander version required by the plugin. Plugins that do not export this are treated as built for versions older than 2.5 beta 2.

An optional third export, `SalamanderPluginGetSDKVer`, allows a plugin to declare compatibility with a newer SDK version than the minimum it requires (for backward compatibility with older Salamander builds).

### Base Address Mapping (Debug Builds)

In debug builds, ASLR is disabled and each module is assigned a fixed base address from `src/plugins/shared/baseaddr_x86.txt` (and the x64 equivalent). This makes memory-leak debugging easier because unloaded modules reload at the same address, allowing proper symbol resolution.

Address ranges are organized as:

| Range | Usage |
|-------|-------|
| `0x04000000` | `salamand` (the main executable) |
| `0x20100000` -- `0x29Exxxxx` | Plugin DLLs (each spaced 0x100000 apart) |
| `0x30000000` -- `0x39Cxxxxx` | Language modules (`lang_*`) |

Example assignments:

```
salamand        0x04000000
demoplug        0x20100000
lang_demoplug   0x30100000
zip             0x21100000
lang_zip        0x31100000
ftp             0x23100000    0x001000000   (oversized allocation)
pictview        0x20600000
lang_pictview   0x30600000
```

---

## Complete Plugin Inventory

The source tree contains 28 plugin directories under `src/plugins/` (8 obsolete plugins were removed in feature 007). Each plugin (except `shared`) has a `.vcxproj` and corresponding `lang_` project. Which plugins are compiled and shipped is decided by `plugins.cfg` in the repository root (18 enabled / 10 disabled by default); see `specs/007-plugin-build-policy/`.

### Archive Plugins (15)

| Plugin | Description | Status |
|--------|-------------|--------|
| **7zip** | 7-Zip archive support (uses bundled 7za library) | Buildable |
| **zip** | ZIP archive support (pk3, jar); full read/write | Buildable |
| **tar** | Unix archive formats: tar, tgz, gz, bz, bz2, z, rpm, cpio (read-only) | Buildable |
| **uncab** | Windows Cabinet (.cab) archive extraction | Buildable |
| **unchm** | Compiled HTML Help (.chm) archive browsing (uses bundled chmlib) | Buildable |
| **undelete** | Deleted file recovery from NTFS volumes | Buildable |
| **uniso** | ISO 9660 CD/DVD image browsing | Buildable |
| **unmime** | MIME/EML email message extraction | Buildable |
| **unole** | OLE structured storage (compound document) browsing | Buildable |
| **unrar** | RAR archive extraction | Buildable |

### Viewer Plugins (4)

| Plugin | Description | Status |
|--------|-------------|--------|
| **pictview** | Image viewer with thumbnail generation, TWAIN scanning, and EXIF support (includes salpvenv helper) | Buildable |
| **mmviewer** | Multimedia viewer for audio/video files (WMA parser included) | Buildable |
| **peviewer** | PE (Portable Executable) file viewer -- displays headers, sections, imports/exports | Buildable |

### File Management Plugins (4)

| Plugin | Description | Status |
|--------|-------------|--------|
| **filecomp** | File and directory comparison tool (includes fcremote helper for remote comparison) | Buildable |
| **folders** | Folder size calculation and directory statistics | Buildable |
| **diskmap** | Visual disk space usage map (treemap visualization) | Buildable |
| **renamer** | Batch file renaming with pattern matching and regular expressions | Buildable |

### Utility Plugins (5)

| Plugin | Description | Status |
|--------|-------------|--------|
| **checksum** | File checksum calculation (CRC32, MD5, SHA1, etc.) | Buildable |
| **checkver** | Online version checking for Salamander and plugins | Buildable |
| **dbviewer** | Database file viewer (CSV, DBF, and similar tabular data) | Buildable |
| **regedt** | Windows Registry editor with search functionality | Buildable |
| **automation** | Scripting/automation interface for Salamander | Buildable |

### Network Plugins (4)

| Plugin | Description | Status |
|--------|-------------|--------|
| **ftp** | FTP/FTPS client with file system integration and SSL support | Buildable |
| **nethood** | Windows network neighborhood browser (UNC paths, shares) | Buildable |
| **portables** | Portable device file management (MTP/PTP) | Buildable |

### Demo/Example Plugins (3)

| Plugin | Description | Status |
|--------|-------------|--------|
| **demoplug** | SDK demo: full-featured example showing archiver, viewer, menu, and filesystem interfaces | Buildable |
| **demoview** | SDK demo: minimal file viewer implementation | Buildable |
| **demomenu** | SDK demo: menu extension example | Buildable |

### Special Cases

| Plugin | Description | Status |
|--------|-------------|--------|

### Shared Infrastructure

The `src/plugins/shared/` directory is not a plugin itself but contains:
- All `spl_*.h` SDK headers
- Shared property sheets (`vcxproj/*.props`)
- Base address mapping files (`baseaddr_x86.txt`, `baseaddr_x64.txt`)
- Shared utility code (`mhandles.cpp`, `lukas/utilbase.cpp`)
- Shared libraries (`libs/`)
- Debug helpers (`dbg.h`)

---

## Plugin Interface 104 (UTF-8 + Long Paths)

Plugin interface version 104 (feature `004-long-paths-unicode`)
changed the string contract: all `char*` names/paths crossing the
interface are UTF-8, `CFileData::NameLen` widened from a 9-bit
bitfield to a full 32-bit byte count (ABI/layout break), and paths may
reach the OS maximum (~32k chars). Binaries built for interface <= 103
are refused at load (`PLUGIN_REQVER = 104`) because the layout change
would corrupt memory; the migration path is a rebuild against the 104
SDK - see `doc/plugin-vnext-migration.md` and
`specs/004-long-paths-unicode/contracts/plugin-interface-vnext.md`.

## Plugin Loading Mechanism

Plugin loading is implemented in `src/plugins1.cpp` (`CPluginData::InitDLL`) and `src/plugins2.cpp` (`CPlugins::Load`, `SearchForAddedSPLs`).

### Plugin Registry and Discovery

Salamander discovers plugins through three mechanisms:

1. **Registry persistence** -- `CPlugins::Load()` reads the plugin list from the Windows Registry on startup. Each entry stores the plugin name, DLL path (relative to the `plugins\` subdirectory), supported function flags, version, and other metadata.

2. **Default configuration** -- When no registry data exists (first run), Salamander registers a minimal set of default plugins hardcoded in `CPlugins::Load()`: ZIP and TAR (PAK and Internet Explorer Viewer were part of this set until feature 007 removed those plugins).

3. **plugins.ver auto-installation** -- `SearchForAddedSPLs()` reads the `plugins.ver` file from the application directory. This file contains versioned entries in the format `<version>:<relative_path_to_spl>`. When the file's version number is newer than the last processed version, Salamander auto-installs any new SPL files listed. Additionally, `SearchForSPLs()` recursively scans the `plugins\` subdirectory for any `.spl` files not yet registered.

### DLL Loading Sequence

The loading sequence in `CPluginData::InitDLL()` proceeds as follows:

1. **Path resolution** -- If `DLLName` is a relative path, it is resolved relative to `<exe_dir>\plugins\`. UNC and absolute paths are used as-is.

2. **LoadLibrary** -- The DLL is loaded via `LoadLibrary(path)`. On failure, an error message displays the Windows error code.

3. **Entry point resolution** -- `GetProcAddress(DLL, "SalamanderPluginEntry")` retrieves the plugin's entry point. This is the `FSalamanderPluginEntry` function pointer.

4. **Version negotiation** -- `GetProcAddress(DLL, "SalamanderPluginGetReqVer")` retrieves the required version. If the plugin requires a version newer than the current Salamander (`PLUGIN_REQVER`), loading is aborted with a version mismatch error. Optionally, `SalamanderPluginGetSDKVer` can report a higher SDK version for backward-compatible plugins.

5. **Entry point call** -- A `CSalamanderPluginEntry` object is constructed and passed to the entry point function:
   ```cpp
   CPluginInterfaceAbstract* resIface = entry(&salamander);
   ```
   The plugin uses the `salamander` object to call `SetBasicPluginData()` (declaring its name, capabilities, version, extensions, and filesystem name), `LoadLanguageModule()` (loading its `.slg` resource DLL), and obtain interface pointers to Salamander services (`GetSalamanderGeneral()`, etc.).

6. **Interface acquisition** -- After the entry point returns, Salamander queries the returned `CPluginInterfaceAbstract*` for sub-interfaces based on the declared capability flags: `GetInterfaceForArchiver()`, `GetInterfaceForViewer()`, `GetInterfaceForMenuExt()`, `GetInterfaceForFS()`, and `GetInterfaceForThumbLoader()`.

7. **Connection** -- The plugin's `Connect()` method is called, allowing it to register file extension associations, menu items, toolbar buttons, filesystem names, and icon overlays with Salamander.

### Language Module Loading

When a plugin calls `LoadLanguageModule()`, Salamander:
1. Searches for an `.slg` file matching the current UI language
2. If not found, presents the user with a selection dialog for available alternatives
3. Loads the chosen `.slg` via `LoadLibrary()` as a resource-only DLL
4. Returns the `HINSTANCE` handle for use with `LoadString()`, `DialogBox()`, etc.
5. Automatically frees the language module when the plugin is unloaded

### Plugin Unloading

When a plugin is unloaded (via the Plugins Manager or application shutdown), Salamander calls `CPluginInterfaceAbstract::Release()` to allow the plugin to clean up, then calls `FreeLibrary()` on both the plugin DLL and its language module.
