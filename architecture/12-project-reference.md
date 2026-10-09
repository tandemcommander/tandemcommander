# Project Reference — long form

The detailed paragraphs on product identity, build policies, key facts and
technologies. They were part of `CLAUDE.md` until 2026-10-09 and were moved
here unchanged so that they are not loaded into every session; `CLAUDE.md`
keeps a short form of each and points here.

Read the section you need when you work on: the copyright notices, the
release mechanics, the plugin or language build policy, the shipped Visual
C++ runtime, missing dependencies, the privacy statement's update rule, the
code-signing or translation tool chain, or WebView2 hosting (the binding
contract itself is `11-webview2-integration.md`).

When a fact here changes, change it here and — only if the short form is
affected — in `CLAUDE.md`.

## Product Identity (established in feature 032, renamed in feature 046)

- **Product name**: Tandem Commander, version **0.1.9** (internal build 193,
  release dated 2026-10-07 — it carries features 083–121 and 123,
  everything made since 0.1.8 / build 192 / tag `v0.1.8`);
  released versions and what changed in each are recorded in `CHANGELOG.md`
  (mandatory per the constitution: a release bumps
  `VERSINFO_SALAMANDER_*` + `VERSINFO_BUILDNUMBER` in
  `src/plugins/shared/spl_vers.h`, `MyAppVersion` in
  `setup/tandemcommander.iss`, and this line, in the same change as the
  changelog entry; the plugin interface version
  `LAST_VERSION_OF_SALAMANDER` is independent and changes only with the
  plugin API). Version 0.1.0 was the first public release;
  known as Newt Commander before feature 046 — the rename covered every
  user/OS-visible surface, kernel-object/IPC names, URLs, translations and the
  installer (new AppId), with **no** config import from the old registry root
- **Binary**: `tandemcommander.exe` (set via `<TargetName>` in `salamand.vcxproj`)
- **Registry root**: `HKCU\Software\Tandem Commander\0.1` — never reads or
  writes Open Salamander/Altap/Newt Commander registry keys (no config import)
- **Websites**: https://tandemcommander.org · repo github.com/tandemcommander/tandemcommander
- **Copyright rule**: years up to 2026 → "Open Salamander Authors",
  2026 onward → **Pavel Stupka** (sftp+mdview plugins are solely his).
  The holder name is defined **once**, as `VERSINFO_HOLDER_TANDEM` in
  `src/plugins/shared/spl_vers.h`; every notice concatenates it
  (`"… , © 2026 " VERSINFO_HOLDER_TANDEM`) and never spells it out — that
  covers all 30 `versinfo.rh2` files, the standalone `.rc` files
  (shellext, zip sfx trio, fcremote, salpvenv) and the two
  hardcoded strings in `plugins2.cpp` / `zip/add_del.cpp`. The two
  notices shown in the About dialog and on the splash screen live in
  `src/versinfo.rh2` (`VERSINFO_COPYRIGHT_TANDEM` above
  `VERSINFO_COPYRIGHT_OPENSAL`) and are never translated — the About
  controls carry an empty caption in `lang.rc`. Do not look for this
  text in the language files (feature 040).
- **IMPORTANT**: source files, functions, classes, project/solution names
  (`salamand.sln`, `salamand.vcxproj`, `SALAMANDER_*` constants) deliberately
  keep their upstream names — rename only user/OS-visible identity
- **Brand assets**: `tools/brand/` — hand-swappable sources (feature 035):
  `icon-master.png` (+ optional `icon-<N>.png` overrides) → all shipped
  `.ico`; `about.png` → `src/res/logo.png` (About + splash artwork);
  `python tools/brand/gen_icons.py` regenerates everything, see
  `tools/brand/README.md`

## Technology

- **Language**: C++ (C++20, `/std:c++latest`)
- **Compiler**: MSVC v143 (Visual Studio 2022)
- **Platform**: Windows 11+, pure WinAPI
- **Build system**: MSBuild (`.sln` / `.vcxproj` / `.props`)
- **Plugin format**: `.spl` (plugin DLL) + `.slg` (language resource)

## Repository Structure

```
src/                   All source code (~2,224 files)
  common/              Shared libraries and headers
    dep/               Third-party libs (zlib, bzip2, sqlite, fmt, wil...)
  plugins/             31 plugins (archive, viewer, utility, network)
    shared/            Shared plugin build infrastructure
  vcxproj/             VS solution (salamand.sln) and project files
  lang/                English resources for main app
  shellext/            Shell extension (x86 + x64)
  setup/               Installer/uninstaller
architecture/          Architecture documentation (see below)
convert/               Character conversion tables
doc/                   License files, third-party notices
help/                  User manual source (HTML Help)
tools/                 Build utilities (code signing, timing)
translations/          UI translations
```

## Build Quick Start

```batch
set OPENSAL_BUILD_DIR=D:\Build\OpenSal\
build.cmd                       :: Debug x64 incremental build (from repo root)
build.cmd rebuild               :: Full clean + rebuild Debug x64
build.cmd full                  :: Complete build: also copies runtime data
                                ::   (convert tables, toolbars, scripts) and
                                ::   generates plugins\plugins.ver so all
                                ::   enabled plugins auto-register in
                                ::   Plugin Manager
build.cmd full release          :: Complete Release x64 build
```

**Plugin build policy**: `plugins.cfg` in the repository root decides
which plugins are compiled and shipped (`name=on|off`, one line per
plugin; currently 20 on / 11 off). Every `build.cmd` run validates the
file, builds only enabled plugins (via a generated solution filter
`src\vcxproj\salamand.gen.slnf`, gitignored), and removes outputs of
disabled plugins. See `specs/007-plugin-build-policy/`.

**Language build policy**: `translations/languages.cfg` decides which
languages are built and shipped — each `[folder]` section carries
`enabled = on|off`, the language counterpart of `plugins.cfg`. Every
`build.cmd` run validates the registry and reconciles the output tree
(any `.slg` not belonging to an enabled language is deleted from `lang\`
and `plugins\*\lang\`); language modules are *produced* only on a full
build. Currently 8 of 11 enabled — Simplified Chinese, Russian and
Ukrainian are off pending a menu rendering defect; their translation
source is retained, so re-enabling is one line. Authoring tools skip
disabled languages by default (`translate.merge --language <folder>` is
the opt-in). See `specs/039-language-build-policy/`.

Alternative scripts in `src\vcxproj\`: `build.cmd` (simple), `rebuild.cmd` (interactive menu) — these build the full solution and ignore `plugins.cfg`.

**Prerequisites**:
- Windows 11 or newer
- Visual Studio 2022 (Community, Professional, or Enterprise)
- "Desktop development with C++" workload installed in VS2022
- Windows 10/11 SDK (any version; projects use `10.0` = latest installed)
- Environment variable `OPENSAL_BUILD_DIR` (optional — defaults to `.\build\`)

## Key Facts

- **79 projects** in salamand.sln (1 main app, 31 plugins, 32 lang
  modules, 6 helper libs, 3 utilities, 2 shell exts, 3 setup, 1 other;
  the `salspawn` helper left in feature 084, `7zwrapper` in feature 087)
- **Plugin set is policy-driven**: 8 obsolete plugins were removed in
  feature 007 (pak, unarj, unlha, unfat, wmobile, ieviewer, splitcbn,
  winscp); `plugins.cfg` disables 10 more by default (demos and
  marginal plugins), so a default build ships 20 plugins
- **All dependencies are embedded** — zero NuGet packages
- **Visual C++ runtime ships with the product** (feature 077):
  `build.cmd release` copies `vcruntime140/vcruntime140_1/msvcp140/concrt140`
  from the located VS installation into the tree root and
  `tools/check_runtime_deps.py` proves every shipped module's runtime
  imports resolve there; the signing sweep leaves Microsoft's signature on
  them. Plugin authors: toolset no newer than the shipped runtime.
- **Missing deps**: unrar.dll (unrar - not needed: RAR is read by the
  7zip plug-in's own engine, 7-Zip 26.03 since feature 087, whose RAR
  decoder carries the "unRAR restriction" the maintainer accepted in
  feature 084; unrar.dll *is* redistributable, the issue is GPL
  compatibility), OpenSSL (ftp); pictview runs on
  the built-in Windows WIC engine since feature 006 (no pvw32cnv.dll
  needed)
- **Encoding**: UTF-8-BOM, formatted with clang-format
- **Comments**: Legacy Czech OK, new comments in English
- **Debug builds** use fixed base addresses (no ASLR) for leak detection
- **Release builds** use LTO/WPO and code signing
- **Privacy statement** (feature 083): `PRIVACY.md` is a **public claim**
  about the shipped product, referenced by the winget `PrivacyUrl`
  (`tools/winget/templates/locale.en-US.yaml.in`). It MUST be updated **in
  the same change** as any of: new or changed network communication
  (including a new URL the program opens); a plugin enabled in the default
  build (`plugins.cfg`) or a disabled one shipped; a change to what is
  stored, where, or how credentials are protected (fixing any of the
  NEXT-WORK item 7 defects F1–F9 counts); a change to crash reporting; a
  change to what the installer or uninstaller writes or removes. Update its
  validity line ("describes Tandem Commander <version>. Last updated …")
  with it, and on every release. Evidence for each claim:
  `specs/083-privacy-policy-winget/research.md` + `fix-log.md` claim map

## Compiler Recommendation

- **Primary**: MSVC 2022 (full compatibility, zero effort)
- **Secondary CI**: Clang-cl (catches extra bugs, MSBuild-compatible)
- **Not viable**: MinGW-w64 (no x86 SEH, no MSBuild)

## Plugin Build Pattern

Each plugin: `plugins/<name>/vcxproj/<name>.vcxproj` → outputs `<name>.spl`
Each language: `plugins/<name>/vcxproj/lang_<name>.vcxproj` → outputs `english.slg`
Property sheets: `plugins/shared/vcxproj/plugin_base.props` + debug/release variants

## Branching Strategy

- **`main`** — upstream/stable branch
- **`ai-main`** — main branch for AI-assisted development
- Feature branches (e.g., `003-speckit-review`) are created from and merged into `ai-main`

## Active Technologies
- Windows Batch script (.cmd) + MSBuild (from VS2022), vswhere.exe (002-msvc-x64-build-script)
- C++ (C++20, `/std:c++latest`), MSVC v143 (VS2022) + Pure WinAPI (no frameworks); internal shared libs (`src/common/`); no new external dependencies (004-long-paths-unicode)
- Windows Registry for configuration (`REG_SZ` string values); NTFS/exFAT/FAT/network file systems as managed objects (004-long-paths-unicode)
- Translation data: `translations/<language>/<module>.slt` UTF-8-BOM text archives, committed; consumed at build time by `translator.exe` quiet modes to produce `<language>.slg` (038-translations-build-integration)
- Python 3.13 (`tools/`, `pyproject.toml`) + `anthropic` SDK for offline machine translation — developer-side only, never invoked by the build (038-translations-build-integration)
- Language build policy: `translations/languages.cfg` `enabled = on|off` per language; validated and reconciled by `src/vcxproj/lang_policy.ps1` on every `build.cmd` run (039-language-build-policy)
- Code signing: `tools/codesign/codesign.cfg` (committed profile: certificate SHA-1 thumbprint + Certum timestamp URL) consumed by `tools/codesign/sign_release.ps1` (Windows PowerShell 5.1 sweep, idempotent) and `setup/build_setup.cmd`; signtool.exe from the Windows SDK; Inno Setup 7 for the installer (050-code-signing)
- SFTP plugin: vendored libssh2 1.11.1_DEV (`src/common/dep/libssh2`) on the WinCNG backend (`LIBSSH2_WINCNG` + `LIBSSH2_ECDSA_WINCNG` — RSA/ECDSA only, no ed25519, no OpenSSL); test harness `src/plugins/sftp/test/` runs against a local Docker reference server (container `tandem-sftp`, localhost:2222) (051-fix-sftp-keyauth-hang)
- **WebView2 shared-engine contract** — MANDATORY for any plugin embedding
  WebView2 (planned: formatted source viewer, WebGPU), see
  `architecture/11-webview2-integration.md`: one canonical user data folder
  `%LOCALAPPDATA%\Tandem Commander\WebView2` (a different UDF spawns a
  separate cold browser tree), one browser-arguments set — **exactly one
  definition in the tree**, `TcWebBrowserArguments()` in
  `src/common/webhost/webhost.cpp` (later environments' args are silently
  ignored — extensions are coordinated changes there, never per-plugin
  overrides), per-controller security stays per-plugin, and each plugin arms
  its own session-long keeper at its own first use (any one live controller
  keeps the warm tree for all). SDK vendored at `src/common/dep/webview2/`
  (v1.0.4078.44). **The lift is complete since feature 081**: both mdview and
  codeview run on `src/common/webhost/` (`CTcWebHost`, `CTcWebKeeper`) and
  keep only a COM-free `webglue.{h,cpp}`; a third consumer adds those two
  `.cpp` files to its project and fills a `TcWebHostConfig` — it never copies
  code
