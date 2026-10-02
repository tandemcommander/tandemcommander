# Tandem Commander — Project Context

## What Is This?

Tandem Commander is a two-panel file manager for Windows, derived from
Open Salamander (open-sourced under GPLv2 in 2023). It is a pure
WinAPI C++ application — no MFC, no Qt, no cross-platform frameworks.

## Product Identity (established in feature 032, renamed in feature 046)

- **Product name**: Tandem Commander, version **0.1.8** (internal build 192,
  release dated 2026-09-20 — it carries features 075, 077, 078, 079, 080
  and 081, everything made since 0.1.7 / build 191 / tag `v0.1.7`);
  released versions and what changed in each are recorded in `CHANGELOG.md`
  (mandatory per the constitution: a release bumps
  `VERSINFO_SALAMANDER_MINORB` + `VERSINFO_BUILDNUMBER` in
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

## Architecture Documentation

Detailed analysis is in the `architecture/` directory:

| Document | What It Covers |
|----------|---------------|
| [01-project-overview.md](architecture/01-project-overview.md) | History, tech stack, repo layout |
| [02-solution-structure.md](architecture/02-solution-structure.md) | All 90 projects with categories |
| [03-build-pipeline.md](architecture/03-build-pipeline.md) | Build scripts, configs, output paths |
| [04-dependencies.md](architecture/04-dependencies.md) | Third-party libs, missing deps |
| [05-compiler-comparison.md](architecture/05-compiler-comparison.md) | MSVC vs Clang-cl vs MinGW vs Intel |
| [06-plugin-architecture.md](architecture/06-plugin-architecture.md) | Plugin API, .spl/.slg format |
| [07-preprocessor-defs.md](architecture/07-preprocessor-defs.md) | All #defines by configuration |
| [08-code-standards.md](architecture/08-code-standards.md) | Encoding, formatting, conventions |
| [09-plugin-catalog.md](architecture/09-plugin-catalog.md) | All 36 plugins categorized by purpose |
| [10-plugin-maintenance-outlook.md](architecture/10-plugin-maintenance-outlook.md) | Per-plugin 2026+ maintenance assessment (Czech) |
| [11-webview2-integration.md](architecture/11-webview2-integration.md) | **Binding contract** for any plugin embedding WebView2: canonical user data folder, single browser-arguments helper, keeper pattern (warm shared engine) |

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

## What To Work On Next

`specs/NEXT-WORK.md` is the single entry point for continuing work — a
consolidated, prioritized ordering of the per-feature handoffs
(`specs/069-finish-encoding-fixes/REMAINING-WORK.md`,
`specs/070-source-viewer-plugin/REMAINING-WORK.md`,
`specs/072-winget-distribution/REMAINING-WORK.md`,
`specs/080-restart-manager-upgrade/REMAINING-WORK.md`), which stay authoritative
for the detail and the reasoning behind each item. Start there rather than
re-deriving the order from the individual files.

## Constitution

Project principles are in `.specify/memory/constitution.md`
("Tandem Commander Constitution", v3.0.0): build reproducibility,
backward compatibility (baseline Tandem Commander 0.1.0 — the break
with Open Salamander 5.0 was made in feature 032, the Newt→Tandem
rename in feature 046; both deliberate, documented, one-time),
incremental modernization, Windows platform commitment,
plugin architecture preservation, UI consistency.

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->

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

## Recent Changes
- 002-msvc-x64-build-script: Added Windows Batch script (.cmd) + MSBuild (from VS2022), vswhere.exe
- 038-translations-build-integration: 12 shipped languages (English + 10 existing + new machine-translated Ukrainian) x 20 enabled modules; `.slt` import is strictly positional, so translation source is always regenerated from a current-structure English template
- 039-language-build-policy: which languages ship is now a committed policy (`enabled = on|off` in `translations/languages.cfg`), honoured by the build on every run; 3 non-Latin-script languages disabled pending a menu rendering defect, source retained
- 046-tandem-commander-rebrand: product renamed Newt Commander → Tandem Commander (`tandemcommander.exe`, registry root `HKCU\Software\Tandem Commander\0.1`, TandemCommander*/TCExten_* kernel/IPC names, tandemcommander.org, new installer AppId, new icon/artwork from `tools/brand/`); no config migration; upstream `salamand*`/`SALAMANDER_*` names retained
- 050-code-signing: on-demand release signing — `build.cmd full release sign [setup]` signs all shipped PE artifacts (exe/dll/spl/slg, ~206 files) via idempotent sweep `tools/codesign/sign_release.ps1` + compiles a signed Inno Setup installer (`setup/build_setup.cmd [sign]`, `#ifdef SIGN` in the .iss); default builds never sign (per-target hook `sign_with_retry.cmd` is a no-op unless `TC_CODESIGN=1`); Release trees no longer contain `.pdb/.lib/.exp` (redirected to `obj\` by `src/Directory.Build.targets`, cleaned + installer-excluded as safety nets)
- 052-fix-plugin-name-encoding: Plugins Manager showed mojibake names of
  not-loaded plugins in non-English UI. Root cause: `CPluginData::Name` had no
  defined encoding — CP1250 from a loaded plugin (`LoadStringA`) but UTF-8 from
  the feature-004 registry facade — and the name column used the ANSI listview
  call. Fix: plugin metadata is **UTF-8 by contract** (normalized at intake via
  `SalLegacyToU8Alloc`, see `specs/052-.../contracts/plugin-metadata-encoding.md`),
  name column renders via `SalListViewSetItemTextU8`, 15 mixed-composition
  sites converted to `LoadStrU8`, `tools/check_encoding.py` tracks the contract
  identifiers, **`build.cmd` now fails when python is missing** (guard can't be
  silently skipped). ZIP plugin renamed to literal "ZIP" in all languages
  (was machine-translated as "postal code" in cs/sk/fr/es/zh), pinned in
  `translations/ui-overrides.json`. No registry migration — stored values were
  verified intact; the defect was display-only.
- 056-prerelease-review: release gate for **0.1.2** (build 186, released
  2026-08-07). Multi-agent review (6 independent perspectives — memory,
  concurrency, network security, credentials, encoding, tooling/data — with
  adversarial verification) over the whole `v0.1.1..HEAD` delta (features
  052–055). All four code-safety perspectives judged the delta itself clean;
  the only shipped-product regression was F1 (SFTP: Duplicate on the now-transient
  Quick Connect row produced an empty bookmark — `dialogs.cpp` gates it on
  `isBookmark` like Save/Rename/Delete). Deferred, non-shipping: a dev-only
  `addrows.py` bug left the 3 disabled languages' `sftp.slt` 5 rows short (fix
  before re-enabling them); pre-existing `plugins1.cpp` fixed-buffer patterns.
  Gates G1–G9 green (full Debug+Release build, saltests 1145/0, SFTP harness
  7/7 + leak check, key-format fixtures 66/0, slt round-trip, cs+en smoke,
  version sweep). Report: `specs/056-prerelease-review/review-report.md`.
- 055-contextual-retranslation: every machine-provenance UI string outside the
  SFTP plugin (≈3,300 entries, 8 enabled languages × 19 modules) re-translated
  with usage context — the feature-051 method applied product-wide. Tooling:
  `translate.merge --redo-machine` (demotes all `machine` `.origin` entries to
  gaps; human/skip untouched by construction) + repeatable `--exclude-module`;
  `uicontext._DOMAINS` now covers all 20 enabled modules. Latent pipeline
  defects fixed: translations identical to their English were re-sent to DeepL
  on every run (match.py now trusts the sidecar), `dedupe_accelerators` was
  exponential on salamand's large menus (proper Kuhn visited-set sharing:
  >4 min → 0.3 s per language) **and rewrote accelerators inside human
  translations** (human/skip rows are now frozen obstacles), overrides that
  matched the engine's output lost their `human` provenance, contexts were
  built 16× instead of once. 20 pins added to `ui-overrides.json` (mdview
  View-menu strings across 7 languages, theme names, plugin name). Run cost
  52,728 DeepL chars; verification: provenance-scoped diff over 59,360
  entries proves human/skip entries byte-identical (0 violations); details in
  `specs/055-contextual-retranslation/run-notes.md`.
- 051-fix-sftp-keyauth-hang: fixed whole-app freeze on private-key connect. Root cause was in vendored libssh2: `_libssh2_pem_parse_memory`'s scan loops never terminate when the expected PEM marker is absent (`readline_memory` cannot signal EOF), and the WinCNG in-memory loader only understood classic RSA/DSA PEM — so an OpenSSH-container key (ssh-keygen's default since OpenSSH 7.8) spun the CPU forever on the UI thread. Patched pem.c (bounds guards, documented in `src/common/dep/libssh2/readme.txt` "Local patches"), added openssh-key-v1 RSA/ECDSA import + classic-PEM passphrase decryption to the WinCNG memory path, real libssh2 error codes on key-load failures. Plugin side: connect runs on a worker thread with a cancellable wait window (prompts stay on the UI thread via a `cpHostKey`/`cpPassphrase`/`cpPassword` retry handshake), the socket stays non-blocking so libssh2's timeout is actually enforced, key-format gate rejects PKCS#8/ed25519/.ppk up front, error classification by code (not message substrings), password fallback on a server-rejected key, dead-transport detection + reconnect, cancellable F3 download. Test harness reworked onto the product's `publickey_frommemory` path with a hang watchdog (`test/run_keyauth.cmd`, 7 scenarios) plus key-format fixtures in `test/build_and_run.cmd`
- 058-fix-cloud-status-icons: three feature-004 regressions-by-omission
  garbled the UTF-8 panel path in code still treating it as ANSI, breaking
  every folder whose path contains non-ASCII characters (e.g. Google Drive's
  `G:\Můj disk`): no cloud sync-status overlay badges (icon-reader wide
  prefix converted via CP_ACP, `fileswn1.cpp`), generic file icons
  (`SHILCreateFromPath` CP_ACP, `geticon.cpp`), and silently dead
  auto-refresh causing a busy-cursor re-list on every window activation
  (ANSI `FindFirstChangeNotification` in `snooper.cpp`, 3 sites). All three
  converted to the house pattern `SalU8ToW`/`SalU8ToWAlloc` + CP_ACP
  fallback (legacy plugin callers of `GetFileIcon` keep working); new W
  overload in the HANDLES layer. The provider was never the trigger — ASCII
  OneDrive paths worked all along. Contract:
  `specs/058-fix-cloud-status-icons/contracts/path-encoding-icon-pipeline.md`.
- 066-fix-surrogate-filenames: files with unpaired UTF-16 surrogates in the
  name (legal on NTFS, e.g. `Lone<U+D800>surrogate.txt`) could not be deleted,
  copied, moved, renamed or viewed — the feature-004 intake
  (`SalConvertFindDataW`) substituted U+FFFD on the strict-conversion failure,
  so every operation recomposed a nonexistent path. Fix: the house converter
  pair `SalWToU8`/`SalU8ToW` is **WTF-8** — `SalWToU8` is total (a lone
  surrogate encodes as its 3-byte sequence `ED A0 80..ED BF BF`), `SalU8ToW`
  additionally accepts exactly those sequences and still rejects every other
  malformed input (the "valid UTF-8, else ANSI" heuristics depend on that);
  byte-identical to UTF-8 for all valid Unicode names. Display
  (`SalU8ToWDisplay`, `CStaticText::SetText`) decodes to the true unit
  (Explorer-parity notdef glyph). WTF-8-aware probes: registry facade both
  directions (`SalRegQueryValueExW8` read side had been *lenient* — stored
  surrogate values loaded as U+FFFD), `CopyTextToClipboardU8`,
  `SalLegacyToU8Alloc`; the F8 recycle-list build in `fileswn8.cpp` converted
  leniently and was the one residual operational site. Contract:
  `specs/066-fix-surrogate-filenames/contracts/name-encoding-wtf8.md`;
  saltests 1221/0 incl. a real-NTFS facade round trip (`TestWtf8FileOps`).
- 069-finish-encoding-fixes: implemented the contained remainder the 068 review
  handed off — **31 of its 34 confirmed findings fixed** plus D01–D05, in 11
  groups, one commit each. Three items were **already fixed** and are recorded
  verify-closed (F-P1-03 by X06/X07, F-P2-10 by X02 — it is the same site as
  F-P6-02, found twice by two perspectives — and the jump-list half of F-P1-25
  by X03), and five site references in the findings proved stale, so every task
  now begins with a "still defective at HEAD?" check. Highlights: the command
  line inserts the name you see (six lines at the sink — the control already
  writes and reads its text through the wide house helpers, so no selection
  offset, word-break callback or `WM_CHAR` unit moves; a name outside the code
  page now inserts as `?`, which needs the Unicode control of cluster B-1);
  Compare Directories, the archive-edit *Copy To…*, Explorer drops, shortcuts,
  the SFX/link/batch-wrapper operations, help and `config.reg` under an accented
  install path, `$(SalDir)`, the cloud entries (all three producers — the
  "OneDrive-specific" framing was refuted), the external archivers (**both**
  directions of the OEM boundary in one change, because they cancelled each
  other), volume/subst/label information with the Drive Information template
  (one commit — two of its rows render correctly *only* while their arguments
  stay code-page bytes), shares, the viewer's default conversion and caption,
  and the ZIP overwrite line. Two fixes were made **differently from the
  finding's own suggestion** after tracing the consumers: `CCodeTablesData::Name`
  is *not* re-encoded (those bytes reach plugins through
  `EnumConversionTables`, and `dbviewer`/`filecomp` persist them), so the
  viewer's stored default is repaired in the lookup instead; and the help chain
  moves as a whole (producer + search + `HtmlHelpW`), with the wide help call
  guarded because `dwData` may carry an ANSI topic/keyword/`HH_FTS_QUERY` from a
  plugin. New shared helpers: `SalU8TrimIncompleteTail` (drops a *torn* trailing
  UTF-8 sequence and leaves a complete character alone — the obvious version of
  this eats an accented last character) and `SalU8ToOEM`/`SalOEMToU8` for the
  archiver console boundary. Guard: `signed-char-name-byte` retired (its premise
  is void under `/J`) in favour of `acp-byte-table-on-name`, which is now the
  cluster B-2 work list (33 hits); `acp-title-seed` added and proven; strict
  stays `TOTAL: 0`, draft 183 → 148. saltests 1257 → **1289**. Plugin ABI
  untouched (interface 106). **Process**: four independent regression reviews,
  **two REJECTED** and corrected — a progress title blanked in five languages,
  and a half-converted chain that would have made the shell copy a stray
  `DROPFAKE` folder because the ANSI shell extension could not recognise the
  name. Deferred with written reasons, not dismissed: the five systemic clusters
  B-1–B-5, nine named sites (incl. `icncache.cpp`'s icon location and the
  DROPFAKE pair), and six newly found defects — the first of which,
  `codetbl.cpp:873`, is a one-byte buffer overflow and should be fixed first.
  Handoff: `specs/069-finish-encoding-fixes/REMAINING-WORK.md`; record:
  `closing-report.md`.
- 068-encoding-regression-review: product-wide review of encoding handling
  (the whole core, not one release delta) after feature 067 showed a defect in
  a surface earlier features were believed to cover. Seven charted perspectives
  inventoried 2,529 candidate sites across 8 boundaries; **76 findings raised,
  60 confirmed** by independent refute-first verifiers (8 refuted, 4 latent,
  2 by-design, 2 withdrawn). **9 fixes**, each accepted by a third agent that
  did not write it: command-line stack overrun (261-byte buffer vs a 765-byte
  name), taskbar jump list (ANSI `IShellLink` → mojibake *and* wouldn't open),
  per-drive remembered directory lost each restart, disk-cache/temp cleanup
  dead under a non-ASCII `%TEMP%` (incl. the `RemoveTemporaryDir` plugin
  service), rubber-band over-selection, a **regression feature 052 itself
  introduced** (`dialogs5.cpp:495`), ZIP overwrite prompt, filecomp blank
  title. Guard `tools/check_encoding.py` gains 3 strict rules (9 total), each
  **proven to fire** on a planted defect; 4 stay report-only behind deferred
  fixes; `signed-char-name-byte`'s premise is void — the product compiles
  with `/J`. saltests 1229 → **1257**. Plugin ABI untouched (no
  `src/plugins/shared/` or forwarder diff; interface 106).
  **Deferred with evidence, not dismissed** — 6 systemic clusters, each
  feature-sized: 88 of 90 dialogs are ANSI windows (non-ACP input becomes `?`
  and is *persisted* by Change Directory / Find / user menu), ACP byte tables
  behind all name comparison (`Č.txt` != `č.txt`), the undocumented UTF-8
  `GetErrorText` (~27 plugin sites; a naive sweep would *regress* FTP),
  `AlterFileName` (also drives Change Case, which renames on disk), the
  plugin-facing ANSI services (FR-009 freeze), and the remaining facade
  migration. Report: `specs/068-encoding-regression-review/review-report.md`.
- 059-fix-onedrive-syncing-badge: the sync-in-progress badge (blue arrows)
  now shows as in Explorer. Windows exposes cloud state through two
  channels; folders in a pending state are claimed by NO overlay handler
  (all seven OneDrive `IsMemberOf` return S_FALSE) — Explorer draws them
  from `PKEY_StorageProviderState` (documented "Property for the cloud file
  state icon"), which the overlay-only pipeline never read (missing since
  Open Salamander). Fix: property fallback in
  `CShellIconOverlays::GetIconOverlayIndex` — only when every handler
  declined AND the panel path is under a CFAPI sync root
  (`CfGetSyncRootInfoByPath`, cldapi.dll dynamic; `G:` letter drives are
  not CFAPI → unchanged); states {4,5,6,10} map to the synthetic overlay
  `TandemCloudSyncPending` (own icon `src/res/syncpend.ico`, generator
  `tools/brand/gen_overlay_syncpend.py`; disable-able via the existing icon
  overlay config). `GPS_DELAYCREATION|GPS_BESTEFFORT` keeps content
  property handlers from running (no hydration, no failures on malformed
  documents). Integration exposed + fixed a latent upstream RTC bug:
  uninitialized `HRESULT res` in `GetIconOverlayIndexAuxAux` when a reader
  slot is NULL. `cfapi.h` cannot be included at `_WIN32_WINNT=0x0601` —
  the two needed ABI-stable declarations are mirrored locally.
- 071-configurable-command-shell: the **Command Shell** command (`Num /`,
  `Ctrl+/`, Commands menu, toolbar button — one handler, `CM_DOSSHELL` →
  `CMainWindow::OpenCommandShell` in `src/cmdshell.cpp`) opens a user-chosen
  program: presets *Command Prompt* (default = the old `%COMSPEC%` launch,
  bit-for-bit), *Windows PowerShell*, *PowerShell 7*, *Windows Terminal*
  (`-d .`), *Git Bash*, or a *Custom* program + arguments (`$(FullPath)` = panel
  directory **without** a trailing backslash, root excepted — the User Menu
  *Initial Directory* meaning, table `CommandShellArgsExpArray` in
  `execute.cpp`; `$[ENV]`). Preset table + locate algorithm live in
  `src/common/salshell.*` behind an injectable probe (52 saltests checks with a
  fake machine; PowerShell 7 is looked up alias/MSIX first because its MSI is
  being phased out). Setting = 3 values under `Configuration` (`Command Shell
  Preset|Program|Arguments`), no config-version bump. New Configuration page
  *Command Shell* (`IDD_CFGPAGE_CMDSHELL`, `CCfgPageCmdShell`) inserted after
  *Hot Paths* — the hard-coded `mode == 3` page index in
  `CConfigurationDlg` moved 21 → 22; not-found presets are marked and refused
  on OK; empty Custom fields pre-fill from the previous preset. Encoding:
  `SalGetEnvVarU8` (wide env read) now also serves the shared `$[ENV]`
  expansion in `DoExpandVarString`; new `SafeGetOpenFileNameW` for the
  Browse button; launch errors composed from `LoadStrU8` with a Help button
  to the new manual topic `configuration_cmdshell.htm` (first help page
  authored after the rebrand: "Tandem Commander" + "© 2026 Pavel Stupka";
  the other 236 pages still carry the 2023 Open Salamander footer — a
  separate follow-up). Known/kept: `SalCreateProcess` never forwarded
  `lpTitle` (since feature 004) — untouched; Windows refuses a starting
  directory ≥ 259 chars for every program — the launcher retries with the 8.3
  form. Translations: `ui-overrides.json` pins make the page name follow each
  language's existing *Command Shell* menu term (cs "Příkazový řádek", de
  "Eingabeaufforderung", fr "Interpréteur de commandes", nl "Opdracht Shell",
  ro "Comanda Shell", sk "Príkazový riadok") and keep the corpus' formal
  register. GUI matrix (quickstart §3–§6) is a human step; see
  `specs/071-configurable-command-shell/fix-log.md`.
- 072-winget-distribution: Tandem Commander is published to the **Windows
  Package Manager** catalogue as `PavelStupka.TandemCommander` (moniker
  `tandemcommander`), so `winget install tandemcommander` / `winget upgrade`
  work - the product's first update path. The catalogue stores no binary, only
  three YAML manifests pointing at the GitHub release asset and pinning its
  SHA256, so publishing = a pull request to `microsoft/winget-pkgs`. Tooling in
  `tools/winget/`: the **templates are the source of truth** for all catalogue
  metadata (authoring comments are stripped on generation, so submitted
  manifests stay conventional - consequence: no line inside a YAML block scalar
  may start with `#`), and one entry point `publish.ps1` (Windows PowerShell
  5.1, `sign_release.ps1` tier) derives the version from
  `setup/tandemcommander.iss`, the release date **and release notes** from
  `CHANGELOG.md`, downloads the published asset, **verifies its Authenticode
  signature against `tools/codesign/codesign.cfg`**, hashes it, renders,
  `winget validate`s, and with `-Submit` hands the directory to `wingetcreate`.
  `.github/workflows/winget-publish.yml` runs the same script on
  `release: published` (pre-releases skipped) and degrades to
  generate-and-validate when `secrets.WINGET_PAT` is absent - the first
  workflow in the repository to use a secret. **No product file changes
  behaviour**: the plan called for adding `commandline` to
  `PrivilegesRequiredOverridesAllowed` in `tandemcommander.iss` so winget could
  pass `/ALLUSERS` / `/CURRENTUSER` in a silent install, plus a version gate
  keeping older releases from advertising a scope they could not honour. Both
  were **refuted by testing and removed**: Inno Setup enables the command-line
  scope switches for the `dialog` override mode too, which the installer has
  always had - a probe with the installer's exact privilege configuration
  installed per-user silently with no elevation. So `=dialog` stays (plus a
  comment: **do not narrow it, winget depends on it**), and 0.1.5 already
  offers **both** scopes. What replaces the gate is an invariant check -
  `publish.ps1` refuses to generate if that directive is missing, so the
  manifests can never advertise an install mode the installer would reject.
  `MinimumOSVersion: 10.0.19041.0` states what the binaries can run on
  (`_WIN32_WINNT=0x0601`), not the Windows 11 the project markets; winget
  refuses to install below it. `ProductCode` is the Inno key `{AppId}_is1` and
  must move with `AppId` or upgrade detection silently breaks. Real installs,
  the workflow run and the first (irreversible, public) submission are manual -
  see `specs/072-winget-distribution/quickstart.md` and `fix-log.md`.
- 075-fix-small-hardening: closed the six defects that were **recorded but not
  fixed** — the five from `069/REMAINING-WORK.md` §3 (which feature 069's own
  charter forbade it to touch, having no finding behind them) plus the Code
  Viewer test-runner note from 074. One commit per defect, each independently
  reviewed: `CCodeTables::GetCodeName` (**two** overflows, not the one recorded
  — a name of exactly the caller's buffer length wrote one byte past it *and*
  an unbounded `convert.cfg` name overran a 1024-byte stack scratch; one
  bounded `lstrcpyn` replaces both), the viewer's coding-menu default read
  before it was set, a NULL conversion name faulting inside the plugin-facing
  `GetConversionTable`, the viewer title torn mid-character on paths over 259
  bytes (the one user-visible item), the File Comparator's unbounded header
  copy, and `run_tests.cmd`'s Node-version-dependent verdict
  (`--experimental-detect-module`; detection is the default from Node **22.7**,
  not 22.12). **Plugin ABI untouched** — no `src/plugins/shared/` diff,
  interface 106, `saltests` unchanged at 1353/0 by design (contract C14: none
  of the sites is reachable from a test exe that links only `src/common/`).
  **Process, and the reason to keep it**: the independent review REJECTED the
  File Comparator fix — its walk-back ran unconditionally and ate the last
  character of an *untruncated* code-page name, reachable because
  `fcremote.exe` is an ANSI build — while the build, the tests and the evidence
  probe were all green; the same trap had been written into the *viewer title's*
  design hours earlier and simply not applied. Reviews also corrected three
  factual claims in the feature's own records. Evidence: a committed probe
  (`specs/075-fix-small-hardening/probe/`) compiling the verbatim pre- and
  post-fix bodies in canary arenas, 37 checks — its first two failures were
  fixture bugs, and after each review it gained the fixture class that would
  have caught what the reviewer found. **Still owed**: the GUI scenarios S1–S5
  and gate G6 need a person; this session could not drive the application or a
  debugger, which is recorded rather than worked around. Ships with 0.1.8;
  its changelog text is in that section of `CHANGELOG.md`.
- 077-fix-antivirus-findings: implements findings 3.2 and 3.3 of the 076
  antivirus false-positive review (`specs/076-avast-false-positive-review/`).
  **(a) The Visual C++ runtime ships application-locally**: every shipped
  module links the CRT dynamically but no release ever carried
  `vcruntime140.dll`, `vcruntime140_1.dll`, `msvcp140.dll`, `concrt140.dll`;
  on a machine without the redistributable the installer finished and the
  program failed with "VCRUNTIME140.dll was not found" (the likely "problem
  with the installation" of the user report). `build.cmd release` (full and
  incremental) now calls `src/vcxproj/copy_vc_runtime.cmd` (redist version
  from `VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt` of the
  `vswhere`-located VS, no absolute path) and then
  `tools/check_runtime_deps.py`, a stdlib PE import-table closure check that
  fails the build if any shipped PE imports a runtime DLL missing from the
  tree root; the installer packages the tree recursively and needed no
  change. `tools/codesign/sign_release.ps1` exempts validly Microsoft-signed
  files (never re-signed, `Exempt (Microsoft): 4`) and refuses a
  runtime-named file without a valid Microsoft signature (contract:
  `specs/077-fix-antivirus-findings/contracts/signing-exemption.md`, amends
  050 section 1). **(b) The in-process kernel32 patch is gone**:
  `callstk.cpp` no longer rewrites `kernel32!SetUnhandledExceptionFilter` in
  memory (`VirtualProtect` + `WriteProcessMemory` trampoline, an inline-hook
  pattern behaviour shields flag); the filter is registered normally and
  `CallStk_ReassertTopLevelExceptionFilter()` re-registers it from the
  15-second `IDT_ADDNEWMODULES` timer (`AddNewlyLoadedModulesToGlobalModulesStore`).
  `WriteProcessMemory`/`VirtualProtect` left the import table. Verified
  twice each: builds, checker negatives, loaded-module origin
  (`probe/check_loaded_crt.ps1`), crash parity with a cdb-injected fault
  (`probe/crash_inject.ps1`, app + zip.spl; the injected thread must be the
  window-owning one, woken by `WM_NULL` after `.detach`; with a debugger
  attached the registered filter is never called), re-registration under a
  breakpoint (`probe/reassert_filter.ps1`), signing sweep + negative
  (`probe/sign_exempt_negative.ps1`), silent per-user install/uninstall,
  saltests 1353/0. **Found on the way, out of scope**: the crash-reporting
  helper loaded `dbghelp.dll` only from its own `utils\` directory, which is
  not shipped, so no minidump has ever been produced in any release (text
  report only); and an old bug report left in `%LOCALAPPDATA%\Tandem
  Commander\` made the helper offer it at start-up while the main thread
  blocked (both gone with the helper in feature 079). **Owed human step**: the literal start on a clean
  Windows without the redistributable (Windows Sandbox / VM, admin needed).
  Record: `specs/077-fix-antivirus-findings/fix-log.md`.
- 078-panel-tabs: **panel tabs** (version 0.1.8, build 192 — the feature
  that bumped the version). Design Model A:
  each panel keeps its single `CFilesWindow`; a tab is a remembered view state
  (`CPanelTab` in `src/paneltabs.*`: location in external form, view template,
  sort, filter, cursor, selection, scroll, its own `CPathHistory`); switching =
  capture -> pre-set sort/filter/view -> the **unchanged** `ChangeDir` ->
  restore, so archives and plugin file systems keep their own leave rules
  (`CHPPFR_CANNOTCLOSEPATH` reverts everything; the SFTP plugin v1 closes on
  leave and reconnects from the saved password without a prompt). Strip
  `CTabWindow` (`src/tabwnd.*`) is owner-drawn on the shared `ItemBitmap` with
  the caption palette, never takes focus, and owns its context menu; pure rules
  (title derivation incl. WTF-8, index arithmetic, record clamping) live in
  `src/common/saltabs.*` under `saltests` (1353 -> 1405). Persistence: `{Left,
  Right} Panel\Tabs\<n>` subkeys + `Active Tab`, legacy values unchanged for
  the active tab, written only with the configuration; `Configuration\Panel
  Tabs` (default 1, documented exception to the opt-in principle). Left/Right
  menus gain a *Tabs* submenu (removed while off), 21 `CM_*` ids 2860-2880,
  Ctrl+Shift+T/W/PgUp/PgDn reserved in `IsSalHotKey` (Plugins Manager refuses
  them); the Appearance page got the checkbox and its three groups moved down
  12 dialog units. Plugin ABI untouched (interface 106), no
  `THIS_CONFIG_VERSION` bump. Verified by a PowerShell GUI driver against the
  Debug build (SFTP container, archive-update prompts, accented/Chinese/lone-
  surrogate titles, 20-tab overflow, skill levels, hotkey refusal, fresh and
  0.1.7-shaped registries). **Open**: two Debug-CRT leak reports of one
  88-byte block from a plugin module unloaded before the dump (six other runs
  clean; DBWIN listener recipe in the fix-log), and one unreproduced wrong
  landing after a USB drive arrived during the archive leave prompts -
  `SwitchToTab` now brackets `ChangeDir` with `BeginStopRefresh`/
  `EndStopRefresh` like the Change Directory dialog. Translations: 12 strings x
  8 languages via `translate.merge`, pins under `_feature_078` in
  `ui-overrides.json` (de *Registerkarte*, three close-confirmation strings
  repaired by hand). Record: `specs/078-panel-tabs/fix-log.md`,
  `closing-report.md`.
- 079-remove-salmon-crash-reporter: the out-of-process crash reporter
  (`utils\salmon.exe`, `src/salmon/`, `src/salmoncl.*`, its solution project,
  dialog `IDD_SALMON_MAIN` and 41 strings) is **gone** — antivirus engines
  flagged the helper (a background process holding the main process open to
  read its memory), its upload had been off since 0.1.0 and it never produced
  a minidump (no `dbghelp.dll` shipped, 077). The application now does the two
  things the helper did for it: it names the report
  (`TC<shortver>-YYYYMMDD-HHMMSS[-n].TXT`, pure formatter
  `src/common/salbugreport.*` under `saltests`, 1405 → 1427) and creates
  `%LOCALAPPDATA%\Tandem Commander` on demand (previously a report was
  silently lost when the folder did not exist), writes the same text report
  as before (`CreateFileW`, wide path end to end), and shows the closing
  message (`IDS_BUGREPORT_SAVED` / `_NOTSAVED`, `LoadStringW` — not
  `LoadStrW`, whose critical section the crashing thread may hold) from the
  bug-report thread with a new `MessageDone` handshake in
  `CCallStack::HandleException`, inline fallback, a re-entry guard for a
  nested fault on the handling thread and a guard for a crash inside the
  bug-report thread itself; exit code stays 1. No start-up prompt about old
  reports, no `Bug Reporter` registry key access, `CProcessListItem::SalmonPID`
  is `Reserved1` (same offset, always 0) so older instances (0.1.7, earlier
  0.1.8 development builds) and this build share the
  process list; `EnableExceptionsOn64` moved into `salamdr1.cpp`. `build.cmd`
  deletes a stale `utils\salmon.exe` from older output trees (MSBuild rebuild
  cleans only projects still in the solution and the installer packages the
  tree). Translations: two-stage refresh twice; **DeepL returned the informal
  register** for de/fr/nl/es (pinned formal under `_feature_079`), and the
  merge tool's string-table identity is the *bundle ordinal*, so removing
  whole 16-id bundles displaced 46 rows per language into DeepL — repaired
  from HEAD by script, dry run 0 gaps (tooling defect recorded, not fixed).
  Verified: full Debug + Release builds, crash probe (app + zip.spl targets,
  report path in the message text, BM_CLICK dismissal, exit code 1), Task
  List Break via `tools/salbreak`, start-up probes with stale reports and a
  fresh registry (backup/restore verified key by key), signing inventory,
  runtime-dependency check. The intermittent Debug-CRT 88-byte leak at exit is
  the 078 one (dump captured, `#File Error#(84)`), not new. No version bump
  of its own — it ships with 0.1.8 (the `## [0.1.8]` section of
  `CHANGELOG.md`), plugin ABI untouched (interface 106).
  Records: `specs/079-remove-salmon-crash-reporter/fix-log.md`,
  `closing-report.md`; probes under `probe/`.
- 080-restart-manager-upgrade: **closing for an update** (Restart Manager),
  ships with 0.1.8, no version bump of its own. The backlog's diagnosis
  (*"the program does not end when the installer asks"*) was **refuted by the
  reproduction it demanded**: updates over a running 0.1.7 failed because of
  `salmon.exe` — a process without a window cannot be closed by the Restart
  Manager, which then fails the *whole* request in milliseconds without asking
  the main program; feature 079 had already removed that. The real defects,
  measured first: an installer's request (`WM_QUERYENDSESSION` /
  `WM_ENDSESSION` with `ENDSESSION_CLOSEAPP`) ran the complete *interactive*
  exit inside the question, so a running file operation or an open plug-in
  viewer (the default F3 viewer) made the installer time out after 5 s, left a
  prompt on an unattended machine, and the program exited by itself when the
  prompt was answered later; the program was not started again; upgraded
  installations kept `salmon.exe`. Fix: **decide at the question**
  (side-effect-free `CMainWindow::DecideCloseApp` → pure
  `SalCloseAppDecide`, reasons D1–D8 in `src/common/salcloseapp.*` under
  `saltests`, 1427 → 1527), **act at the instruction** by re-entering the
  existing exit handler synchronously with the global **`UnattendedClose`**
  set — every prompt site on the exit path takes its negative branch without
  showing anything (`mainwnd3/4`, `fileswn2`, `plugins1`, `finddlg1`,
  `regwork`); it is the *opposite* policy of `CriticalShutdown` and is not
  exposed to plug-ins. The branch in `WM_ENDSESSION` is selected by the
  message, not by our agreement (a forced close delivers the instruction to a
  program that declined — measured), and the one `WM_CLOSE` the Restart Manager
  sends afterwards is swallowed. Scope guard: close-app flag set, critical
  flag clear, `SM_SHUTTINGDOWN` 0 — sign-out, shutdown, critical shutdown and
  the normal exit are untouched. `RegisterRestartForUpdates()`:
  `RESTART_NO_CRASH|NO_HANG|NO_REBOOT`, command line = identity only
  (`-t`, `-i`), state through the stored configuration. **An open plug-in
  window declines the update** — closing viewer windows silently needs a
  plug-in-visible signal (interface 107), handed over in `REMAINING-WORK.md`.
  Installer: the stale helper is deleted from `[Code]` at `ssPostInstall`,
  **never via `[InstallDelete]`** — entries of that section are registered
  with the Restart Manager, which brings exit 5 back for a running 0.1.7
  (measured; comment in the `.iss`). Verified with six committed probes
  (`probe/rm_probe.ps1` performs Inno Setup's Restart Manager sequence without
  an installer; `rm_protocol_dummy.ps1` logs what the Restart Manager really
  sends): 5/5 silent updates exit 0 and restart, busy states decline in 0.0 s
  with nothing on screen, configuration saved by the unattended close equals a
  manual exit's, upgraded file list identical to a fresh install; independent
  review: no blocker, three SHOULD-FIX fixed. Traps: `Start-Process -Wait`
  waits for the process *tree* (the restarted program is Setup's descendant —
  also corrected in 072 quickstart §2b), Git Bash rewrites `/SWITCH` arguments
  into paths, Setup ignores `/DIR` while an installation with the same AppId
  exists. Owed to a person: the elevated machine-wide update, a real
  `winget upgrade`, real sign-out/shutdown. Records:
  `specs/080-restart-manager-upgrade/closing-report.md`, `fix-log.md`.
- 081-mdview-shared-webhost: **one WebView2 host in the product**, ships with
  0.1.8, no version bump of its own, plugin ABI untouched (interface 106).
  Feature 070 lifted the hosting code to `src/common/webhost/` and built the
  Code Viewer on it but left the Markdown Viewer on its own 984-line copy
  (`webview.{h,cpp}`, `CMdWebHost`) — the duplication
  `architecture/11-webview2-integration.md` exists to prevent. That copy is
  **deleted**; mdview now configures `CTcWebHost`/`CTcWebKeeper` from a
  COM-free `webglue.{h,cpp}` holding only what is its own (the `doc.html` +
  `img/<n>` server with the WinHTTP consented fetch, the key map, the
  pre-065 folder janitor, the keeper's window-class identity), and the
  viewer window owns the `DocVersion` that cache-busts the document URL, as
  codeview's does. `MdKeeperArmed()` dropped (dead). The
  browser-arguments literal existed **three** times — including in
  `webkeeper.cpp`, whose comment claimed to include the one definition and
  did not — and is now `TcWebBrowserArguments()` in `webhost.cpp`, guarded by
  `rg -c "disable-features=msWebOOUI" src/` == 1. **mdview gained the shared
  host's stricter posture** with no visible change for ordinary documents:
  a content policy on the served document, downloads and permission requests
  refused, script dialogs off, the close-during-cold-start guard, the Debug
  lockdown read-back. Deliberately preserved: a broken `img/<n>` still
  answers **404**, not the host's 403. **The trap the contract now
  documents**: `TcWebResponse::Data` is read *after* `Serve` returns, so image
  bytes live in a scratch buffer owned by the callback — a vector local to the
  lambda dangles (codeview never met this; its answers outlive everything).
  Evidence: Debug + full Release builds; 29 generator assertions via the new
  `tests/mdview_htmlgen_test/build_and_run.cmd` (the `.vcxproj` was never
  committed — a gap open since 021); `check_csp_compat.py` shows the control
  document and the harness sample with **0 blocked references** under the new
  policy; `mdview_probe.ps1` 24 checks (smoke, 9 hostile fixtures, keeper
  warmth over 65 s, crash re-arm, 10 close-during-cold-start cycles,
  cross-plugin warmth from the Code Viewer); `render_diff.ps1` **0 of 729,144
  pixels differ** from the preserved pre-migration build
  `build\tandemcommander\Debug_x64_prefix081\` (**do not delete it** before
  the on-screen pass). **The independent review (no blocker, 3 SHOULD-FIX, all
  fixed) found that `CTcWebKeeper` allocated its state lazily and had no
  destructor — 88 bytes leaked per plugin per session since feature 070, even
  in a session where nothing was ever viewed** (the disarm on the unload path
  allocates it too). `sizeof` measured independently as exactly **88**, which
  matches the *"one 88-byte block from a plugin module unloaded before the
  dump"* that 078 and 079 both record as unexplained — **the most likely
  explanation of that leak, not proven**; check whether it is gone the next
  time that report appears. Also fixed: the image scratch buffer held the last
  served image (up to 64 MB) for the viewer window's life, and a comment in the
  shared keeper justified itself by a code path that does not exist. Owed to a
  person: `quickstart.md` § A–D — the network monitor over the hostile corpus,
  the *Keep the rendering engine ready* toggle, plugin unload/reload, dark
  menus. Records:
  `specs/081-mdview-shared-webhost/closing-report.md`, `fix-log.md`.
- 083-privacy-policy-winget: **`PRIVACY.md`** — the product's first privacy
  statement, written because winget moderators ask credential-storing
  packages for a `PrivacyUrl` (072 REMAINING-WORK § P0). Evidence first:
  four independent read-only inventories (main app + installer, FTP/SFTP +
  password manager, the WebView2 viewers, the other 16 plugins) plus a
  `dumpbin /imports` scan of all 26 shipped modules — only `ftp.spl`,
  `sftp.spl`, `mdview.spl` (WinHTTP, remote images after consent) and the
  exe (`mpr`/`netapi32` for network drives and shares, `wsock32` ordinal 10 =
  `inet_addr` only) import anything network-capable. The statement says the
  unflattering parts plainly: saved passwords without a Master Password are
  only obfuscated, FTP is unencrypted and FTPS unavailable, crash reports hold
  paths, the full command line and drive serial numbers (never sent), remote
  images send `OpenSalamander-mdview`, uninstall leaves all per-user data.
  Every sentence is mapped to evidence (`specs/083-…/fix-log.md` claim map)
  and was checked by an independent reviewer and a reader test. The winget
  locale template gained a literal `PrivacyUrl` to `blob/main/PRIVACY.md`
  (answers 200 only once merged and pushed); `publish.ps1` unchanged. Contact
  is the public issue tracker only, because GitHub private vulnerability
  reporting is still disabled — enabling it and adding the second contact
  line is the maintainer's step. The update rule is in *Key Facts*
  ("Privacy statement"). Defects found on the way (F1 — a password typed as
  part of an address, `ftp://user:password@host`, is saved in plain text in
  the Quick Connect, Change Directory and command-line histories — first;
  F3 — a Markdown document can open the browser without a click; F8
  withdrawn) are recorded as NEXT-WORK item 7, not fixed. The independent
  review caught two false claims in the first draft (a shell-extension
  registration that 0.1.8 never performs — the code is gated on a DLL that
  is not shipped), so cite *reachable* code, not just existing code; fixing any of them updates
  `PRIVACY.md` in the same change. No product code changed.
- 084-archiver-cleanup: **external archivers work for the first time.**
  - **What was broken.** Every external archiver operation since 0.1.0 failed
    with "Unable to execute new process ...\utils\salspawn.exe". The helper
    started every archiver, but it was built only in the `Utils (Release)`
    configuration, into `plugins\Intermediate\`, and no release ever
    contained it. Of the 12 known archivers, 7 were MS-DOS programs that
    64-bit Windows cannot run.
  - **What it is now.** The archiver is started **directly**
    (`PackRunArchiver`, `src/pack3.cpp`) in a **kill-on-close job object**,
    behind a wait window with **Cancel**. Esc cancels too; a listing honours
    the caller's "Reading list…" window instead of opening its own. The
    `salspawn` project is deleted (solution: 80 projects).
  - **Two archivers left.** Index 0 = **7-Zip console** (new, UID 13): browses
    (`7z l -slt -ba`, pure parser `src/common/sal7zlist.*`) and unpacks ARJ
    and LZH/LHA. Index 1 = **RAR (WinRAR console)**: packing only, UID 2 and
    index kept so stored `rar;r##` associations stay valid. JAR, ACE, ARJ,
    PKZIP, LHA, UC2, every DOS row, the floppy presets, the OEM column parser,
    `PackUC2List` and the ARJ/RAR5 hacks are deleted.
  - **List files.** New variable `$(ListUnicodeFullName)` gives a UTF-16LE
    list file with a BOM. 7-Zip 22.01 rejects 4-byte UTF-8 (emoji) in a UTF-8
    list. Custom entries keep their OEM/ANSI behaviour.
  - **Hiding (FR-017).** `RefreshAvailability` (at `CheckData`, the Locations
    page OK, and after Autoconfiguration; UNC paths not probed) drives three
    things: `CanBrowse` (`BuildArray` skips records of missing or
    non-browsing archivers), `CanPack` (the runtime "can pack" sites), and
    `IsPackerOffered`/`IsUnpackerOffered` (Pack/Unpack combos now map
    positions through item data).
  - **Autoconfiguration** finds 7-Zip and WinRAR through the registry and
    Program Files before any disk scan.
  - **Configuration version 106.** `PackMigrateArchiversTo106`, with pure
    decisions in `src/common/salarcmig.*`, removes entries that use a removed
    archiver's variable (edited or not, clarification Q4) and the floppy
    presets. It rewrites the untouched 0.1.8 RAR packer default, deletes the
    RAR unpacker default, adds the 7-Zip unpacker and the `arj` / `lzh;lha`
    associations, and runs once before `CheckData`.
  - **Traps the reviews caught.**
    - `PackErrorHandler` shows every ID >= `IDS_PACKQRY_PREFIX` (11101) as an
      OK/Cancel question, so error strings live in 11072-11074.
    - The default 7-Zip unpacker without `-o"$(TargetPath)"` silently
      overwrote files in the target (blocker).
    - Without `-ba` an archive comment injected fake entries.
    - On a volume without 8.3 names the archiver path went unquoted
      (`D:\Program.exe`).
    - A user command quoting the variable now expands to `""path""` and is
      normalised.
  - **Translations.** The merge tool keys string rows by bundle *ordinal*,
    so removing two bundles would have displaced 456 rows per language.
    `probe/rekey_stringtables.py` re-keys the committed `.slt` and `.origin`
    to the new bundle numbering before the merge: 15 gaps per language,
    5,696 DeepL characters, `IDS_PACKERR_EXEMISSING` pinned formal with the
    real UI names. Python TLS to DeepL needs `SSL_CERT_FILE` = certifi.
  - **RAR out of the box (stage S7) is blocked** on NEXT-WORK item 8, the
    upgrade of the vendored 7-Zip 16.04 (RAR RCE CVEs) to 25.x. The
    maintainer accepted the "unRAR restriction" licence of the RAR decoder
    already inside `7za.dll` (documented in `doc/third_party.txt`).
  - **Status.** saltests 1527 → 1647. Plugin ABI untouched (interface 106).
    The GUI probes (`probe/gui_probe.ps1`, `make_cfg_fixtures.ps1`) were
    written but **not run**, at the maintainer's request; they are owed.
    Records: `specs/084-archiver-cleanup/fix-log.md`, `inventory.md`,
    `closing-report.md`.
- 085-privacy-defect-fixes: **the privacy defects 083 recorded are fixed**
  (NEXT-WORK item 7, F1–F7; F9 left), `PRIVACY.md` updated in the same change.
  - **F1, passwords in typed addresses** never reach a history: one pure rule,
    `src/common/salurlpwd.*` (compiled into core, saltests and the FTP plugin),
    applied to the *history copy* only — never to the value the operation uses.
    Three forms: single value (part ends only at `/`; FTP accepts spaces and
    quotes in a password), command line (word ends, except a quoted URL), FTP
    address field (`SalStripAddressPassword`, the plugin passes its FS names).
    `%3A`/`%40` count. Sinks: Change Directory, Copy/Move target (core dialogs,
    and via `CSalamanderGeneral::AddValueToStdHistoryValues` for
    `CopyHistory`/`ChangeDirHistory` — no ABI change), Find *Look in*
    (`HistoryComboBox(..., stripPasswords)`), command line, FTP Quick Connect;
    histories are also cleaned after load. Location stores (Alt+F12, tabs, hot
    paths) record the FS-reported path, which never holds the FTP password.
    First review **REJECTED** (spaces/quotes kept the password) — fixed.
  - **F3**: the shared WebView2 host forwards a cancelled navigation to the
    link handler only if `get_IsUserInitiated`; because that flag is
    *transient* activation, mdview also renames raw-HTML `http-equiv` to
    `data-tc-equiv` (`htmlgen.cpp AppendRawHtml`; its first version was
    REJECTED: md4c sends a raw-HTML line break as its own call, so `=` on
    the next line bypassed it — the name is now renamed at a call's end too).
  - **F2**: mdview's fetch moved to `remotefetch.*` (no PCH, probe-buildable):
    UA `TandemCommander-mdview`, cookies + automatic authentication off, 2xx
    only. The probe's negative control showed the old code **sent an
    `Authorization` header** (Windows logon) on a 401 Negotiate/NTLM.
  - **F4/F5**: one environment-options builder for host and keeper
    (`webenvopts.h`), `IsCustomCrashReportingEnabled = TRUE`; mismatched
    options make the later environment fail (per Microsoft, not measured), so a
    0.1.5–0.1.8 instance running at the
    same time cannot share the engine (viewer says "engine unavailable").
  - **F6** `BCryptGenRandom` salts; **F7** SFTP cancelled Master Password prompt
    no longer saves a scrambled secret (FTP parity).
  - Found, not fixed: the ZIP plugin's AES salt still uses `rand()` (NEXT-WORK
    item 7). saltests 1647 → 1816, htmlgen 29 → 38. GUI steps owed
    (`quickstart.md` G1–G6). Records: `specs/085-privacy-defect-fixes/fix-log.md`.
- 086-zip-aes-salt: **encrypted ZIP archives get unpredictable salts.** The
  ZIP plugin's AES salt (`add.cpp`) and the random bytes of each ZIP 2.0
  header (`crypt.cpp CryptHeader`, 10–11 of its 12) came from `rand()` seeded once per run with
  time ^ pid — predictable (one guessable 32-bit seed), repeated only across
  runs with an equal seed. Both, and the core password manager (085 F6), now
  use **`SalGenRandom`** in the header-only `src/common/salrandom.h`
  (`BCryptGenRandom`, links `bcrypt.lib` by pragma) — header-only because the
  ZIP project cannot compile a shared `.cpp` from `src/common` (its sources
  find `precomp.h` beside themselves). New security-relevant random bytes
  MUST come from it. Format unchanged; old archives keep their salts. SFX
  archives cannot use AES (`add_del.cpp:112`). saltests 1816 → 1829; probe
  `specs/086-zip-aes-salt/probe/zip_salts.py` (self-test against 7-Zip); GUI
  round trip owed (`quickstart.md`). Records: `specs/086-zip-aes-salt/fix-log.md`.
- 087-7zip-2603-rar: **the 7zip plugin runs on 7-Zip 26.03 and reads RAR.**
  - **Engine** (`src/plugins/7zip/7za/`, pristine 26.03 subset + one patch):
    only 7z, RAR (1.5-4) and RAR5 (3 formats; 16.04 had 53), built from the
    upstream `Format7z` bundle plus the RAR set. The one local patch is the
    thread trampoline in `C/Threads.c` (`TC_7ZIP_CALLSTACK`, every engine
    thread runs through the plug-in's call-stack object - proven by
    `probe/fakespl.c`, negative control included); everything else and the
    retired 16.04 patches are in `7za/TC-PATCHES.md`. 26.03 seeds 7z AES IVs
    from `RtlGenRandom` (16.04: time + pid). `7zwrapper.dll` (no caller) is
    gone - solution 79 projects; installer `[Code]` and `build.cmd` delete a
    stale copy.
  - **Item names are cleaned** (`src/common/salarcname.h`, header-only,
    `SalArcCleanItemPath`): `..`, absolute/drive/UNC paths, ADS (`name:x`)
    and reserved names could be written outside the target by **every
    earlier version**; cleaned at listing and again in the extract callback
    (the security boundary). Links (`kpidSymLink`/`kpidHardLink`) are never
    extracted - also those marked only by the Unix mode in the attributes
    (RAR4, Unix-made 7z); the count is reported (`IDS_LINKS_SKIPPED`).
  - **RAR**: handler chosen by signature (`SalArcDetectFormat`), volumes via
    `IArchiveOpenVolumeCallback` (siblings of the first part only), memory
    requests bounded by min(4 GiB, RAM/2) (`AnswerArchiveMemoryRequest`),
    read-only (no `IOutArchive` -> "not supported"). Registration:
    configuration version **4**, `AddPanelArchiver("rar;r##", view only)`;
    a fresh plug-in installation takes over the core's `rar;r##` record
    (WinRAR stays its packer), an **upgraded** one can only extend its own
    7z record (`plugins1.cpp` `updateExts`) - 084 contract M2's expectation
    corrected.
  - **26.03 API traps**: `Z7_*` COM macros, every callback `throw()`
    (`catch (...)` in them; `std::map::operator[]` replaced by `find`);
    `Extract()` returns S_OK with per-item errors (the 16.04 "JRY FIX" is
    retired) - `Decompress` maps any per-item error or skipped link to
    `OPER_CONTINUE` and **callers require `== OPER_OK`**, else *Unpack and
    delete* deletes a partly failed archive (review blocker); `g_IsNT` must
    be true for `LoadLibraryW`; 0.1.8 sent the word size as `VT_I4`, which
    both engines reject (probe `props`), so it now takes effect.
  - **Results the old code did not know** (second review, REJECT): RAR5
    reports `kWrongPassword` after the output file exists - file deleted,
    password forgotten, operation stopped; every other failed result asks
    *delete or keep*. `Cleanup` on Cancel deletes only a file opened for the
    current item (`HaveOutFile`) - 0.1.8 could delete the user's own file
    after *Skip* + Cancel. *Unpack and delete* hands every opened RAR part to
    the core (`OpenedVolumes`) and keeps the archive when the listing was
    incomplete (`ListingIncomplete`).
  - **Password prompt** (087 said "code-page characters only"): wrong - the
    password was garbled for every non-ASCII character since 0.1.0; fixed by
    feature 093. The password is wiped (`WipeUString`) on close, after a
    failed open and after an operation with errors.
  - Evidence: `specs/087-7zip-2603-rar/probe/` (`7zdrive.exe` drives any
    `7za.dll`; `run_engine_probe.py`: 23 RAR files of the 084 fixtures,
    7z round trips checked by 7z.exe 22.01, hostile names, memory bound,
    timing). saltests 1829 -> 1900. GUI pass owed (`quickstart.md`). Records:
    `specs/087-7zip-2603-rar/fix-log.md`.
- 088-plugin-interface-107: **plug-in interface 107 - an update goes through
  with viewer windows open, and the path-buffer contract is true.**
  - **Interface** (pure append, plug-ins built for 104-106 keep loading):
    `IsUnattendedClose()` (TRUE while an installer closes the program through
    the Restart Manager - `Release(parent, FALSE)` must then show nothing) and
    `SetWindowClosesUnattended(hwnd, closes)` (a plug-in declares a top-level
    window that holds nothing to lose). The declaration is a **window
    property** (`SALCLOSEAPP_WINDOW_PROP`), so `DecideCloseApp` reads it with
    `GetProp` - no message, no side effect, gone with the window. Contract:
    `specs/088-plugin-interface-107/contracts/plugin-api-v107.md`; history in
    `spl_vers.h`; overview of 105-107 in `architecture/06`.
  - **Who declares**: codeview, mdview, pictview, dbviewer at `WM_CREATE`;
    `Release` closes with `CloseAllWindows(FALSE, 5000)` (never forced).
    PictView withdraws the declaration while it shows an image that exists
    only in the window (pasted, scanned, captured - review finding). FTP no
    longer asks "cancel existing operations?" on that path. A viewer's own
    dialog, and every other plug-in's window, still declines. `UnloadAll`
    stops at the first refusal during an unattended close.
  - **Buffers**: `SAL_MAX_PATH_UTF8` and `CSalMaxPathBuffer` are in
    `spl_base.h`; the headers said `MAX_PATH` for buffers the core fills with
    up to 98,302 bytes (`GetNext/PreviousFileNameForViewer`,
    `SalSplitGeneralPath`, `SalSplitWindowsPath`, `CheckAndCreateDirectory`'s
    `firstCreatedDir`). PictView and the Database Viewer overflowed a
    260-byte stack buffer in a deep folder - fixed. A plug-in built for < 107
    gets only names that fit `MAX_PATH`; longer ones are stepped over
    (`GetFileNameForOldViewer`, rule in `src/common/salplugver.h`).
  - Evidence: `probe/viewers_probe.ps1` (10/10: four viewers alone and
    together agree in 1.4-1.6 s, dialogs decline in 0.0 s, normal exit
    unchanged), `longpath_probe.ps1` (10/10 on a 349-character path),
    `oldplugin_probe.ps1` (the 0.1.8 PictView, interface 106, in the new
    core: loads, no overflow, still declines). saltests 1900 -> 1918.
    Records: `specs/088-plugin-interface-107/fix-log.md`.
- 089-7zip-followups: **the three leftovers of 087's reviews.**
  - **One RAR association.** `AddPanelArchiver(exts, edit FALSE, updateExts
    TRUE)` - an installed plug-in adding view-only extensions - used to append
    them to the plug-in's own first record, so an updated configuration got
    `7z;rar;r##` with the plug-in as packer while a new one got the core's
    `rar;r##` record taken over with WinRAR as packer. Now a record whose
    **external unpacker can never browse** (`CArchiverConfig::NeverBrowses`,
    i.e. no list command by design - RAR console) is taken over for viewing,
    the same extensions leave the plug-in's other records, and extensions the
    plug-in already serves are not added twice; everything else goes through
    the unchanged legacy code (tar, uniso, unmime rely on it). 7zip plug-in
    configuration version **5** repeats the registration once. Helpers:
    `src/common/salarcassoc.h`. Probe `probe/assoc_probe.ps1`: the real 0.1.8
    configuration, two 087-development shapes and a first start all end with
    `rar;r##` = packer 1 / unpacker plug-in and `7z` = plug-in / plug-in.
    Registry layout: `Packers & Unpackers\Archive Association\<n>`
    (`Extension List`, `Packer Index`, `Unpacker Index`; a plug-in is
    `-Index-1`).
  - **`splunicode.h` is WTF-8** (was excluded from 066): strict Windows
    conversion first, then the core's routine ported header-only - so every
    plug-in opens a path with a lone surrogate, and the 7zip plug-in's
    `U8ToUString`/`UStringToU8` keep such names. Malformed input still fails
    (ftp, uncab, renamer use the failure to detect legacy text). Parity with
    the core in saltests; the reviewer brute-forced 181,789,444 cases.
  - **7z update matching** uses the cleaned name (`CArchiveItem::Name`,
    `NameIsStoredName`): a file added into a cleaned-name folder replaces
    instead of duplicating; among several items with one name the really
    stored one is replaced. Found on the way: a matched **directory** item was
    dropped from the archive, and on a Move a file that met a folder's name
    was not packed but its source was deleted - both fixed.
  - saltests 1918 -> 2039. Interface stays 107. Records:
    `specs/089-7zip-followups/fix-log.md`.
- 090-ftp-anonymous-default: **privacy defect F9 closed.** The FTP plug-in's
  placeholder for anonymous logins was `name@someserver.com` - an ordinary
  domain - and went to every anonymous server. It is now
  `anonymous@example.com` (RFC 2606). The rule for a stored value is pure and
  header-only (`src/common/salftpanon.h`, `SalFtpAnonymousOnLoad`): the old
  placeholder in any letter case is replaced on load, anything else is the
  user's and is kept; no configuration version bump (idempotent).
  `PRIVACY.md` updated in the same change. saltests 2039 -> 2055. Records:
  `specs/090-ftp-anonymous-default/fix-log.md`.
- 091-workflow-actions-node: **the workflows are off the Node 20 actions** -
  `actions/checkout` v7, `actions/upload-artifact` v7, `actions/github-script`
  v9, `microsoft/setup-msbuild` v3 (eight `uses:` lines, nothing else);
  `ilammy/msvc-dev-cmd@v1` stays (no Node 24 release exists). **Not run** -
  nothing is pushed from an implementation session; verified statically
  against the upstream tags (`runs.using`, inputs, breaking changes).
  **Finding for the maintainer**: `actions/checkout` refuses fork
  pull-request code under `pull_request_target` since v7.0.0 and, backported
  on 2026-07-20, on every older major too - so `pr-comments-guard.yml` has
  failed for labelled fork pull requests since then; opting in
  (`allow-unsafe-pr-checkout: true`) or retiring the upstream
  comment-translation workflows was a security decision - **decided
  2026-10-02: opted in** (the job only preprocesses the checkout with
  `clang -E`, read-only token, maintainer's label required; never add a
  step there that runs code from the checkout).
  Record: `specs/091-workflow-actions-node/fix-log.md`.
- 092-name-identity-unicode: **"the same name" is the file system's rule**
  (encoding cluster B-2, core identity part). The core compared names with
  code-page byte tables applied to UTF-8 bytes: `Č.txt` != `č.txt`, and on
  CP1250 `ĥ.txt` == `Ĺ.txt` (their second bytes fold together).
  - **Helpers** (`src/common/salunicode.*`, contract
    `specs/092-name-identity-unicode/contracts/name-identity.md`):
    `SalNameCompareOrdinalCI`, `SalNameEqualOrdinalCI`,
    `SalPathEqualOrdinalCI`, `SalPathHasPrefixOrdinalCI` -
    `CompareStringOrdinal(..., TRUE)` for WTF-8, the legacy fold for text
    that is not, a total order over both. **New identity decisions in the
    core MUST use them**; `SalNameEqualCI` (linguistic) is for searching only.
  - **Traps**: 7 case pairs have different UTF-8 lengths (U+023A/2C65 ...),
    so no byte-length guard before the comparison, and after a prefix test
    index the path by the count the helper returns; no character outside
    ASCII equals an ASCII letter (`ı`, `ſ`, Kelvin are different names).
  - **Converted** (73 comparisons, four reviewed stages): finding an item by
    name (focus after refresh, viewer next/previous), overwrite / delete /
    rename decisions (`worker.cpp`, `RenameFileInternal`, 8.3 collisions,
    `SalSplitGeneralPath`'s rename gate), core path identity (history,
    archive identity, prefix tests), and the sorted name lists (`SortNames`
    + its searches - both sides in one change).
  - **Not converted, by decision**: the comparison services exported to
    plug-ins, `CSalamanderDirectory`, the panel sort, masks, *Change Case*,
    the disk-cache keys, x86-only code - listed in NEXT-WORK item 5 with the
    defects found on the way (first: delete-then-retry on a server that
    folds more than Windows; an unbounded `StrICpy` at `fileswn9.cpp`).
  - Guard: `acp-byte-table-on-name` is **strict** (drive-letter look-ups
    excluded). saltests 2055 -> 12,828. Probes: `probe/build_and_run.cmd`
    (NTFS arbitrates), `focus_probe.ps1`, `timing_probe.ps1`, `run_perf.cmd`.
    GUI steps owed (`quickstart.md`). Records:
    `specs/092-name-identity-unicode/fix-log.md`.
- 093-unicode-dialogs: **text outside the code page in Find, Configuration,
  the command line, and the 7zip password** (encoding cluster B-1).
  - **The premise was measured in the product and was wrong.** Research on
    windows in a process without the comctl32 6 manifest said "a dialog
    created with `DialogBoxParamA` has code-page controls". In the product
    (manifest present) `Edit` and `ComboBox` are Unicode controls regardless
    of the entry point: Change Directory, Pack, Unpack, Select, filter lose
    nothing. **Measure in the product before converting anything**
    (`probe/dialogs_probe.ps1`: IsWindowUnicode, prefill, set, posted
    characters).
  - **What loses text** - two causes only: (1) a **code-page message loop**
    (`GetMessageA`/`IsDialogMessageA`/`DispatchMessageA`) converts typed
    characters before the window sees them: Find's thread loop, the
    Configuration holder (`common/sheets.cpp`), and the main loop's
    `IsDialogMessage` are wide now; (2) a **code-page `CWindow` attached to a
    text control** flips it: attach helpers of text fields with
    `CWindow::AttachToWindowKeepKind` (`CComboboxEdit`, the in-place list
    editor, the command line's `CEditWindow`/`CEditLine`). Plain
    `AttachToWindow` on an edit is a defect; `CStaticText`/`CButton` stay
    code-page (they pass `char*` text and go to plug-ins). Contract:
    `specs/093-unicode-dialogs/contracts/dialog-unicode.md`.
  - **Menu mnemonics** compare UTF-16 (`IsMenuBarMessageEx`,
    `SalMnemonicMatchW`); the plug-in-facing `IsMenuBarMessage` is unchanged.
    The Debug build used to crash on Alt+`ř` in the main window (RTC cast).
  - **Command line**: `WM_CHAR` switch on the whole unit (cut to a byte,
    U+010D was Enter), word break and Ctrl+Backspace on UTF-16, selection
    offsets in units (`SalU8OffsetToW`), drop target wide.
  - **Overflow**: `EditLine`/`SalGetWindowTextU8` cut at a whole character
    (`SalWToU8Truncate`) instead of a code-page re-read.
  - **7zip password**: winliblt's `EditLine` returns UTF-8, four consumers
    read it as `CP_ACP` - every non-ASCII password was garbled since 0.1.0
    (archives made elsewhere did not open; archives made by the plug-in need
    the garbled password elsewhere). Now UTF-16 from the field to the engine.
    **Legacy form** (`src/common/salarcpwd.h`, verified against the old code
    on 800,776 cases) is tried **per item**: a preference test on a second
    handler, pass 2 over refused items with the other form, pass 3 for a
    damaged item's partial output; unrequested and declined items of a
    failed block are not errors. Three reviews (REJECT: one form per archive
    broke mixed archives; REJECT: a successful extraction counted as failed;
    ACCEPT). Also fixed: a wrong password on a content-encrypted archive did
    nothing and said nothing. **The ZIP and SFTP prompts use the same
    `EditLine` and were not examined.**
  - **GUI probes run on a hidden desktop**: `tools/run_on_hidden_desktop.ps1`
    (CreateDesktop, no admin) - the maintainer works on the machine. Limits:
    no real keyboard; a menu popup may close by itself there (probe artefact,
    proven on both builds). Probes share `HKCU\Software\Tandem Commander`
    with an installed instance (backup/restore of the whole key).
  - saltests 12,828 -> 12,973. Interface stays 107. A real-keyboard pass is
    owed (`quickstart.md`, menus first). Records:
    `specs/093-unicode-dialogs/fix-log.md`.
