# Tandem Commander — Project Context

Two-panel file manager for Windows, derived from Open Salamander (GPLv2,
open-sourced 2023). Pure WinAPI C++ — no MFC, no Qt, no cross-platform
framework. C++20 (`/std:c++latest`), MSVC v143 (VS2022), MSBuild, Windows 11+.
Plugins are `.spl` (DLL) + `.slg` (language resource).

**This file is loaded into every session — keep it short.** Per-feature
notes go to `specs/FEATURE-HISTORY.md`, long-form facts to
`architecture/12-project-reference.md`. Add here only a rule that must change
how future work is done (one or two lines, with the feature number). Do not
add *Recent Changes* / *Active Technologies* sections.

## Where things are

| Need | Read |
|------|------|
| What to work on next | `specs/NEXT-WORK.md` — single entry point, section *Open items at a glance*; per-feature `REMAINING-WORK.md` files hold the detail |
| What a feature did, its traps and evidence | `specs/FEATURE-HISTORY.md` — search `^- NNN-` or use its index by area; **read the entries of the area before changing it** |
| Full record of a feature | `specs/NNN-*/` — `fix-log.md`, `closing-report.md`, `research.md`, `contracts/`, `probe/` |
| Identity, build policies, key facts in full | `architecture/12-project-reference.md` |
| Architecture (build pipeline, dependencies, plugin API, plugin catalog, code standards) | `architecture/README.md` → `01`–`12`; `06` = plugin API, `11` = WebView2 **binding contract** |
| Principles | `.specify/memory/constitution.md` (v3.0.0): build reproducibility, backward compatibility (baseline 0.1.0), incremental modernization, Windows commitment, plugin architecture preservation, UI consistency |
| Released versions | `CHANGELOG.md`; public privacy claim `PRIVACY.md` |

## Product identity

- **Tandem Commander 0.1.9** (internal build 193, release dated 2026-10-07;
  carries features 083–121 and 123; previous: 0.1.8 / build 192 / tag
  `v0.1.8`). Plugin interface version (`LAST_VERSION_OF_SALAMANDER`) **107** —
  independent, changes only with the plugin API.
- **A release** bumps, in the same change as the `CHANGELOG.md` entry:
  `VERSINFO_SALAMANDER_*` + `VERSINFO_BUILDNUMBER` in
  `src/plugins/shared/spl_vers.h`, `MyAppVersion` in
  `setup/tandemcommander.iss`, the line above, and the validity line of
  `PRIVACY.md`. The installer keeps the name
  `tandemcommander-<ver>-x64-setup.exe` and the GitHub release is published
  with it attached (the new-version check builds that address, 123). A bumped
  tree is not a published release — check the git tag.
- Binary `tandemcommander.exe`; registry root
  `HKCU\Software\Tandem Commander\0.1` (never reads or writes Open
  Salamander / Altap / Newt Commander keys); https://tandemcommander.org,
  github.com/tandemcommander/tandemcommander.
- **Upstream names stay**: source files, classes, `salamand.sln`,
  `salamand.vcxproj`, `SALAMANDER_*` — rename only user/OS-visible identity.
- Copyright: up to 2026 "Open Salamander Authors", from 2026 Pavel Stupka —
  the holder is defined once (`VERSINFO_HOLDER_TANDEM` in `spl_vers.h`) and
  never spelled out; About/splash notices live in `src/versinfo.rh2`, not in
  the language files. Brand assets: `tools/brand/README.md`.

## Build

```batch
build.cmd                 :: Debug x64 incremental (from the repository root)
build.cmd rebuild         :: clean + rebuild Debug x64
build.cmd full            :: + runtime data, plugins.ver, language modules
build.cmd full release    :: complete Release x64 (LTO; VC++ runtime copied in)
build.cmd full release sign [setup]   :: signed tree (+ signed installer)
```

- Output: `OPENSAL_BUILD_DIR` (default `.\build\`). Python is required (the
  build fails without it — encoding guard `tools/check_encoding.py`).
- `plugins.cfg` (`name=on|off`, 20 on / 11 off) decides which plugins are
  built and shipped; `translations/languages.cfg` (`enabled = on|off`, 8 of
  11 on — zh-CN, ru, uk off) which languages. Both are validated and the
  output tree reconciled on every run.
- Solution: `src/vcxproj/salamand.sln`, 79 projects. Plugin project:
  `src/plugins/<name>/vcxproj/<name>.vcxproj` (+ `lang_<name>.vcxproj`),
  property sheets in `src/plugins/shared/vcxproj/`.
- All dependencies are vendored (`src/common/dep/`), zero NuGet.
- Tests: `saltests` (pure rules from `src/common/`, 18,184 checks at 123);
  GUI probes per feature in `specs/NNN-*/probe/`.
- Sources: UTF-8-BOM, clang-format; new comments in English (legacy Czech
  stays).
- Branches: `main` = stable, `ai-main` = AI-assisted development; feature
  branches `NNN-name`.

## Repository map

`src/` (core; `common/` shared code and `dep/`; `plugins/` 31 plugins +
`shared/`; `vcxproj/`; `lang/`; `shellext/`) · `setup/` installer ·
`translations/` · `help/` · `tools/` (brand, codesign, winget, checks,
`run_on_hidden_desktop.ps1`) · `architecture/` · `specs/` · `doc/` licences.

## Standing rules

Each is one line of a longer story; the number is the feature whose entry in
`specs/FEATURE-HISTORY.md` explains it. Read that entry before working nearby.

**Text and names**
- Paths and names in the core are **UTF-8, precisely WTF-8** (`SalWToU8` /
  `SalU8ToW`, 066); plugin metadata is UTF-8 by contract (052). Never pass
  them to an `A` API or convert with `CP_ACP`; `tools/check_encoding.py`
  enforces it (strict rules, `TOTAL: 0`).
- "The same name" is the file system's rule: `SalNameEqualOrdinalCI`,
  `SalNameCompareOrdinalCI`, `SalPathEqualOrdinalCI`,
  `SalPathHasPrefixOrdinalCI` (092; header-only `salnameorder.h` for plugins,
  115). Byte-compared identity keys: `SalNameIdentityKeyAlloc` (109). No
  byte-length guard before comparing.
- `LoadStr` is code page; UTF-8 sinks take `LoadStrU8`, wide sinks `LoadStrW`.
- Text controls: wide message loops and `AttachToWindowKeepKind`, never a
  code-page subclass on an edit (093, 102, 104, 116). Top-level window titles:
  `SalSetWindowTitleW` / `SplSetWindowTitleW`; controls keep `SetWindowTextW`
  (100).
- **A path or name is never cut** — refuse (`IDS_TOOLONGPATH`) or use a heap
  buffer; if text must be shortened, cut at a whole character (097, 098, 101).
  Buffers the core fills are `SAL_MAX_PATH_UTF8` / `CSalMaxPathBuffer` (088).
- `A` shell/dialog APIs use best-fit mapping (`voilà` → `voila` = another
  file). Plugins ask for a file or folder with `SplGetFileNameU8` /
  `SplBrowseForFolderU8`, not the core's code-page services (104).
- A winliblt `EditLine` value that does not fit is refused; a refusal is
  never stored as an empty value or acted upon (104).

**Never lose the user's data**
- A "safe to delete?" check fails closed: not everything checked = unsafe
  (098). Every *Move* route into an archive or file system calls
  `ScanMoveSelectionForDirLinks` first (099).
- Same-file decisions go by identity, not by name: `src/common/salsamefile.h`
  (103, 106, 107, 119).
- Replacing a user's file: temporary file + `SalReplaceWithTempW`
  (`salsafereplace.h`, 105). A replaced archive member is deleted only once
  its replacement is stored (110, 113).
- Security-relevant random bytes: `SalGenRandom` (`salrandom.h`, 086).
- Archive item names are cleaned at listing and again at extraction
  (`salarcname.h`, 087); a password typed as part of an address never reaches
  a history (`salurlpwd.*`, 085).

**Plugins and shared engines**
- The plugin ABI is append-only; older plugins keep loading. Changes go
  through a contract in `specs/NNN-*/contracts/` and `spl_vers.h` history.
- Closing for an installer's update: decide at the question without side
  effects, act at the instruction with `UnattendedClose`; a plugin window
  with nothing to lose declares `SetWindowClosesUnattended` (080, 088, 118).
- WebView2: `architecture/11-webview2-integration.md` is binding — one user
  data folder, one `TcWebBrowserArguments()` (exactly one definition in the
  tree), one environment-options builder; host code lives in
  `src/common/webhost/` and is never copied (081, 085).
- Shared rules for projects that cannot compile a `.cpp` from `src/common`
  (ZIP and other plugins) are header-only.

**Public claims, installer, translations**
- `PRIVACY.md` (*Privacy statement*) is a public claim referenced by winget.
  Update it **in the same change** as: new or changed network communication
  (also a new URL the program opens); a plugin enabled in the default build
  or a disabled one shipped; a change to what is stored, where, or how
  credentials are protected; a change to crash reporting; a change to what
  the installer or uninstaller writes or removes — and its validity line on
  every release. Claims cite *reachable* code (083).
- Installer: keep `PrivilegesRequiredOverridesAllowed=dialog` (winget depends
  on it, 072); never use `[InstallDelete]` (Restart Manager, 080);
  `ProductCode` moves with `AppId`. Shipped Microsoft runtime DLLs are never
  re-signed (077).
- New or removed UI strings break `build.cmd full` until the two-stage `.slt`
  refresh runs (`translate.merge`, pass `--templates`). Use free slots in an
  existing string bundle; removing whole bundles needs a re-key first (084).
  DeepL drifts to the informal register for de/fr/nl/es — pin in
  `translations/ui-overrides.json`. `PackErrorHandler` shows ids >= 11101 as
  questions.

## Working method

- **Measure first.** Backlog notes and "obvious" premises were wrong often
  enough (093, 095, 100, 104): reproduce on the build before, check that the
  defect is reachable, then fix. A negative control that does not fail is a
  finding.
- Keep a running `fix-log.md` in `specs/NNN-*/` while working. Put pure
  decisions in a header under `src/common/` with `saltests` checks.
- GUI probes run on the hidden desktop (`tools/run_on_hidden_desktop.ps1`):
  the maintainer works on the machine. Probes share the product's registry
  key — back it up and restore it; never write the real wallpaper (dry-run
  seam, 111). No real keyboard or clipboard there: record such rows as NOT
  DRIVEN and as a step owed to a person.
- Have an independent agent review a finished fix (refute-first); reviews
  rejected fixes that built and tested green in 075, 085, 087, 093, 098, 109,
  111, 117.
- Serious defects found on the way go to `specs/NEXT-WORK.md` and are fixed
  one by one, not inside the current feature.
- Do not push or publish from an implementation session; build, tag, GitHub
  release and winget submission are the maintainer's steps.
- Write scripts with the editor tools — Bash here-documents collapse doubled
  backslashes (123).

## Status (2026-10-07)

Features up to 121 are done and GUI-verified on the hidden desktop; 123 (new
version check) is implemented and verified, its person steps owed
(`specs/123-new-version-check/closing-report.md`). **0.1.9** is tagged
(`v0.1.9`); the winget submission waits until
`microsoft/winget-pkgs#426090` is settled.
