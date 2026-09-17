# Build Pipeline

## Prerequisites

| Requirement | Details |
|-------------|---------|
| OS | Windows 11 or newer |
| IDE | [Visual Studio 2022](https://visualstudio.microsoft.com/downloads/) (Community, Professional, or Enterprise) |
| Workload | Desktop development with C++ |
| SDK | Windows 11 SDK (10.0.26100.4654) — install as VS optional component |
| Git | Optional — [git-scm.com](https://git-scm.com/downloads) |
| PowerShell | Optional — 7.4+ for normalize.ps1 script |
| HTML Help | Optional — [HTMLHelp Workshop 1.3](https://learn.microsoft.com/en-us/answers/questions/265752/htmlhelp-workshop-download-for-chm-compiler-instal) for help file compilation |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENSAL_BUILD_DIR` | Recommended | Build output directory. **Must have trailing backslash** (e.g., `D:\Build\OpenSal\`). If not set, build may fail or use a default path. |

## Quick Start

```batch
:: 1. Set build output directory
set OPENSAL_BUILD_DIR=D:\Build\OpenSal\

:: 2. Build from the repository root (recommended)
build.cmd                :: Debug x64 incremental build
build.cmd rebuild        :: Full clean + rebuild

:: 3. Or open solution in Visual Studio
start src\vcxproj\salamand.sln
```

## Build Entry Points

### 1. build.cmd — Repository Root (Recommended)

```batch
build.cmd              :: Incremental Debug x64 build
build.cmd rebuild      :: Full clean + rebuild Debug x64
build.cmd help         :: Show usage
```

Auto-detects Visual Studio 2022 via vswhere.exe, validates
prerequisites, and displays a build summary with timing.

Every run also executes the **plugin build policy stage** (feature 007):
`plugins.cfg` in the repository root (one `name=on|off` line per plugin)
is validated by `src\vcxproj\gen_plugins_filter.ps1`, a solution filter
`src\vcxproj\salamand.gen.slnf` (gitignored) is generated so MSBuild
compiles only enabled plugins, and stale outputs of disabled or removed
plugins are deleted from the output `plugins\` directory (`plugins.ver`
is filtered to the enabled set). Any validation error — missing file,
syntax error, unknown or duplicate entry, unlisted plugin — stops the
build before compilation. See
`specs/007-plugin-build-policy/contracts/build-cmd.md`.

Every run then executes the **language build policy stage** (feature 039),
the language counterpart of the above. `translations\languages.cfg` — the
shipped-language registry, one `[folder]` section per language carrying an
`enabled = on|off` field — is validated by `src\vcxproj\lang_policy.ps1`,
and the output tree is reconciled with it: every `.slg` in `lang\` and
`plugins\*\lang\` that does not belong to an enabled language is deleted
(`english.slg` is compiled from the `.rc` sources and always kept). Any
validation error — missing or unrecognized field, duplicate LANGID, a
registered language with no `translations\<folder>\` directory, or a
directory with no record — stops the build before compilation, naming the
offending section.

Note the split: **removal happens on every build, production only on a
full build.** Language modules are produced by `build_langs.cmd`, which
runs from `:populate_runtime` (i.e. `build.cmd full`). If removal also
lived there, a plain `build.cmd` after switching a language off would
leave its modules in the output tree — and because the product enumerates
`lang\*.slg` from disk, the language would still be offered. See
`specs/039-language-build-policy/contracts/build-scripts.md`.

### 2. Visual Studio IDE

Open `src\vcxproj\salamand.sln` and build from the IDE. Select
configuration (Debug/Release) and platform (x86/x64) from the toolbar.

### 3. src\vcxproj\build.cmd — Legacy Single Configuration

```batch
src\vcxproj\build.cmd [config] [arch]
```

- Default: `Debug x64`
- Examples: `build.cmd Release x86`, `build.cmd Debug x64`

### 4. src\vcxproj\rebuild.cmd — Legacy Full Rebuild with Menu

```batch
src\vcxproj\rebuild.cmd
```

Interactive menu with options:

| Option | Description |
|--------|-------------|
| 3 | Rebuild all targets |
| 5 | **Internal Build** (Utils + Debug x86/x64) — default |
| 6 | Developers Build (Utils + Debug + Release x86/x64) |
| 8 | Release/Beta Build (Utils + Release x86/x64) |
| 9 | Utils Only (Utils x86/x64) |

Uses MSBuild with parallel compilation (`/m:%NUMBER_OF_PROCESSORS%`).

## Build Configurations

| Configuration | Optimization | Debug Info | ASLR | Code Signing | Key Defines |
|---------------|-------------|------------|------|-------------|-------------|
| Debug\|Win32 | Disabled | Full | Off (fixed base) | No | `_DEBUG`, `TRACE_ENABLE` |
| Debug\|x64 | Disabled | Full | Off (fixed base) | No | `_DEBUG`, `TRACE_ENABLE`, `_WIN64` |
| Release\|Win32 | MaxSpeed + LTO | Yes | On | Yes | `NDEBUG` |
| Release\|x64 | MaxSpeed + LTO | Yes | On | Yes | `NDEBUG`, `_WIN64` |
| Utils\|Win32 | MaxSpeed | Yes | On | Yes | `NDEBUG` |
| Utils\|x64 | MaxSpeed | Yes | On | Yes | `NDEBUG`, `_WIN64` |

Debug builds use fixed base addresses from `baseaddr_x86.txt` /
`baseaddr_x64.txt` to help with debugging and memory leak detection.

## MSBuild Configuration Flow

```
salamand.sln
  ├── Per-project .vcxproj
  │     └── Imports property sheets (.props) in order:
  │           1. x86.props or x64.props (platform macros)
  │           2. sal_base.props / plugin_base.props (shared settings)
  │           3. sal_debug.props / sal_release.props (config-specific)
  │
  ├── Resolves macros:
  │     $(OPENSAL_BUILD_DIR) → build root
  │     $(ShortPlatform) → x86 or x64
  │     $(Configuration) → Debug, Release, or Utils (Release)
  │
  └── Builds in dependency order (parallel where possible)
```

## Key Compiler Settings

| Setting | Value | Flag |
|---------|-------|------|
| C++ Standard | C++20 | `/std:c++latest` |
| Char signedness | Unsigned | `/J` |
| Parallel compilation | Yes | `/MP` |
| Warning level | 3 | `/W3` |
| Precompiled header | precomp.h | `/Yu"precomp.h"` |
| Runtime (Debug) | MultiThreadedDebugDLL | `/MDd` |
| Runtime (Release) | MultiThreadedDLL | `/MD` |

## Output Directory Structure

```
%OPENSAL_BUILD_DIR%tandemcommander\
├── Debug_x86\
│   ├── salamand.exe              Main application
│   ├── lang\english.slg          Main language resources
│   ├── plugins\
│   │   ├── 7zip\
│   │   │   ├── 7zip.spl          Plugin binary
│   │   │   └── lang\english.slg  Plugin language resources
│   │   ├── zip\zip.spl
│   │   ├── tar\tar.spl
│   │   └── [enabled plugin directories - 18 by default...]
│   ├── Intermediate\             Object files, PCH cache
│   └── toolbars\                 Toolbar bitmaps
├── Debug_x64\                    Same structure as Debug_x86
├── Release_x86\                  Same structure (signed binaries)
├── Release_x64\                  Same structure (signed binaries)
├── sfx7zip\                      Self-extractor tools
├── translator\                   Translation utility
├── tserver\                      Trace server
├── setup\                        Installer
└── remove\                       Uninstaller
```

## Post-Build Steps

### Code Signing (Release only)

Release builds run `tools\codesign\sign_with_retry.cmd` as a
post-build event to sign executables, plugins, and DLLs (a no-op unless
`TC_CODESIGN=1`; release signing normally happens as the whole-tree sweep
`build.cmd full release sign`). Since feature 077 the sweep
(`tools\codesign\sign_release.ps1`) leaves files that carry a valid
Microsoft signature, the application-local Visual C++ runtime, untouched
(`Exempt (Microsoft): 4` in its summary) and refuses to run when a
runtime-named file is not validly Microsoft-signed.

### Visual C++ Runtime (Release only, feature 077)

Every shipped module links the CRT dynamically (`/MD`), so a Release tree
must carry the runtime itself: a machine without the "Microsoft Visual C++
2015-2022 Redistributable (x64)" could install 0.1.0-0.1.7 but not start
them. `build.cmd release` (full and incremental) therefore runs, after the
runtime layout and before the tree clean-up:

1. `src\vcxproj\copy_vc_runtime.cmd <VS_INSTALL> <OUT_DIR>` copies
   `vcruntime140.dll`, `vcruntime140_1.dll`, `msvcp140.dll`, `concrt140.dll`
   from `<VS_INSTALL>\VC\Redist\MSVC\<v>\x64\Microsoft.VC143.CRT\` into the
   tree root, where `<v>` is read from
   `<VS_INSTALL>\VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt`
   (the same file `VsDevCmd.bat` uses) and `<VS_INSTALL>` is the
   installation `build.cmd` located through `vswhere` (no absolute path,
   no manual step). A missing toolchain component fails the build with
   `ERROR: Visual C++ runtime not found: <path>`.
2. `python tools\check_runtime_deps.py <OUT_DIR>` parses the import and
   delay-load tables of every shipped PE (`*.exe *.dll *.spl *.slg`) and
   fails the build if any runtime-named import does not resolve to a file
   in the tree root (`<module> needs <dll> (not shipped)`). That is the
   signal to extend the fixed list in step 1.

The summary block reports `Runtime       : 4 file(s) shipped, closure OK`.
The Universal CRT (`api-ms-win-crt-*`, `ucrtbase.dll`) is part of Windows
10 and later and is not shipped. The signing sweep leaves Microsoft's
signature on these files (see Code Signing). Debug trees are untouched
(debug CRT from Visual Studio, never shipped).

Application-local deployment means the shipped runtime takes precedence
over any system-wide copy for the whole process, plugins included; see
`06-plugin-architecture.md`, section "Visual C++ Runtime", for what that
means for plugin authors.

### Legacy: Populate Build Directory

Upstream Open Salamander's `src\vcxproj\!populate_build_dir.cmd` copied the
MSVC redistributables, the Universal CRT, conversion tables and support
files into the output tree from hard-coded absolute paths. It is kept for
reference only; `build.cmd full` (runtime data) and `build.cmd release`
(runtime DLLs) cover everything it did that is still shipped.

## Build Logs

rebuild.cmd generates detailed logs:

| Log | Content |
|-----|---------|
| `rebuild_debug_x86.log` | Full build output |
| `rebuild_debug_x86.log.err` | Errors only |
| `rebuild_debug_x86.log.wrn` | Warnings only |
| `rebuild_times.log` | Build timing |

Similar logs are generated for each configuration.

## Linker Dependencies

### Main Application (salamand.exe)

```
htmlhelp.lib   — HTML Help API
comctl32.lib   — Common controls
mpr.lib        — WAN networking
wsock32.lib    — Winsock
netapi32.lib   — Network APIs
msimg32.lib    — Imaging functions
shlwapi.lib    — Shell utilities
```

Stack reserve: 3 MB (3,145,728 bytes)

### Plugins

```
comctl32.lib   — Common controls (all plugins)
```

Each plugin has a `.def` file for explicit DLL exports.

## Cleaning Build Artifacts

| Script | Description |
|--------|-------------|
| `!clean_all_interm.cmd` | Clean intermediate files from source AND build directories |
| `!clean_src_interm.cmd` | Clean VS cache, .aps, .ncb, .sdf files from source only |
