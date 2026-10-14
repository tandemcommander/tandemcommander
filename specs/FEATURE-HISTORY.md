# Feature History — per-feature notes

What each feature changed, why, the traps it met and where its evidence
lives. These notes were the *Recent Changes* section of `CLAUDE.md` until
2026-10-09; they were moved here unchanged so that they are no longer loaded
into every session. `CLAUDE.md` keeps only the rules that follow from them.

**How to use this file**

- Do not read it whole (about 145 KB). Find the feature by number —
  search for `^- NNN-` — or by area in the index below, and read that entry.
- An entry is a summary. The full record is in `specs/NNN-*/` (`fix-log.md`,
  `closing-report.md`, `research.md`, `contracts/`, `probe/`).
- **New features add their entry at the end of this file**, not to
  `CLAUDE.md`. Only a rule that must change how *future* work is done gets one
  line in `CLAUDE.md` § *Standing rules*.
- Entries describe the state when the feature closed. Later features may have
  changed it (noted where known); open items are tracked in
  `specs/NEXT-WORK.md`, user-visible changes per version in `CHANGELOG.md`.

**Index by area** (feature numbers)

| Area | Features |
|------|----------|
| Build, signing, installer, winget, CI | 002, 050, 072, 077, 080, 091 |
| Releases and pre-release reviews | 056, 068 |
| Translations (pipeline, policy, pins) | 038, 039, 055; string additions in 084, 101, 106, 123 |
| Rebrand, identity | 046 |
| Encoding: UTF-8 / WTF-8 contracts, names, dialogs, titles | 052, 058, 066, 068, 069, 075, 092, 093, 100, 101, 121 |
| Long paths, buffers | 088, 095, 097, 098, 121 |
| Data-loss guards (same file, links, safe replace, pack over source) | 098, 099, 103, 105, 106, 107, 119 |
| Archives in the core, disk cache, external archivers | 084, 095, 096, 097, 108, 109, 112, 144 |
| ZIP plug-in | 086, 094, 106, 110, 113, 119 |
| 7zip plug-in (engine 26.03, RAR) | 087, 089, 093, 113 |
| Plug-in interface 107, closing for an update (Restart Manager) | 080, 088, 118, 121 |
| WebView2 viewers (Markdown, Code) | 081, 085 |
| Privacy and security | 083, 085, 086, 090, 123 |
| FTP / SFTP | 051, 056, 085, 090, 094, 099, 116, 121 |
| PictView | 105, 111, 120 |
| Undelete | 114, 115, 148 |
| File Comparator, Renamer, Database Viewer, Checksum, Disk Map, RegEdit | 102, 104, 117, 118, 121, 143, 147 |
| Crash reporting, antivirus findings | 077, 079 |
| Cloud status icons | 058, 059 |
| User-facing features (Command Shell, panel tabs, new version check) | 071, 078, 123 |

## Feature notes

Order is the order in which the entries were written (roughly chronological;
a few early ones are out of sequence).

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
    nothing and said nothing. The ZIP and SFTP prompts were examined by
    feature 094 (they do not use that `EditLine`).
  - **GUI probes run on a hidden desktop**: `tools/run_on_hidden_desktop.ps1`
    (CreateDesktop, no admin) - the maintainer works on the machine. Limits:
    no real keyboard; a menu popup may close by itself there (probe artefact,
    proven on both builds). Probes share `HKCU\Software\Tandem Commander`
    with an installed instance (backup/restore of the whole key).
  - saltests 12,828 -> 12,973. Interface stays 107. A real-keyboard pass is
    owed (`quickstart.md`, menus first). Records:
    `specs/093-unicode-dialogs/fix-log.md`.
- 094-plugin-password-encoding: **ZIP and SFTP passwords are the text that
  was typed.** Measured first (`research.md`): neither plug-in had the 7zip
  plug-in's defect - passwords inside the system code page always worked and
  7-Zip opens what the ZIP plug-in writes.
  - **ZIP, the real defect**: the ANSI plug-in read the Unicode field with
    `GetDlgItemTextA`, so a character outside the code page became `?`
    (a Cyrillic password on a Czech Windows = `??????`, opened by any other
    word of that length); UTF-8-keyed archives never opened, OEM-keyed AES
    ones neither; 255 characters were cut to 254; the password was in the
    call-stack text of a crash report.
  - **Forms** (`src/common/salzippwd.h`, header-only, contract
    `specs/094-plugin-password-encoding/contracts/zip-password-forms.md`):
    the typed text is UTF-16; **packing** uses code-page bytes when the text
    is representable (strict, no best fit) - unchanged, what 7-Zip opens -
    else UTF-8; **unpacking** tries code page, OEM, UTF-8 and `oldread` (what
    the old read produced, incl. the 254-byte cut) **per item**. Verified
    against the old read on a real edit control: 486,246 cases, 0
    mismatches.
  - **Classic encryption: verify first, write once.** Its check lets a wrong
    key through 1 time in 256, so when more than one form passes, each is
    verified by decoding the item without output (`ClassicVerify`) before the
    target file is touched; none verifies = wrong password. One passing form
    = the old path, unchanged.
  - **Self-extracting archives keep the old read** (the stub is a separate
    unchanged program with its own prompt).
  - **SFTP**: secrets of 512+ UTF-8 bytes were re-read through the code page;
    fields now take 511 characters, the whole buffer chain is 2048 bytes
    (`SFTP_SECRET_BUF`), no code-page fallback. FTP: not changed (UTF-8
    bytes verbatim; long-password edge recorded).
  - No new strings; interface stays 107; `PRIVACY.md` updated (crash report).
    saltests 12,973 -> 13,032. Probes on the hidden desktop: ZIP 56 of 57
    rows (previous build 33; the 57th, a self-extractor row, cannot be driven
    in a Debug tree), SFTP 11 rows. Independent review ACCEPT. Records:
    `specs/094-plugin-password-encoding/fix-log.md`.
- 095-archive-path-buffers: **the archive-path buffers, and what the premise
  got wrong.** The backlog said an unbounded `StrICpy` of the panel's archive
  path into `buf[MAX_PATH]` overruns the stack. It **could not**:
  `ChangePathToArchive` cuts the archive path to 259 bytes
  (`lstrcpyn(backup1, archive, MAX_PATH)`, the only non-empty writer of
  `ZIPArchive`), and the archive listing refuses inner paths and names over
  255 bytes (`AddFile`, in bytes) - every one of the four buffers fit its
  maximum, one of them exactly. The four sites (`fileswn2/5/6/9.cpp`) now
  build the disk-cache name in exact-size heap strings
  (`src/common/salheapstr.h`, `CSalHeapString`; its folding copy is
  byte-for-byte `StrICpy` - the cache key must not change, see 092).
  - **The real defect it fixed** (found by the reviewer, not by the author):
    `ExecuteFromArchive` ignored the result of two bounded appends, so with
    archive + inner folder + name >= about 520 bytes Enter / F4 asked the
    plug-in for the *folder* ("File not found").
  - **Found, not fixed** (NEXT-WORK item 5): an archive at a path over 259
    bytes cannot be opened and the cut can open *another* archive; an edited
    file with an accented name may not be packed back.
  - Lesson: a probe whose negative control does not fail is a finding -
    check reachability (every writer, in bytes) before fixing an "overflow".
    saltests 13,032 -> 13,102. Probe `probe/longarc_probe.ps1`: 60/0
    (previous build 56/4). Records:
    `specs/095-archive-path-buffers/fix-log.md`.
- 096-archive-edit-accented: **an edited file with a non-ASCII name is packed
  back into its archive.** In every release so far, editing `článek.txt`
  inside an archive (F4 or Enter) and leaving the archive lost the edit
  without a word: `CFileTimeStamps::CheckAndPackAndClear` (`salamdr3.cpp`)
  looked the temporary copy up with the code-page `FindFirstFile` on a UTF-8
  path, did not find it, and dropped it as "unchanged" - a consumer feature
  004 missed when it moved the producer to UTF-8. Fix: `SalFindFirstFile`;
  **only "not there" may drop an item**, any other look-up failure keeps it
  (offered for the update); wide `SetCurrentDirectory` before packing; the
  Archive Update list shows deep names whole. Found by the probe of 095,
  measured first (`research.md`). Probe `probe/archedit_probe.ps1`: 17 of 17
  cases updated (before: the 7 ASCII-named ones). The maintainer's standing
  instruction since this one: serious defects found on the way go to the
  backlog and are then fixed one by one. Records:
  `specs/096-archive-edit-accented/fix-log.md`.
- 097-archive-long-path: **archives in deep or accented folders open, and a
  path is never cut.**
  - **What was wrong**: `ChangePathToArchive` copied the archive path, the
    inner path and the focus name with `lstrcpyn(..., MAX_PATH)` - a silent
    cut at 259 **bytes** (about 130 accented characters), even inside a
    UTF-8 character. Enter did nothing, or an error named the cut path, or a
    file at the cut path - **another archive** - was opened (probe: on all
    three routes).
  - **S1 - refuse, never cut**: `IDS_TOOLONGPATH`, panel untouched, silent on
    refresh; `refusedTooLong` out-flag (do NOT key on `noChange` /
    `CHPPFR_INVALIDPATH`: a dead archive in history sets those too - the
    review's blocker). Same for `-L/-R/-A` (519-byte fields, layout shared
    between instances - not widened), hot paths, the path-field menu, drops
    on the directory line and the command line.
  - **S2 - make it work**: the rule `SalArchiveNameFitsHandler`
    (`src/common/salplugver.h`): under 260 bytes always; longer only for a
    plug-in **built for interface 107+** (up to `SAL_MAX_PATH_UTF8 - 1`);
    external archivers and older plug-ins keep 259 (backstops in the
    `CPluginData` archive wrappers and in front of the external-archiver
    code in `pack1/2.cpp`). About 20 core buffers on the plug-in route became
    heap strings (`CFileTimeStamps::ZIPFile`, the F8 question, `GetPanelPath`,
    crash-report lines, title, history `IsTheSamePath`, ...). The inner path
    keeps 259 bytes (`CSalamanderDirectory` is shared with plug-ins).
  - **Plug-in contract (comment only, no version bump - 107 was never
    released)**: `spl_arc.h` states the archive name may be up to
    `SAL_MAX_PATH_UTF8 - 1` bytes for plug-ins built for 107+;
    `SalGetTempFileName` accepts a long base path for such plug-ins (their
    buffer must then be `CSalMaxPathBuffer`; demoplug fixed).
  - **Evidence** (hidden desktop): `probe/arcwork_probe.ps1` 390 PASS / 0
    FAIL - ZIP, 7z, TAR at 200-7,000 bytes: enter, view, unpack, edit +
    update, delete, add, two panels, history, tabs; reviewer's ladder to
    20,000 bytes; `arcpath_probe.ps1` 55 / 0 with the twin archive never
    opened. Three reviews: S1 ACCEPT, S2 REJECT (history stuck on a dead
    archive entry + four remaining cuts), S2 ACCEPT. saltests 13,102 ->
    13,119.
  - **Found, queued in NEXT-WORK item 5**: a crash navigating disk folders
    ~7,500+ characters deep (`BuildHotTrackItems`); a typed 260+ byte file
    path in Change Directory overruns `shortenedPath`; a 7zip message buffer.
    Records: `specs/097-archive-long-path/fix-log.md`.
- 098-long-path-overruns: **four long-path defects of every release**, found
  by the 097 review and measured first (`research.md`):
  - **Directory line crash** at ~7,500 characters: `CHotTrackItem`
    (`stswnd.h`) kept pixel widths and offsets in `WORD` - now `int`.
  - **Change Directory to a typed file path of 260+ bytes**: `strcpy` into
    `shortenedPath[MAX_PATH]` (`fileswn3.cpp`) - heap now; `ClipboardPastePath`
    refuses instead of cutting and reads `CF_UNICODETEXT` as UTF-8 (it fed
    code-page bytes to a UTF-8 consumer); UNC-copy and `CShares::GetUNCPath`
    appends bounded.
  - **Silent loss when packing from a folder of 260+ bytes**:
    `CPanelTmpEnumData::WorkPath` was cut at 259 bytes and `_ReadDirectoryTree`
    returned success - sub-folder contents were left out (also built-in ZIP /
    7z). `WorkPath` heap, walk buffer `SAL_MAX_PATH_UTF8`, per-level data on
    the heap (Debug frame ~1.5 KB, Release ~290 B), depth limit 1,000 levels
    reported, never silent. External packer refuses sources of 260+ bytes.
  - **The review's blocker - the lesson**: making the silent link scan
    report "too deep" by *stopping* made `Pack` read the early stop as "no
    links", and *Move* then deleted files behind a junction **outside the
    selection**. Rule now: a scan that could not check everything is "a link
    was found" (warning, delete off). Any "is it safe to delete" check must
    fail closed.
  - **Found, next** (NEXT-WORK item 5): F6 / drag-and-drop *Move* into an
    archive has no link check at all - deletes files behind a junction
    (every release).
  - Probes (hidden desktop): `probe/fix_probe.ps1` 107 / 0 (before: 50 / 34:
    crashes, assertions, 16 of 16 packings losing files); regressions 095,
    096, 097 unchanged. Reviews: REJECT (the junction blocker), ACCEPT.
    Records: `specs/098-long-path-overruns/fix-log.md`.
- 099-move-into-archive-links: **moving into an archive or to FTP never
  deletes files behind a link.** In every release, F6 / drag & drop / paste
  with Move of a folder holding a junction or a directory symlink (or of the
  link itself) into an archive packed the files *behind* the link and deleted
  them - only the Pack dialog's Move had a link check. Now one helper,
  `ScanMoveSelectionForDirLinks` (`fileswn7.cpp`; 098's fail-closed scan:
  0 = no link and everything checked, 1 = link or not everything checked,
  2 = Esc), runs before every move into an archive (`FilesAction` in
  `fileswn8.cpp`, `DragDropToArcOrFS` in `fileswna.cpp`, the Pack dialog);
  on 1 the existing warning `IDS_DELFILESAFTERPACKINGNOLINKS` ("this is not
  possible ...") is shown and F6 / drag & drop cancel before anything is
  packed. **FTP plug-in had the same loss** on upload-Move: `ListLinkAsEmpty`
  (`operats*.cpp`) lists a link (or a folder whose attributes cannot be read)
  as empty, so nothing behind it is uploaded or deleted; the link is removed
  and an empty folder created on the server. SFTP never descended into links.
  Probe `probe/linkmove_probe.ps1` 24 / 0 (before: 14 / 10, the file behind
  the link deleted in all 8 link cases); the reviewer drove FTP against a
  local pyftpdlib server on both builds. Rule for any future "move" route:
  call the helper first. Records: `specs/099-move-into-archive-links/fix-log.md`.
- 100-cjk-focus-name: **window titles keep characters outside the code page.**
  A backlog note said "Change Directory to a CJK file name shows `f??.txt`";
  measured: focus and file were right, only the **title** of every code-page
  ("ANSI") top-level window lost the characters - `SetWindowTextW` on an A
  window stores through the code page. Helper `SalSetWindowTitleW`
  (`src/common/winlib.*`; header-only `SplSetWindowTitleW` in
  `splunicode.h`): `SetWindowTextW` first (every handler and subclass still
  sees `WM_SETTEXT`), then - for a top-level window (`WS_CHILD` clear) of the
  calling thread - compare the stored title (`InternalGetWindowText`) and
  correct it with `DefWindowProcW(WM_SETTEXT)`. **Controls keep plain
  `SetWindowTextW`** (the trick would bypass a control's procedure).
  `IsWindowUnicode` is not a reliable test (a `TTF_SUBCLASS` tooltip makes the
  internal viewer report Unicode while storing code-page text). Used by every
  viewer, File Comparator (worker sends `WM_USER_SETTITLEW` to the window's
  thread), DiskMap, the main window (its "unchanged?" check reads
  `InternalGetWindowText` - it had re-set the title on every refresh), some
  dialogs. Probe `probe/cjk_focus_probe.ps1` 77 / 0. Found, not fixed: the
  tray tip garbles non-ASCII names. Records:
  `specs/100-cjk-focus-name/fix-log.md`.
- 101-small-leftovers: the minor items left by 097-100. Tray icon through
  `NOTIFYICONDATAW` (`SalU8ToWTruncate`: cut at a whole character); clipboard
  path paste any length; *Copy UNC name* refusals show `IDS_TOOLONGPATH`
  (owner = the calling window, Find included); `SalPathIsWithinOrdinalCI` for
  share matching (it had no component-boundary check since Open Salamander);
  drag image capped to the monitor width; **three new strings** 14182-14184
  (unreadable / too deep, in free slots of the 14181 bundle - no re-key)
  translated by `translate.merge` (6,488 DeepL characters, 17 pins under
  `_feature_101`: DeepL drifted to the informal register for de/fr/nl/es, a
  Czech word in Slovak, the wrong Hungarian word for "folder");
  `SalU8EllipsizeMiddle` shortens names in those messages visibly. 096's
  probe flake explained: F4 acts only after the idle-time command-enabler
  refresh - the probe now waits for idle. saltests 13,119 -> 13,278. Review
  ACCEPT. Records: `specs/101-small-leftovers/fix-log.md`.
- 102-filecomp-unicode-names: **the File Comparator compares the files you
  name.** Its engine already opened files wide; the routes around it lost
  names: the dialog's path combos had a **code-page subclass** (the 093
  lesson again: `SetWindowLongPtrW`/`CallWindowProcW` now), history, drop
  and Browse were code-page calls, and **`DragQueryFileA` / `GetCommandLineA`
  use best-fit mapping** - `voilà` -> `voila`, `ＡＢ` -> `AB`: an existing
  look-alike file was compared silently. `fcremote.exe` (CRT-free external
  diff entry) sent code-page bytes to a plug-in expecting UTF-8 - broken for
  every non-ASCII name since 004. Now: wide everywhere; plug-in-local
  `LoadStrU8` (on `SG->LoadStrW`); heap name buffers; the header bar
  shortens a long name *before* `DT_PATH_ELLIPSIS` (quadratic: 28 s per
  repaint at 30,000 units); fcremote builds absolute paths itself
  (`FcAbsoluteNameW`, `fcproto.h`) because `GetFullPathNameW` strips a
  trailing dot from intermediate folders (`L.\f.txt` -> `L\f.txt`: another
  file); channel version "2" in the mapping name (a mismatch fails cleanly,
  `-w` no longer waits forever), messages bound-checked and copied once.
  winliblt gained an opt-in `AttachToWindowKeepKind` (other plug-ins
  unchanged byte for byte). The reviewer explained a one-time Debug
  "Buffer is too small" assert: history written by two threads at start-up
  (receiver now starts after `LoadConfiguration`; `HistoryLock`). Probe
  `probe/filecomp_probe.ps1` 95 / 0 (decoys never compared). Records:
  `specs/102-filecomp-unicode-names/fix-log.md`.
- 103-same-file-delete-guard: **the source is never "the existing target".** A rename or
  move that met "already exists" decided by the NAMES that the target was another file and
  deleted it; on a server that folds more than Windows (NFC/NFD on macOS) the target was the
  source. Reproduced without a Mac: `specs/103-.../probe/davnorm.py`, a standard-library WebDAV
  server folding like macOS (the redirector answers such a rename with 183; WebDAV reports file
  id 0) - the build before 103 **deleted the file** on Quick Rename, F6, F6 without the overwrite
  question, and F6 between `\\localhost@port` and `\\127.0.0.1@port` (copy onto itself, then
  the source deleted - nothing blocks `CREATE_ALWAYS` on a WebDAV alias). NTFS itself answers
  success for its own aliases (hard link, 8.3 name, junction); copies onto SUBST / `\\localhost\C$`
  / junction aliases survived only by the source's share mode (after "overwrite x with x?").
  Rule, header-only `src/common/salsamefile.h` (+ UTF-8 facade in `salfileio`): identity = volume
  serial + file id (128-bit `FileIdInfo` mirrored for 0x0601) from a `FILE_READ_ATTRIBUTES`
  open, metadata when there is no id; rename/move onto (possibly) itself -> **self-checking
  temporary name** (`src` -> `salXXX` -> `tgt`; if the target survives, it is another file and
  the old handling follows; never the source's own name as the temporary one); copy (and a move
  between roots) onto itself -> "Cannot copy/move a file to itself." (existing strings, own
  Skip All). Sites: `DoMoveFile`, `RenameFileInternal`, `DoCopyFile`, Renamer `MoveFile` +
  `CopyFile`, PictView rename; a symbolic link / junction moved onto what it points at is refused
  (it deleted the file before - second review). No new string, interface 107. Probe 62/0
  (pre-103 55/7: six losses); saltests 13,326 -> 13,438. Review: 4 SHOULD-FIX fixed, re-review ACCEPT. Records:
  `specs/103-same-file-delete-guard/fix-log.md`.
- 104-plugin-unicode-names: **the plug-ins use the names you give them** (NEXT-WORK item 5,
  sub-item 5, the 102 class in the other plug-ins). Measured first; the backlog's list was
  mostly wrong - the eight "code-page subclasses" carry no names (except ZIP's path label,
  display), the `DragQueryFile` A calls only count, the `CreateFileA` fallbacks are unreachable,
  `salpvenv.exe` is not built, shipped or reachable since 006. The real defects, all
  reproduced on the build before (`Debug_x64_pre104`): the **Renamer** attached winliblt's
  code-page `AttachToWindow` to its Mask / New name / Search / Replace edits and manual list
  and ran code-page loops - a new name `voilà.txt` became `voila.txt` (with "overwrite?" for the
  existing one), `Ж*.txt` became the wildcard `?*.txt` (other files selected); and the
  plug-in-facing **`SafeGetOpenFileName` / `SafeGetSaveFileName` / `GetTargetDirectory` are code
  page by contract** (best fit), so the Database Viewer opened `voila.csv`, PictView copied into
  `voila\` and its Save As offered to replace `voila.bmp`, the FTP save dialogs overwrote
  look-alikes and failed for every accented name, the CAB plug-in took the next volumes from
  `voila\`, Undelete opened `voila.ima`.
  - **Helpers** (`src/plugins/shared/splfiledlg.h`, header-only, no interface change):
    `SplGetFileNameU8` (an `OPENFILENAMEA` whose *names* are UTF-8 and *texts* code page, run
    as `Get{Open,Save}FileNameW`, the core's retry kept, offsets in bytes; no hooks) and
    `SplBrowseForFolderU8` (`SHBrowseForFolderW`); `SplShowNameTooLong` = Windows' own text for
    `ERROR_FILENAME_EXCED_RANGE` (no new string). **New plug-in code that asks for a file or
    folder MUST use them, never the core services.** `splunicode.h` `SplDrawWindowTextW` paints
    a path label wide (long text shortened first - 102's `DT_PATH_ELLIPSIS` lesson).
  - **winliblt `EditLine`**: WTF-8 both ways; a text whose UTF-8 form does not fit is
    **refused** - it was re-read through the code page (best fit). The core cuts at a whole
    character (093 D4); plug-in buffers are 260-byte names. **A refusal must never be stored as
    an empty value or acted upon** (review B1: the FTP Connect dialog stored an EMPTY password):
    `EditLine` records each field's buffer size (`WinLibSetTextLimit`) and
    `CDialog`/`CPropSheetPage::ValidateData` refuse a field that does not fit before Validate -
    one message, nothing transferred; code that reads a field outside that path checks
    `WinLibTextFits` (FTP Connect's kill-focus handlers). Audit of every caller in fix-log T010.
    The dbviewer CSV separator (one code-page byte) no longer goes through `EditLine`.
  - Renamer: `AttachToWindowKeepKind`, wide loops, the menu bar still fed code-page characters
    (plug-in-facing `IsMenuBarMessage`), mask/history/manual list/filter/editor UTF-8. PictView
    Save As: `GetSaveFileNameW` with its hook (the hook reads a code-page copy of the filter -
    only `nFilterIndex`/`lCustData` from the W struct). ZIP and CAB labels: Unicode subclass.
    Regedt Find loop wide, its editor launch ported from the Renamer. FTP/SFTP field readers
    refuse instead of re-reading. Disabled plug-ins listed, unchanged.
  - **Found, not fixed** (NEXT-WORK item 5, sub-item 5 queue): **PictView Save As onto an
    existing file deletes it, then fails** (WIC cannot encode, every release since 006 - data
    loss, first); Undelete's FAT `Replace0xE5` garbles CJK names on restore; FTP password
    fields keep a code-page subclass; checksum lists in the code page.
  - Probe `probe/plugnames_probe.ps1` (hidden desktop, decoys, a local FTP log server):
    50 PASS / 0 FAIL / 6 NOT DRIVEN (before: 47 rows showing the old behaviour). saltests
    13,438 -> 13,487. Regressions 093, 094 ZIP + SFTP, 099, 102, 103 as baseline. Review 1:
    REJECT (B1), fixed; re-review ACCEPT (S1: the pre-check skips read-only, disabled and
    hidden fields and only UTF-8 values get a size; NIT 1: an unchanged long password saved by
    0.1.8 keeps working). Records: `specs/104-plugin-unicode-names/fix-log.md`.
- 105-pictview-saveas-loss: **PictView's Save As saves, and never loses the file it
  replaces.** Measured first: worse than the 104 record - since feature 006 Save As saved
  *nothing* (14 types offered, every one "Unable to save the image": the WIC engine stubbed file
  output and its `PVIsOutCombSupported` said "supported" to everything), and an existing target
  was **deleted before** that failure (every format; also in a folder that denies creating
  files, also on Esc). Not lost before: a file held open elsewhere, the shown image ("in use");
  a read-only file never reaches PictView (Windows' Save dialog refuses it).
  - **Rule** (`src/common/salsafereplace.h`, header-only, wide): write `pvXXXX.tmp` next to the
    target (`SalCreateTempNextToW`, CREATE_NEW, any length), flush, close, then
    `SalReplaceWithTempW`: `ReplaceFileW` (attributes/ACL kept; fails with 5/32/2 leaving both
    files intact - measured), `MoveFileExW(REPLACE_EXISTING)` only for "not supported", a new
    name `MoveFileExW` without replace; a failure keeps the target (read-only put back) and the
    caller deletes the temp - except when the target is already gone: the new file is moved in
    or kept and named. "Gone" means not-found only (`SalPathIsGoneW`). **New code that replaces
    a user's file MUST use it.**
  - **Engine** (`wicengine.cpp`): `WicPlanOutput` table (BMP 16/256/gray/555/565/24, PNG and
    TIFF 16/256/gray/24 + bilevel, JPEG gray/24, GIF 16/256/gray as 8bppIndexed; TIFF
    none/LZW/Deflate/PackBits/Default=LZW, CCITT bilevel only), real `PVIsOutCombSupported`,
    `WicEncodeImageToFile` (a no-copy `IWICBitmapSource` over the shown DIB - flips, then the
    clockwise turn, progress/Esc every 16 rows; palette, converter, options, a file-handle
    `IStream` that keeps the first system error), `WicDetachSource` (the decoder holds the shown
    file without `FILE_SHARE_DELETE`: released after the new file is complete, the window reloads).
    `PVSaveImage` file output stays refused (wallpaper unchanged). Comments are UTF-8:
    `VT_LPWSTR` is converted to the code page by the PNG tEXt and TIFF writers (`?`, measured),
    so JPEG/GIF/TIFF get the UTF-8 bytes and PNG `tEXt` (ASCII) or `iTXt`.
  - **Dialog**: the language's type list filtered to BMP/GIF/JPEG/PNG/TIFF (no string change; the
    stored index stays a whole-list index); GIF interlace/89a and TIFF strips disabled (no
    encoder counterpart); *File > Save As* back in the menu; the suggested name no longer
    overflows a 260-byte stack buffer (every release, 87+ CJK characters).
  - Same one-step replace for *Regenerate thumbnail* and the *Rename* overwrite (both
    unreachable). No new string, no interface change (107), no registry change; `PRIVACY.md`
    mentions the `pvXXXX.tmp`. Probe `probe/saveas_probe.ps1` (hidden desktop, GDI+ decode,
    headers read by hand): 56 PASS / 0 FAIL / 4 NOT DRIVEN, 0 files
    lost (the build before: 7 / 49 / 4, 8 existing files deleted). saltests 13,487 -> 13,555.
    Records: `specs/105-pictview-saveas-loss/fix-log.md`.
- 106-zip-overwrite-source: **a pack never writes its archive over a file it packs.** Measured
  first (`research.md`), worse than the 103 note: a multi-volume ZIP whose volume name was a
  selected file (`a.z01`/`a.z04` for `a.zip`) lost that file after "Overwrite?" Yes - on a Copy
  too (volume 1 was created before the files were even listed), and with Move broke the archive
  and deleted the other files; any spelling (case, 8.3, `\\localhost\C$`) and a hard link. A
  declined "Overwrite?" for volume 2+ deleted the declined file. And the core's Pack dialog
  *Overwrite* deleted a selected file named like the archive before any packer ran (ZIP, 7-Zip).
  Now: `SalPackOutputIsSource` / `SalPackTargetInSelection` (`salsamefile.h`, pure: same id incl.
  hard links, or no ids + equal metadata = yes); the ZIP plug-in lists the files before creating
  any output and checks every existing volume / self-extractor against all of them (only when
  such an output already exists) - refused before the question with the new `IDS_PACKEDSOURCE` (1255,
  free slot, 8 languages pinned under `_feature_106`; review SF-1: no size filter - a hard link
  written through its other name is listed with a stale size); `TempNameOurs` - a failed multi-volume
  pack deletes only a volume it created; the core's *Overwrite* checks the selected items and the
  archive's folders and says "Cannot copy a file to itself." (behaviour change: an old archive
  that is itself selected can no longer be overwritten by packing it - deselect it). Unchanged,
  measured without loss: ordinary ZIP pack/F5/F6 into a selected archive (its open handle blocks
  the read), 7-Zip (the old archive ends up inside), TAR (no packing); SFX unreachable; RAR not
  driven. Interface 107, no registry change. saltests 13,555 -> 13,588. Probe
  `probe/packself_probe.ps1` 70/0 (before: 49/17 plus the two review rows failing). Found, not fixed: partial volumes after a failed
  multi-volume pack; the last volume not renamed when `name.zip` exists; `translate.merge
  --module zip` would re-lay out 510 controls. Records: `specs/106-zip-overwrite-source/fix-log.md`.
- 107-folder-alias-move: **a folder is never copied or moved onto another path of itself** (103's
  leftovers NIT 4 and NIT 5, measured first). On the build before, F6 of a folder "into the same
  place" through `\\localhost\C$`, `\\127.0.0.1\C$`, a mapped drive, SUBST, a second WebDAV server
  name - and on the same drive through a junction, the 8.3 spelling of a folder above it or a WebDAV
  NFC/NFD spelling - deleted its empty subfolders; F6 into itself or into its own subfolder through
  an other-root alias moved the whole content one level down and deleted the originals; a junction
  below the target pointing back into the source lost an empty folder of the source; a junction moved
  onto itself through UNC was deleted. No file content was lost (103 refuses files), copies lose
  nothing (a copy into itself stays a snapshot copy - decision). Fix: `DirTargetIsSource107` in
  `BuildScriptDir` (top-level folder of every copy/move route: F5/F6, paste and drag & drop via
  `BuildScriptMain2`, the plug-ins' `MoveFiles`), only when the target differs from the source by name:
  `T\name` exists and is the source -> refuse; a move whose target `T` or a folder above it is the
  source -> refuse ("Cannot move a directory to itself.", a copy "Cannot copy a file to itself." - no
  new string). `T`'s chain is read once per operation (`CDirChainScope107`) along the written path and
  the final path (a junction in the middle). Worker: `DoCreateDir` refuses a merge into the source
  folder itself before "Confirm Directory Overwrite" (Skip leaves the subtree and its deletions out; a
  move fails closed). Rules in `src/common/salsamefile.h`: `SalDirIsSame` (ids; without ids equal times
  AND the same path below the server name up to case/NFC; one side with an id and one without = two file systems, so WebDAV
  uploads are not refused), `SalDirChainHolds`, and for hard links `SalSameDirEntry` +
  `SalDecideExistingTargetEx`: the same directory entry through an alias (holding folders' identities +
  `FindFirstFile`'s stored names) is refused as "to itself", another link keeps the old handling; facade
  `SalSameDirEntryU8`, `SalGetFinalPathU8Alloc`, `SalPathsBelowServerLooselyEqualU8` in `salfileio`.
  Independent review ACCEPT with two false refusals fixed: a folder in a snapshot (shadow-copy device
  or `@GMT-` path; `SnapshotTag`, read only by the folder checks via `volumeTraits`) is never the live
  one, so restoring from Previous Versions merges; FAT ids count only with equal times; on WebDAV (no
  ids) the whole path below the server name must agree - both sides resolved first (a mapped drive ->
  UNC, `DavWWWRoot` dropped; the targeted re-check REJECTED a typed-text version that let a mapped
  drive and the `DavWWWRoot` form fail open) - so backup updates with equal folder times merge. Interface stays 107, no registry change. Probe
  `specs/107-folder-alias-move/probe/folderalias_probe.ps1` 206/0 (pre-107 157/21 + 18/6: every FAIL
  a source-tree change); paste and drag & drop NOT DRIVEN (hidden desktop) - a person's pass owed
  (`quickstart.md` step 5); snapshots and FAT rule-tested only; 103's `davnorm.py` now answers
  `PROPFIND /` (the `DavWWWRoot` form). saltests 13,588 -> 13,756. Records:
  `specs/107-folder-alias-move/fix-log.md`.
- 108-archive-edit-name-collision: **edited archive members whose names
  collide are tracked and packed back apart** (for ZIP see the plug-in
  caveat below). NEXT-WORK item 5 (left by 092), measured first
  (`research.md`): `CFileTimeStamps::AddFile` (`salamdr3.cpp`) called two
  members "already present" when their UTF-8 names fold together in the code
  page (CP1250: `ĥ`/`Ĺ`, `Í`/`Ý`, `ž`/`ż`, U+4E5D/U+4E4D, `м`/`о` - 19,015
  BMP pairs, `probe/collision_set.py`); the caller then released the second
  member's temporary copy, so the disk cache deleted it under the editor and
  the edit was never offered for the update. 7z lost the edit; ZIP lost the
  whole second MEMBER, because the ZIP plug-in's update matching
  (`CompareStringA` + `NORM_IGNORECASE` on UTF-8, `zip/add.cpp`) replaced it
  after an overwrite question. The inverse was real too: Change Directory to
  `arc.zip\DIR` (stored `Dir`) gave one member two copies through the two
  spellings and the second pack replaced the first edit.
  - **Rule** (`src/common/salarcedit.h`, header-only on 092's helpers): an
    edited member = its temporary copy, folder + name by the file system's
    rule (`SalEditedCopyIsSame`); one packer call = the same folder in the
    archive byte for byte + the same folder on disk by the rule
    (`SalEditedCopiesPackTogether`); the disk cache already gives two members
    two files and one member one file (092's `ContainTmpName`). Result: for
    7z both edits of a pair are packed back; for ZIP only when the two
    copies share one temporary folder - otherwise the ZIP plug-in's own name
    matching can still lose one (review row `split_zip`, also before 108).
  - **Stored spelling**: `GetZIPPathAsStored108` (`fileswn6.cpp`, declared in
    `fileswnd.h`) maps each typed folder of the panel's archive path to the
    listing's stored name when they are one name by the rule
    (`SalArcTakeStoredSpelling`); used by `ExecuteFromArchive` (cache name,
    archiver name, `AddFile` folder - packing never creates a `DIR` spelling)
    and by `ViewFile` (F3 keeps sharing F4's copy). The panel keeps the typed
    path. A folder matched only by the byte fold (merged by the listing)
    stays as typed. Trap (review NIT 3): tar extracts case-sensitively under
    a case-insensitive listing - a typed `arc.tar\DIR` over merged `Dir`/`DIR`
    folders now asks for `Dir\b.txt` (worked before only by luck).
  - Kept: two members equal by the rule in one folder stay refused for F4
    (092's message) - nothing can be lost there.
  - **Not fixed, queued (NEXT-WORK item 5; next 109, then 110)**: 109 - the
    disk cache keys an ARCHIVE by its code-page lower-cased name -
    `ĥ.zip` and `Ĺ.zip` share their
    members' copies; F4 in the second (other panel) opened the first's copy
    and the update packed it into the second archive, silently (measured,
    `-CacheKeyRows`, both builds); 110 - the ZIP plug-in's name matching
    (add, delete, extract) - editing one member of such a pair, packing the
    two in separate calls, or F5 of such a file into the archive, deletes the
    other member after an overwrite question.
  - Review ACCEPT (no code change); its SF1/SF2 corrected the ZIP claims in
    the records.
  - Probe `probe/namecoll_probe.ps1` + `arcfix.py` (archives read back by
    Python `zipfile` / `7z.exe`): 28 / 2 (the two ZIP single-edit rows, the
    plug-in), pre-108 14 / 16. Regressions unchanged: 096 17/17, 097 arcwork
    subset 120/0, 106 packself 70/0/4, 092 focus 10/10. saltests 13,756 ->
    13,835. Interface stays 107, no new string, no registry change. Records:
    `specs/108-archive-edit-name-collision/fix-log.md`.
- 109-disk-cache-archive-key: **an archive's temporary copies belong to
  that archive only.** NEXT-WORK item 5 queue entry 1 (from 108) and 092's
  "disk cache" item. The disk cache keyed an archive by its code-page
  lower-cased name (`LowerCase` on UTF-8) and compared keys with `strcmp`.
  Measured first (`research.md`), wider than recorded:
  - `ĥ.zip` / `Ĺ.zip` (CP1250 folds their bytes together) in two panels:
    one shared copy; leaving the archives packed it into BOTH (each ends
    with the first one's file + both edits); F3 in the second was given the
    first's file, also with a pending edit. ZIP and 7z, every release.
  - The flush took the bare key as a PREFIX: leaving `p.zip` flushed
    `p.zip.zip`'s copies; a copy being edited there was marked out of date
    and the next F4 (`CCacheData::GetName` -> `CleanFromDisk`) extracted
    the member over the unsaved-to-archive edit - lost silently.
  - Both panels on one archive: the copies were kept "for the other panel"
    also when a refresh reopened the archive because another program had
    changed it - F3 showed the old content (`stale-same`). The first 109
    version spread this to the SUBST pair it unifies; its own probe row
    caught it.
  - Case and 8.3 spellings already arrive canonical (`ChangeDir`
    enumerates each component); SUBST and `\\localhost\C$` gave one member
    two copies - the second update replaced the first edit.
  - **Key rule** (`salunicode.{h,cpp}`): `SalNameIdentityKeyAlloc` -
    `strcmp(key(a), key(b)) == 0` <=> `SalNameEqualOrdinalCI(a, b)`; valid
    WTF-8 through `SalNameIdentityFoldUnit` (ntdll `RtlUpcaseUnicodeChar`,
    proven equal to `CompareStringOrdinal`'s classes over all 65,536 units
    in saltests - `LCMapStringEx` upper case is linguistic and was not
    used), legacy text = 0xFF + `CharLowerA` per byte (tiers never meet).
    New byte-compared identity keys MUST use it.
  - **Core, both sides in one change**: one key per open archive
    (`CFilesWindowAncestor::ZIPArchiveCacheKey`, `GetArchiveCacheKey`,
    set by `SetArchiveCacheKey109` in `ChangePathToArchive`, forgotten by
    `SetZIPArchive`) for F3 (`fileswn5`), F4 (`fileswn6`; the archiver's
    name taken after the key's own length), both flushes (`fileswn2`
    `PrepareCloseCurrentPath`, `fileswn9`; key + `\`) and the
    "other panel shows this archive?" test (keys equal AND the archive
    still has the size/time the other panel listed). Same file under another spelling: the
    other panel's key is taken when size/time match and
    `SalArchiveSharesCacheKey` (`salsamefile.h`: equal usable ids, equal
    known snapshot, FAT also equal metadata) says one file; uncertain = own
    key. An EQUAL key is never trusted alone (review blocker: a key taken
    from `T:\arc.zip` outlived the re-pointed SUBST and shared another
    file's copies): `SalArchiveCacheKeyChoice` reads the identity whenever a
    share could happen; an equal key without certainty (other than the same
    name with no sign of another file) gets a unique suffix (0x01 + counter).
    The freshness test compares with the OTHER panel's listing (the
    refresh marker -1 of `RefreshForConfig` / `RefreshPanelPath(force)` made
    it flush a copy the other panel still edited); `OfferArchiveUpdateIfNeeded`
    takes name OR key. Queued (NEXT-WORK item 5, 2a): a flush can mark a copy
    with a pending edit out of date at all (pre-existing). `cache.cpp`
    unchanged (plug-in keys byte-compared by contract); dead
    `CCacheData::NameEqual` removed; `CSalHeapString::Adopt`/`Swap`.
  - Probe `probe/diskcache_probe.ps1` (F3 through an external viewer that
    logs what it was given; SUBST / UNC / re-pointed drive rows): 18 / 0;
    pre-109 9 / 9 (incl. `stale-same`). Regressions unchanged: 108 namecoll 28/2 (the
    known ZIP plug-in rows) and `-CacheKeyRows` now 2/0, 096 17/17, 097
    arcwork subset 120/0, 095 longarc 60/0. saltests 13,835 -> 13,973.
    Independent review: REJECT (the equal-key blocker) - fixed; re-review ACCEPT
    (left: equal size + 100 ns time under one re-pointed letter; the OOM key fallback).
    Interface stays 107, no new string, no registry change. Records:
    `specs/109-disk-cache-archive-key/fix-log.md`.
- 110-zip-plugin-name-matching: **the ZIP plug-in replaces only the member
  that has the added file's name.** NEXT-WORK item 5 entry 2 (found by
  108), measured first (`research.md`): `CZipPack::MatchFiles`
  (`zip/add.cpp`) compared member names with `CompareStringA` +
  `NORM_IGNORECASE` on the UTF-8 bytes - a LINGUISTIC comparison of
  code-page text (not the core's byte fold): on CP1250 21,925 BMP pairs
  were one name (`probe/zip_collision_set.py`). F5 of `ĥ.txt` into an
  archive holding `Ĺ.txt` asked to overwrite and replaced it (both present:
  two questions, both deleted); an F4 edit of one member deleted the other
  (108 rows `hL1_zip`/`hL2_zip`, review `split_zip`); *Yes* then *Skip*
  lost the edited member and stored the other twice; in a Unix ZIP the
  added file took the OTHER member's spelling and was then "not found".
  - **Rule** (`src/common/salzipname.h`, header-only, contract
    `contracts/zip-member-identity.md`): two valid WTF-8 names by
    `CompareStringOrdinal` on UTF-16 (= 092's `SalNameEqualOrdinalCI`,
    brute-force parity in saltests), legacy (non-WTF-8) text by the old
    `CompareStringA` with its equal-length guard, never equal across; no
    byte-length guard for UTF-8 (7 case pairs differ in length); a prefix's
    covered bytes are counted on the member (`SalZipNamePrefix`);
    `SalZipMemberIs` keeps the old case rule (DOS folder + name ignore
    case, Unix folder respects it). The ZIP project cannot compile shared
    `.cpp` files - the header carries the core's WTF-8 decoder.
  - **Behaviour change**: `č.txt` into `{Č.txt}` (and U+2C65/U+023A ...)
    now asks to overwrite, as `a.txt`/`A.txt` always did; ASCII names of
    one character unchanged, longer ones only from "two" to "one" (Czech
    locale: `cHata.txt` = `chata.txt` now - the old linguistic comparison
    read "ch" as one letter); OEM-named members follow the UTF-8
    rule after `ProcessName`. F5 into a folder pair the core's listing
    merges adds beside instead of replacing (recorded, entry 4).
  - **Review SF1, old defect fixed**: several members one name with the
    added file (`{ax, Ax, AX}`; with 110 also `{čx, Čx, ČX}`) - *Yes* for
    one and *Skip* for another deleted the first and never stored the new
    file. `CAddInfo::Replaced` (`add_del.h`): after a *Yes*, *Skip* / *Skip
    all* / an unopenable source keep only that member. Invariant: a member
    is deleted only if the file replacing it is stored. Probe trap: with
    nothing left to add the plug-in skips the deletions too - test with a
    second file in the operation.
  - Also fixed: `CountFilesInRoot` (`del.cpp`) ignored case in a Unix ZIP -
    deleting the last file of `Dir` beside `DIR` lost the folder; it now
    uses the selection's test (`Unix ? memcmp : MemICmp`). The Unix
    spelling copy grows its buffer (the member's spelling can be longer).
  - Not changed, by decision: delete/extract selection (files by index +
    exact name - correct; folders by the listing's byte fold),
    `FindFile` (index-based).
  - Found: a BACKSPACE byte in a comment of 108's `salarcedit.h` (fixed);
    CR/NUL/TAB bytes in `tools/run_on_hidden_desktop.ps1`'s usage comment
    (recorded).
  - Probe `probe/zipname_probe.ps1` + `zipfix.py` (own ZIP writer/reader:
    UTF-8, OEM, raw-byte, Unix members; F5, F6, F8, F5 out, F4): 42/0,
    pre-110 10/21 + review rows 3/8. Regressions: 108 namecoll 30/0 (was
    28/2), 106 packself 70/0/4, 094 ZIP 56/1 (X1 as before), 096 17/17.
    Independent review ACCEPT (SF1, SF2 fixed). saltests 13,973 -> 14,140. Interface stays 107,
    no new string, no registry change. Records:
    `specs/110-zip-plugin-name-matching/fix-log.md`.
- 111-pictview-shown-image: **PictView renames, deletes and saves over the
  image it shows.** The PictView entries of NEXT-WORK found by 103 and 105,
  measured first (`research.md`): Rename of the shown image failed with 32
  (NTFS and WebDAV), **Delete** of it too ("File in use" - not in the
  backlog), a second viewer window on the file blocked Save As, Rename and
  Delete; every opaque 32-bit PNG/TIFF/ICO asked "the alpha channel will be
  lost", "2 colors"/CCITT were never offered, the title said 16777216 colors
  for every image (the engine reports its 32-bit rows); the wallpaper
  commands could not write and then called
  `SystemParametersInfo(SPI_SETDESKWALLPAPER, NULL)` (documented: revert to
  the default) - read, never run; TIFF tag 270 UTF-8 only, JPEG COM with a
  NUL; a failed save over the shown image reset zoom and mirror.
  - **Release/retake** (`render1.cpp`): before Rename, Delete and the
    replace step of Save As every PictView window showing the file
    (105's `IsShownFile`) lets its WIC decoder go (`WicDetachSource`);
    afterwards `sfaSame` re-attaches without a reload (`WicReattachSource`:
    new decoder on the current name, same container + frame count, the DIB
    untouched - zoom, mirror, rotation stay), `sfaChanged` reopens at the
    same zoom (the saving window drops its mirror - it is in the file),
    `sfaGone` titles `<Deleted>`. Other windows (own threads) via
    `WM_USER_RELEASEFILE`/`_RETAKEFILE`, `SendMessageTimeout(SMTO_NORMAL |
    SMTO_ABORTIFHUNG, 5 s)` to a snapshot of `ViewerWindowQueue`
    (`CViewerWindowQueue::GetWindows`); message data copied per window and
    never freed after a time-out; a loading window keeps the file (fails "in
    use" as before). Not chosen: `FILE_SHARE_DELETE` (pending-delete names on
    FAT/SMB, files changing under the viewer).
  - **Source format** (`WicGetSourceFormat`, pure rules in
    `src/common/salpvsource.h`): the palette's size decides (a 2-color GIF is
    8bppIndexed), `SupportsTransparency` = alpha channel, alpha use recorded
    at decode (`CompositeOverBackground` returns it). `PVImageInfo::Colors`
    stays TC32 (pipette/histogram read the rows by it). Used by the alpha
    question (only real transparency), Save As default depth / mono list /
    "2 colors" + CCITT, title, Image Information.
  - **Wallpaper** (`render2.cpp`): 24-bit BMP via `EncodeReplaceSafe` (105's
    temp + replace, shared with Save As) into `%LOCALAPPDATA%\Tandem
    Commander\PictView_Wallpaper.bmp`, wide registry, `Prev*` backup,
    `SPI_SETDESKWALLPAPER` with an explicit path (never NULL); a failed save
    changes nothing. **Dry-run seam** `TC_PICTVIEW_WALLPAPER_DRYRUN` (a log
    file) in the only two writers (`WpRegWrite`, `WpApply`): probes MUST use
    it - the hidden desktop shares the user's wallpaper; the probe refuses
    without the seam in `pictview.spl` and checks the real values before and
    after. `PRIVACY.md` updated.
  - **Comments**: TIFF outside ASCII = tag 270 UTF-8 (Windows' own
    `System.Title` practice, read back as UTF-8 - measured) + XMP
    `dc:description` (`/ifd/xmp/<xmpalt>dc:description/x-default`); JPEG COM
    NUL removed after the commit (`JpegDropCommentNul`).
  - Found, recorded (NEXT-WORK): pipette and histogram read the 32-bit rows
    as 3 bytes per pixel (every release since 006); a Rename onto a file
    another window shows still fails (120 measured "Access is denied", 5);
    GIF comments UTF-8 - all three closed by 120.
  - Probe `probe/shown_probe.ps1` + `pilcheck.py` + `mkfix111.py` (hidden
    desktop, Pillow decode, WebDAV via 103's `davnorm.py` - `dav-fold`
    drives 103's guard in PictView for the first time): 83/0/2; pre-111
    49/28/7 (`-NoWallpaper`). Review REJECT (B1: a window that moved on was
    given the old file's name or `<Deleted>`; S1: a window encoding or
    printing let go and freed its image; S2: Restore without a backup removed
    the wallpaper; S3: multi-page title) - fixed: the retake acts only on the
    released, still detached image (`WicIsDetached`), `OpenFile` drops the
    release, operation ids in every message (a take-back acts only for the
    operation the window let go for - re-review `r-cross`) + a 1-s timer for
    lost retakes, re-attach only for
    the same file id + size + write time, `<Deleted>`/new name only for the
    operation's own path (hard links), `ImageBusy` refuses during encode and
    print, the wallpaper backup written only after SPI succeeded. Regressions: 105 saveas 56/0/4, 103 samefile 62/0, 104 PictView rows 4/0, 088 viewers 7/3 as on 105 (PictView rows pass; Code/Markdown Viewer rows fail on the hidden desktop on every build). saltests 14,140 ->
    14,169. No new string, interface 107, no registry format change.
    Records: `specs/111-pictview-shown-image/fix-log.md`.
  GUI re-run of the final protocol (2026-10-05 evening, fix-log T015): 85 / 0 / 2 (r-cross PASS;
  pre-111 50 / 29 / 7), regressions 105 56/0/4 (0 lost), 103 62/0.
- 112-cache-pending-edit: **a flush of the disk cache never throws away a
  pending edit.** NEXT-WORK item 5, queue entries 2a (109's review) and 3.
  With both panels on one archive and an F4 edit pending in the left one,
  the right panel's flush (after its own update, or after reopening an
  archive another program changed) marked the left copy out of date; the
  next F3 / F4 of that member deleted it and extracted the member over the
  edit - the stamp then matched and nothing was offered (every release;
  only while the left panel did not refresh in between: automatic refresh
  off, a share without notifications, Ctrl+R in the right panel).
  - **Rule** (`src/common/salcacheedit.h`, `CSalCacheEditPin`): the panel's
    lock on a tracked copy is a core-only EDIT lock (`crtCacheEdit`,
    `CACHE_LOCK_EDIT` in `LockObjFlags`, was `LockObjOwner`); a flush that
    meets it defers the out-of-date mark (`StaleAfterEdit`), set in
    `CCacheData::WaitSatisfied` when the last edit lock goes - then an
    unused copy is deleted at once (109's freshness kept). A mark set
    between look-up and lock is taken over; `GetName` guards the invariant.
    Without an edit lock the rule is the old one step by step (plug-ins
    unchanged; saltests random parity).
  - **F4** (`ExecuteFromArchive`): stamp, `AddFile` (three results,
    `CFileTimeStampsAddResult`) and the edit lock BEFORE the launch, under
    `BeginStopRefresh`; a copy that cannot be tracked is released and not
    edited (`IDS_PACKERR_NOMEM`) - it used to be deleted under the editor;
    the stamp of an existing copy was read after the launch (a fast editor's
    write became "unchanged").
  - Research correction: R re-entering the changed archive cannot reach the
    copy (109 gives it a unique key).
  - Trade-off (review SF1): an UNTOUCHED tracked copy is pinned too - after
    another program changed that member, the panel that opened it shows and
    edits the old content until Ctrl+R / leave; a size/time "untouched" test
    was rejected (it can extract over an edit). Follow-up: a per-member
    "changed in the archive since F4" warning (needs a string).
  - The launch uses a heap copy of the copy's name (the record's `TmpName`
    lives only as long as its lock; a forced Ctrl+R during the launch).
  - Probe `probe/diskcache_edit_probe.ps1` (refresh off / `net use` drive
    with no refresh, controls with refresh on, the left panel's refresh
    detected): results below. saltests 14,169 -> 14,236. Interface stays
    107, no new string, no registry change. Records:
    `specs/112-cache-pending-edit/fix-log.md`.
  GUI runs (2026-10-06 night): new probe 14 / 0 (pre-112 4 / 10, every loss row fails there), 109 18/0,
  108 30/0 and 2/0, 096 17/17.
- 113-zip-read-error-skip: **a file that cannot be read while it is added
  into an archive no longer costs the member it replaces.** The 110 note,
  measured by code reading (no GUI that day) and wider: the ZIP plug-in's
  `DeleteFiles` left the replaced members out BEFORE `PackFiles` read the new
  files, so *Skip* / *Skip all* of a source that could not be opened or read
  lost the member; with "temporary copy" off also *Cancel*, a cancelled
  progress and any error while packing.
  - **Rule**: a member is deleted only if the file replacing it is stored.
    Temporary-copy mode (default): `MatchFiles` records each replaced
    member with its owner and central record (`CReplacedMember`), and
    `RestoreReplaced` copies it back from the untouched original byte for
    byte, the record relocated (`src/common/salzipmember.h`:
    `SalZipMemberSpan`, `SalZipRelocateCentralRecord` - zip64 block patched,
    extended or put FIRST; review S1: the plug-in's `UpdateCentrDir`
    assumed zip64 is the first block - now found by id,
    `SalZipCentralRecordOffsetPos`). In-place mode: pack first, then
    `DeleteReplacedAfterPack` compacts away only the stored files' members
    (`DeleteFiles(dataEnd)` + `DeleteAfterPack`, the added files' offsets
    moved, uninterruptible). Trap: the compaction reads what was just
    written through the same `CFile` - flush the output buffer and extend
    `CFile::Size` (writes never update it) first.
  - Also fixed: AES - the MAC write replaced the error of a skipped or
    cancelled file (stored incomplete, a Move deleted the source, Cancel went
    on); a use after free of `SourFile` on the Skip path; a double free of
    `NewCentrDir`; `DeleteFiles` refuses a member whose end passes the next
    member ON DISK (`SalZipNextMemberOffset`; a 12-byte data descriptor moved
    the rest of the archive 4 bytes, or silently cut the first 4 bytes of the
    untouched member after it, both modes) and
    updates offsets only after a successful move. 7-Zip plug-in, the same loss (an *Overwrite* leaves the
    item off 7-Zip's plan, `S_FALSE` drops the file): Retry / Cancel only for
    a replacing file (`CUpdateInfo::Replaces`), and a file skipped in a Move
    is no longer deleted (`CanDelete`).
  - saltests 14,236 -> 14,327. Performance note: the bound and `UpdateCentrDir`
    walk the directory once per deleted member (n x d). Interface stays 107, no string, no registry
    change. Probe `probe/zipskip_probe.ps1` + `zipskip.py` (37 rows: locks
    held by the probe - "open" / byte-range; temporary copy, AES adding,
    in-place, 7z): results below. Records:
    `specs/113-zip-read-error-skip/fix-log.md`.
  GUI runs (2026-10-06 night): zipskip 37 / 0 (pre-113 11 / 26), 110 42/0, 106 70/0/4, 094 56/1 (X1).
- 114-undelete-names: **Undelete restores files under their own names, from
  the volume chosen.** The 104 note, measured by code reading (no GUI that
  day) and wider.
  - **The FAT rule ran on UTF-8 names of every file system**: `Replace0xE5`
    turned a first BYTE 0xE5 into '$' and `FixDamagedName` asked for every
    such name - every name starting with U+5000..U+5FFF (NTFS, exFAT, FAT
    long names) was listed as '$' + mojibake and restored under another name.
    The rule now lives on the 11 raw bytes of a FAT short-name entry
    (`src/common/salfatname.h`, `SalFatShortNameToW`: 0xE5 -> '$' + record
    flag `FR_FLAGS_NAMEFIRSTCHARLOST`, 0x05 -> the real 0xE5, OEM code page,
    NT case bits 0x08 / 0x10 on A-Z as Windows shows them); only a flagged record
    opens the Damaged Filename dialog; "All" keeps one UTF-8 character.
  - Also on the FAT route: short names were OEM bytes handed on as UTF-8;
    deleted long names were lost unless the first character was ASCII (the
    lost byte was guessed in the ANSI code page - Windows writes the OEM
    byte of the first character it KEEPS and DROPS what it cannot write;
    nothing kept = a hash form `191D~1.TXT` that cannot be linked back; now
    `SalFatLostFirstByteCandidates`, first checksum match wins - the checksum
    is a bijection of the first byte, so never all 256); unpaired surrogates
    became U+FFFD (now WTF-8).
  - **Volume layer W** (`os.cpp`, `salvolpaths.h`): `GetVolumePathNameA` on a
    UTF-8 path through a mount folder outside ASCII returned the parent's
    volume - **another volume was opened**; the mount column was code page /
    best fit. A path that does not fit is left out or refused, never cut.
  - Sweep: an NTFS stream name over 259 UTF-8 bytes matched the default
    stream (its runs joined the unnamed stream); stack overruns
    (`IDS_TEMPDIR` 226 bytes in Ukrainian into 200, `AddNumberSuffix` for two
    equal 300+ byte names, FAT LFN loop, exFAT name entries); error texts in
    UTF-8; EFS capability on W.
  - saltests 14,327 -> 14,383. Interface stays 107, no string, no registry
    change. Probe `probe/undelnames_probe.ps1` + `make_images.py` (FAT12,
    exFAT and a duplicate-name exFAT image written byte by byte - no admin,
    no volume opened): results below; mount points need admin (person step,
    owed). Records: `specs/114-undelete-names/fix-log.md`.
  GUI runs (2026-10-06 night): undelnames 30 / 0 / 4 (pre-114 27 / 1 / 4, every predicted defect seen), 104 3/0.
- 115-undelete-leftovers: **Undelete's Restore Encrypted Files walks any
  depth, {All Deleted Files} drops true duplicates only, one name for
  Windows is one name.** The three "found by 114" items, measured by code
  reading (no GUI that day) and wider.
  - **Restore Encrypted Files** (`restore.cpp`): the source panel's path
    was read into MAX_PATH unchecked (a deeper panel gave "" - relative
    names); `GetDirSize` appended unchecked into that buffer - a name that
    did not fit left the PARENT's path, the parent was listed again: a
    stack overflow at 259 bytes (also a 2-byte overrun); junctions back to
    an ancestor and a target inside the selection recursed without end.
    Now an iterative walk (heap stack of searches) on heap paths of
    `SAL_MAX_PATH_UTF8`; a name that does not fit, an unlistable folder and
    a folder the walk is already in (103's identity - usable 128/64-bit
    ids only - or the normalised final path: an ancestor, the target, a
    folder the restore created) are reported -
    Skip / Skip all / Cancel with the system's text, no new string.
  - **{All Deleted Files}** (FAT, `fat.h RemoveDuplicateFiles`): the
    memcmp of DSSize bytes of the 44-byte `DATA_POINTERS` never removed a
    true duplicate (a directory cluster read twice) and removed a different
    file of up to 20 bytes with the same name. Now size + every data-runs
    block, against every kept item of a run of equal names.
  - **Name identity**: `src/common/salnameorder.h` - the core's
    `SalNameCompareOrdinalCI` / `SalNameEqualOrdinalCI` header-only for
    plug-ins that cannot compile salunicode.cpp (saltests parity);
    `String<char>::NameCmp` in the restore list's and the FAT listing's
    numbering, the duplicate removal and the path lookup.
  - The plug-in's path lookup: exact name first, then the rule (case-only
    pairs are not numbered on NTFS / exFAT).
  - Sweep: a failed backup-form restore deleted
    `<name>` instead of `<name>.bak` (and a named-stream-only record the
    existing base file), `UndeleteGetResolvedRootPath`
    overrun, the main restore's target cut, uninitialised EFS context
    closed, short `.bak` taken as a backup.
  - saltests 14,383 -> 14,401. Interface stays 107, no string, no registry
    change. Probe `probe/undelleft_probe.ps1` + `make_images115.py` (FAT12
    / exFAT images byte by byte, deep / long / junction folders for the
    encrypted route - plain files, no EFS certificate needed or made; the
    command gets Ctrl+Shift+U through the registry for the session):
    results below; real EFS backups NOT DRIVEN (person step). Records:
    `specs/115-undelete-leftovers/fix-log.md`.
  GUI runs (2026-10-06 night): 23 / 0 / 2 (pre-115 shows every defect incl. the stack overflow), 114 30/0/4.
- 116-ftp-passwords: **FTP passwords are the text that was typed, in any script and up to 100
  characters.** Measured first (`research.md`; scratch `probe/m116_subclass.cpp`): the password
  fields' `CPasswordEditLine` was a code-page subclass - every character outside the code page
  became `?` or a best-fit look-alike when typed, shown or read (`voil<U+00E0>` reads as `voila`),
  and since the Connect dialog re-reads its password field on every focus loss, a password stored
  correctly (typed as `ftp://user:password@host`) was saved back as `????` by tabbing through the
  field. Now `AttachToWindowKeepKind`; *Show password* reads, composes (`LoadStrW`) and copies
  (`CopyTextToClipboardW`) UTF-16. The secrets (password, account, proxy and anonymous passwords)
  hold `SAL_FTP_SECRET_BUF` = 301 bytes - the UTF-8 of any 100 UTF-16 units their fields accept
  (`FTPSecretEditLine` keeps the 100-unit limit), so they are never "too long" or cut; login
  commands are built in `FTPLOGINCMD_MAX_SIZE` buffers (static_assert: the longest built-in line,
  `PASS $(Password)@$(ProxyPassword)`, 608 bytes) and the workers pass their real 1,001-byte
  buffer. Wire unchanged (UTF-8 bytes in USER / PASS / ACCT, no UTF8 negotiation); stored format
  unchanged (the scramble's length field takes 999 bytes) - a password over 100 bytes is cut to
  100 by 0.1.8 and older (documented). **The stored-bytes rule** (`SalFtpFieldShowsStored`,
  `src/common/salftpsecret.h`): a field that still shows exactly what the stored value is shown
  as keeps the stored BYTES, any other text is read, an empty field is always read - so a 0.1.8
  code-page password works in Connect, the proxy dialog and the login-error dialog's *Retry* (104
  T012). Do NOT use `EM_GETMODIFY` for such a decision: `WM_SETTEXT` (UI Automation, password
  tools) clears it and the filled-in text would be ignored. User name, address and initial path
  NOT widened (parts of the plug-in's paths) - 104's refusal stays. SOCKS 5 carries 255 bytes
  (RFC 1929): the proxy dialog refuses more, the send never cuts. A refused transfer never stores
  (the proxy dialog had stored an empty value since 104) and the login-error dialog restores its
  values. Shared wipes: `EditLine`'s UTF-16 copy, `SplWToU8`'s buffer on failure. Plug-in
  interface 107, no new string, PRIVACY.md unchanged (reason in fix-log). saltests 14,401 ->
  14,441. Code-only review ACCEPT. Probe
  `probe/ftppwd_probe.ps1` (+ `ftplog_server.py`, 127.0.0.1): results below. Records:
  `specs/116-ftp-passwords/fix-log.md`.
  GUI runs (2026-10-06): 51 / 0 / 4 (pre-116 shows every defect after a probe-only expectation fix).
- 117-checksum-lists: **checksum lists are read in the encoding they were written in** (NEXT-WORK
  plug-in leftovers item 4, from 104). Measured first (`research.md`): coreutils and 7-Zip write
  UTF-8, PowerShell 5.1 writes UTF-16 LE with a mark (`>`), UTF-8 with a mark (`Out-File -Encoding
  utf8`) or the code page with best fit (`Set-Content`: `voila`, `???`), Open Salamander and Total
  Commander the code page (TC: UTF-8 with a mark for Unicode names). The plug-in read only plain
  UTF-8: code-page names "missing", marked UTF-8 and UTF-16 md5/sha lists refused; every `./x` /
  `dir/../x` line "missing" since 004 (`\\?\` keeps `.` and `..`); the existence check was
  `FindFirstFileW` - `???.txt` matched `abc.txt`; its own md5/sha lists were unreadable by
  coreutils (CRLF) and 7-Zip (comment line).
  - **Rules** (`src/common/salcsumlist.h`, header-only): the encoding is decided **once per file**
    (mark; UTF-16 by NUL parity with strong dominance; UTF-8 if the whole file is WTF-8; else
    `GetACP()`; trailing NULs ignored), never per line; OEM never guessed; exact conversion, an
    undecodable byte -> 0xFF (`SAL_CSL_BADCHAR` - not 0x1A: white space is trimmed at a line start
    and would name another file) and the name is "missing" (shown U+FFFD); a NUL inside a line is
    0xFF, never a line end (a cut name is another file's); names with controls, `* ? < > " |` or a
    `:` (streams) are "missing" without a look-up; `GetFileAttributesExW` (no patterns, a folder
    is missing); `.` / `..` / `//` resolved, never above the drive or share; **an absolute name is
    used only on the list's own drive or share - any other, every UNC / `\\?\` / `\\.\` spelling
    included, is "missing" without any file-system call** (review B1: a UNC look-up connected to
    any server a list named and sent the user's NTLM hash); GNU-escaped lines unescaped.
  - **Writing**: md5/sha* lists UTF-8, LF, no comment line (coreutils and 7-Zip read them); SFV
    unchanged.
  - saltests 14,441 -> 14,576 (all single bytes of 18 code pages: never ASCII). Offline model
    `probe/m117_model.cpp` 58 / 0. Code-only review: REJECT (B1 above; S1: one trailing NUL
    refused a list 0.1.8 read), fixed. Probe `probe/csumlist_probe.ps1`: results below. Found,
    not fixed: a path over 780 bytes aborts the Verify. Interface stays 107. Records:
    `specs/117-checksum-lists/fix-log.md`.
  GUI runs (2026-10-06): 82 / 0 (pre-117 60 / 0 showing every old defect), sha256sum and 7z read the saved list.
- 118-plugin-update-close: **an update goes through with a finished comparison, map or
  verification open** (NEXT-WORK item 4 "Left", interface 107 used as is). Read the 088 contract's
  "running operation" as work whose interruption changes or loses data: a read-only computation
  whose only product is the view (comparison, disk scan, verification) holds nothing to lose, also
  while it runs (recorded in `architecture/06`). Declared: the File Comparator window (cancelled
  silently while comparing), Disk Map's map, Log window and tooltip, Checksum's Verify window, and
  a Checksum Calculate window only while EVERY hash type it calculated is saved and unchanged -
  one save writes one type, five are calculated by default (`HoldsWork` / `SavedTypes` with the
  identity of each saved file / `UpdateClosesUnattended` / `WindowsHoldingWork`; a save forgets
  the types whose file it truncates at the open and counts its own only after `ferror`/`fclose`
  succeed - code review S1/S2). Never: the Batch Renamer (masks, Undo), every
  dialog and message box. `Release()` during an unattended close: `CloseAllWindows(FALSE, 5000)`,
  `KillAll(FALSE, 5000)`, and a silent refusal (closing nothing) while a window with work is open
  (Compare Files dialog, Calculate with work, any renamer window). Fixed on the way: a comparator
  closed while comparing lost the close and showed the result's box when the worker finished at
  that moment; Disk Map freed its thread records before its threads ended (write into freed memory
  after a refused `Release`); `CDiskMap::Abort()` used a finished scan worker after handing it
  over to delete itself (`CWorkerThread::AbortAndSelfDelete`); Disk Map still loads in 103-106
  cores, so it calls the 107 services only when `SalamanderVersion >= 107`. Recorded: Disk Map's
  `Release` has no guard for a box or menu opened in between. Other plug-ins' windows recorded (research R6): RegEdit
  Find and FTP Logs / Welcome still decline (declared by 121). saltests 14,576 (unchanged). Probe
  `probe/update_close_probe.ps1` (20 rows, `-Expect fixed|before`) on
  `Debug_x64_118` and `Debug_x64_pre118`: results below. Records: `specs/118-plugin-update-close/fix-log.md`.
  GUI runs (2026-10-06): 20 rows 58 / 0 (pre-118 67 / 0: every plug-in row declined); a real installer update is owed to a person.
- 119-packing-leftovers: **the five leftovers of 106 - no stray volumes, no misnamed set, and a pack
  into its own archive refused with the archive's name.** Measured by code reading (no GUI run was
  allowed that day; the probe followed, results below). (1) A failed multi-volume ZIP pack deleted only the current volume
  - volumes 1..n-1 stayed (Cancel, a source that cannot be opened, a declined "Overwrite?", 106's
  refusal at volume n). Now `CreateNextFile` records every volume it creates with the identity from
  its handle (`CSalPackCreatedFiles`, header-only `src/common/salpackvol.h`) and a failure deletes
  each recorded volume only while its name still holds that file (`SalPackCreatedMayDelete`);
  kept whenever unsure (no file ids: only with the recorded creation time and written size -
  code review SF1); removable media: only the volume still being written (`NextDisk` stops calling
  a closed volume "ours" before the disk can change - SF2); nothing once the archive is complete
  (`outputComplete` - a Move's clean-up failure used to delete the last volume when WinZip names
  were off). A pre-existing volume name overwritten after *Yes* goes with the set (decided).
  (2) The last volume's rename to `name.zip` never replaces and was unchecked: with `name.zip`
  existing (Add) the set ended with `name.z0N` and a Move deleted the sources. Now refused before
  anything is created with the plug-in's existing, translated `IDS_CANTMULTIVOL` (its use had been
  commented out since Open Salamander) where the rename will happen (`SalMultiVolFinalNameTaken`:
  fixed disk, sequential + WinZip names, no SFX); a failed rename is reported and fails the pack.
  (3, 4) The core refuses every pack into an archive that is one of its own sources (106's
  `PackArchiveIsSelectedSource`, now shared) on the Pack dialog - before the "Add or Overwrite?"
  question, which is no longer asked then - F5 / F6 and drag & drop / paste, before any packer:
  ZIP's sharing violation and 7-Zip's archive-inside-itself + "Delete Error (32)" are gone.
  **Behaviour change**: such a pack is refused as a whole - deselect the archive. (5) The refusal
  names the archive: `ShowPackIntoItselfRefusal` = `CFileErrorDlg` with `IDD_ERROR3` and the
  existing copy / move "to itself" text (no new string; "deselect" in words would need one -
  recorded). The check pre-filters plain files when certain (usable ids, one link, the archive's
  real folder known - SF5) and takes the archive's folders from the resolved path too. Also:
  `DetectRemovable` asks `X:\` (also behind `\\?\`), UNC never removable. The probe library
  `fix_probe_lib.ps1` now refuses the Default / Winlogon desktop for every probe (exit inside a
  dot-sourced file ends only that file - it ends the process; opt-out
  `TC_PROBE_ALLOW_VISIBLE_DESKTOP=1`). Interface 107, no registry change, no string. saltests
  14,576 -> 14,655. Probe `probe/packleft_probe.ps1` (106's rows with 119 expectations + L, K, P
  (paste - NOT DRIVEN without a clipboard), Czech; 110 RUN + END rows)
  on `Debug_x64_119` / `Debug_x64_pre119`: results below. Records:
  `specs/119-packing-leftovers/fix-log.md`.
  GUI runs (2026-10-06): 104 / 0 / 8 (pre-119 69 / 35, incl. both sources lost by Move into an existing k.zip), UNC rows pass, 099 24/0, 110 42/0, 113 37/0; paste/drag by hand owed.
- 120-pictview-leftovers: **PictView's pipette and histogram read the real
  pixels; a Rename onto a file another window shows goes through; a
  rotation survives a new background color.** The "Found by 111" entries of
  NEXT-WORK, measured first (`research.md`) with a harness that compiles
  the plug-in's own `wicengine.cpp` + `PixelAccess.cpp` twice (working tree
  / git revision) and compares with Pillow (`probe/pixharness/`).
  - **Pipette / histogram**: the WIC engine hands out 32-bit rows for every
    image (`PV_COLOR_TC32`, stride width x 4); the reader took 3 bytes per
    pixel - pipette wrong for 3 of 4 pixels of every row of every image,
    all histogram channels wrong (2,295 mismatches over 9 fixtures; now 0).
    One pure reader for both, `src/common/salpvpixel.h`
    (`SalPvReadRowPixel`, `SalPvHistogramRow`, `SalPvShownToRow`), bounded
    by the engine's own rows (`WicGetRowsSize`). Also: a mirrored image
    showed the pixel opposite the cursor (the viewer mirrors at draw time,
    the rows never are), `ClientToPicture` overflowed 32 bits zoomed into a
    large image. Other consumers checked: clipboard and print draw through
    `PVDrawImage`, thumbnails take 32-bit rows, Save As / wallpaper encode
    the DIB - correct.
  - **Rename onto a shown target**: the target's windows let it go after
    "Yes" (`ReleaseShownFile(target, own FALSE)` around the replacing
    `MoveFileExW`) and then show what the name holds (`sfaReplaced` = the
    `sfaUnknown` rule: a hard link re-attaches, else reopen at the same
    zoom); busy windows keep it (refused with "Access is denied", 5, as
    before).
  - **Rotation** (105's record): `WicSetBkHandle` re-decoded lazily without
    the viewer's turns (drawn squeezed, saved unturned) - the engine counts
    `Turns` and turns a frame it decodes again (`RedecodeTurned`).
  - **GIF comment, decided**: ASCII as is, other text UTF-8 (GIF has no
    Unicode alternative - the encoder refuses XMP, measured); no change.
  - Found, recorded: the print preview is empty since 006 (`PVSaveImage`
    with scaling refused by the WIC engine).
  - saltests 14,655 -> 17,423. No new string, interface 107, no registry
    change. Probe `probe/pv120_probe.ps1` (hidden desktop; the pipette rows
    only with `-VisiblePipette` on the visible desktop - the pipette follows
    the real cursor): results below. Records:
    `specs/120-pictview-leftovers/fix-log.md`.
  GUI runs (2026-10-06): 17 / 0 / 5 (pre-120 15 / 2: rename onto a shown target "Access is denied" (5), rotation lost); 111 85/0/2, 105 56/0/4; pipette + histogram rows need an unlocked visible desktop (owed).
- 121-small-batch: **eleven small defects of the backlog, measured first** (`research.md`; no GUI
  run was allowed that day - the probe runs followed, results at the end). Find's *Look in* holds any path the program can (`SAL_MAX_PATH_UTF8`, limit
  `SAL_MAX_PATH_W` units; a panel path that does not fit is left out, never cut - it was cut at 259
  bytes, inside a character too; heap copies behind it, `CSearchForData::Dir` was an unbounded
  `strcpy`; `src/common/salfindtext.h`). The message box breaks lines only inside a word wider than
  the box, after a path separator when it can (`SalMsgWrapBreaks`, `src/common/salmsgwrap.h`) - it
  cut every paragraph at its edge. Every core copy command reports a failed copy with the system's
  reason under "Copy To Clipboard" (`CopyTextToClipboardU8Report` / `WReport` /
  `ShowClipboardCopyError`; the copy functions leave the reason in `GetLastError`; the echo variant
  was silent too); the plug-in services unchanged. UTF-8 error fields get `LoadStrU8` (8 sites;
  only a code page lacking the language's letters showed it). Disk Map's log list view is Unicode
  (`NFR_UNICODE`, `SplDisplayTextToWAlloc`). `SplBrowseForFolderU8` enables OK only for a
  file-system item and resolves NetHood folder shortcuts (whole class id). The File Comparator's
  `Release` closes windows that register while it waits (the fcremote "rejected to unload" race).
  Checksum reports a failed save. FTP refuses a typed user name / host / password that does not fit
  (`SalFtpTypedLoginTooLong`, "too long path" - a cut was another account or server), wipes the panel
  login's last command and secret copies, cuts display texts at a whole character
  (`SplU8CopyTrunc`). RegEdit's Find (while idle) and FTP's Logs / message windows are declared for
  an update (interface 107). Item 12 (Save dialogs opening another folder, found by 117's GUI run)
  measured and reverted: Windows records each program path's first initial folder
  (`ComDlg32\FirstFolder`) and opens the last-used folder when asked for that one again; only
  `IFileDialog::SetFolder` overrides it. Romanian `IDS_CANTMULTIVOL`
  capitalised and pinned. Code-only review ACCEPT (its NITs fixed: a code-page tail kept, the
  clipboard block freed, the RegEdit declaration withdrawn before the thread, Disk Map's
  `FormatMessage` buffer). No new string, interface 107, no registry change. saltests 17,423 ->
  17,498. Probe `probe/batch121_probe.ps1` (`-Expect fixed|before`): this build every row PASS (K0
  reported), the build before shows every old behaviour (S1 "rejected to unload" 6/6); regressions
  101, 102, 117 clean, 118 58/0 after the item 12 revert. Records: `specs/121-small-batch/fix-log.md`.
- 123-new-version-check: **the program tells the user about a newer version** - a notification
  shortly after start-up (on by default, about once a day), *Help > Check for New Version*, a
  line in the About dialog, an option on Configuration > General. No version bump of its own.
  - **Source**: one `GET https://api.github.com/repos/tandemcommander/tandemcommander/releases/latest`
    (measured comparison of the alternatives in `source-analysis.md`: 60 requests/hour per IP,
    a `User-Agent` is mandatory, an unauthenticated `304` still counts against the limit).
  - **The program never opens an address from the network.** `src/common/salupdcheck.h`
    (header-only, pure, in saltests) builds the installer and release-notes addresses from the
    validated version; the answer must contain exactly those (tag = canonical
    `v<a>.<b>.<c>`, asset `tandemcommander-<ver>-x64-setup.exe` in state `uploaded`, not a draft
    or pre-release). **Consequence for releases: the installer keeps that name and a release is
    published with its asset attached.** A small strict JSON reader lives there too (it does
    not check the text encoding - do not reuse it for text that is shown).
  - **Request** (`src/updcheck.cpp`): WinHTTP in **asynchronous** mode on a worker thread,
    `winhttp.dll` delay-loaded (`sal_base.props`); fixed `User-Agent`
    `TandemCommander-updatecheck`, no version, no identifier; cookies, authentication and
    redirects off or the request is not sent; one 12 s deadline for the whole request, enforced
    by the worker (`UpdAwait`); a cancel never touches WinHTTP from the main thread. The first
    version was synchronous and cancelled by closing the handle from the main thread - Microsoft
    forbids that, and it could not bound a dripping server.
  - **State**: `HKCU\...\0.1\Update Check`, written at once and read fresh (not part of
    `Configuration`, so the option holds across instances and with *Save configuration on exit*
    off); one claim per interval under the mutex `Local\TandemCommanderUpdateCheck`; 24 h after
    an answered attempt, 1 h after an unreachable one. Contract:
    `specs/123-new-version-check/contracts/stored-state.md`.
  - **Notification** (`src/upddlg.cpp`): a **modeless** dialog owned by the main window - it
    declares `SALCLOSEAPP_WINDOW_PROP` (an installer's update goes through with it open) and,
    when the user is working, appears without taking activation or focus: **a dialog's
    `WM_INITDIALOG` must return FALSE for that** (TRUE gives the first control the focus and
    with it the activation, even for a hidden dialog - the first review's blocker). Links post
    commands that are **not** their control ids (an `SS_NOTIFY` static sends `WM_COMMAND` with
    its own id on every click), and `CUpdateLink` takes Enter itself (an `IDOK` redirect cannot
    tell Enter on a link from the default button's access key).
  - Debug-only seams for probes (`TC_UPDATECHECK_URL` loopback, `..._PRETEND_VERSION`,
    `..._OPENLOG`); absent from Release (checked by string search).
  - `PRIVACY.md` changed in the same change: this is the first time the program contacts the
    internet without being asked. Default-on is a documented exception to the opt-in principle
    (as panel tabs, 078).
  - **Verification**: tests designed and run by independent agents in two rounds - a behaviour
    probe on the hidden desktop against a fixture server (`probe/updcheck_probe.ps1`, final run
    238 PASS / 0 FAIL / 2 NOT DRIVEN), an adversarial differential test of the parser against
    Python's `json` (3.77 million inputs, no security defect), two refute-first code reviews
    (1 blocker + 8 should-fix over both rounds, all fixed). saltests 17,498 -> 18,184. Real
    endpoint checked with Debug and Release builds. 8 languages (Czech pinned whole; 10,376
    DeepL characters).
  - **Traps of the session**: Bash here-documents in the agent shell collapse doubled
    backslashes (two generated literals and one probe script were corrupted - write scripts with
    the editor tools); a hung helper probe left the product's registry key in probe state
    twice (restored from a verified backup); the Restart Manager restarts the program on the
    *visible* desktop.
  - Owed to a person: design acceptance, real keyboard / mouse / screen reader, a real browser
    download, a real installer update; at the next release the "newer" path in a Release build
    and one antivirus scan. Records: `specs/123-new-version-check/closing-report.md`,
    `fix-log.md`.
- 124-regedt-key-text: **Registry Editor's panel texts are UTF-8** (GitHub issue #3, for 0.1.10).
  The plug-in gave the panel code-page text where the core displays UTF-8: the word for a key
  (`IDS_KEY`), the selection templates, the name of the `(Default)` value, the preview of text
  values, date and time of a key. Measured on 0.1.9 first (nine languages): the **information
  line** was garbled (it has no fallback), the **Size column was right** - a cell that is not
  valid UTF-8 is drawn as code page (`fileswn4.cpp`) - so the report's "or the Size column" did
  not reproduce, and the report's patch would have **broken the plug-in's Find window**, which
  converts the same text with `CP_ACP` (built as a negative control: `KLĂŤÄŚ`). The fix keeps the
  word twice (`KeyText` UTF-8, `KeyTextW` wide), never cut (a text that does not fit becomes
  `KEY`); `LoadStrU8` local to the plug-in; the text-data preview is UTF-8 with `...` after a
  whole character. The first version fixed only the key word and the selection text - the
  **independent review found the rest of the same line** (`(Default)`, value data: wrong in all
  nine languages, English included).
  - **Reading owner-drawn text in a probe**: `specs/124-regedt-key-text/probe/shotocr_lib.ps1` -
    `PrintWindow` (works on the hidden desktop), crop of a child window, `Windows.Media.Ocr`
    (only the Czech recognizer is installed) at three sizes; verdict classes `exact`, `folded`
    (diacritics), `near` (one letter, words of 12+ letters). U+FFFD is read as some other letter,
    so garbled text does not match. Keep the crops and look at them; the recognizer returned
    nothing for a short English line at one size.
  - `LoadStrW` of the core never returns NULL or an empty text (a missing string gives
    `ERROR LOADING WIDE STRING`). `tools/check_encoding.py` does not scan `plugins/`.
  - View-mode commands: `CM_ACTIVEMODE_1 + template index`; Detailed is index 2 (2972).
  - Probe `probe/regkey_probe.ps1`: 0.1.9 PASS 48 / FAIL 33, fixed PASS 81 / FAIL 0. Left out:
    column names (code page in the whole program), the plug-in's message boxes (issue #7).
- 125-unc-server-shares: **`\\server\` offers the server's shares** (GitHub issue #5, for 0.1.10).
  An incomplete UNC path went only to a Network plug-in (`GetFirstNethoodPluginFSName`), and
  none ships (`nethood=off`, 007): "A share name is missing in the path specified". The issue
  proposed `nethood=on`; measured first - it works and builds unchanged, but the Debug build
  reports **"Detected memory leaks!" at every exit** after the plug-in was used (it terminates
  its threads with zero wait), a missing server opens an empty panel silently, and an audit found
  more (research R2). **The plug-in policy was not changed** - recorded as a decision for the
  maintainer in `specs/NEXT-WORK.md` section D. The core got a fallback for exactly that branch
  of `CFilesWindow::ChangeDir`: `CUncSharesJob` (`shares.cpp`; worker thread, `NetShareEnum`
  level 1, `WNetOpenEnumW` when the list is refused, registered with `AddAuxThread`),
  `CFilesWindow::PickServerShare` (`fileswnb.cpp`; 400 ms quiet, then the safe wait window with
  the existing "Checking path" text; a `CMenuPopup` under the directory line like the directory
  history), pure rules in `src/common/saluncserver.h` (saltests). No new string. `PRIVACY.md`
  changed in the same change.
  - **Traps**: `small` is a macro of the Windows headers (`rpcndr.h`); a wait loop that polls
    `UserWantsToCancelSafeWaitWindow()` must call `GetAsyncKeyState(VK_ESCAPE)` once first or an
    Esc pressed earlier cancels it (review); a core worker thread needs the `F` -> `FEH` -> `FBody`
    shape and `AddAuxThread` (review); at start-up an untitled `#32770` is the splash screen.
  - **Probing a popup menu**: it is owner-drawn (`PopupMenuClass`) and takes posted
    `WM_KEYDOWN`; the text recognition misreads short names with `$`, so the list is checked by
    choosing the k-th item and reading the path the program then tries from the reopened Change
    Directory field. The wait window's Esc / Close read the real keyboard and mouse - NOT DRIVEN.
  - Debug-only seam `TC_PROBE_UNC_SHARES` / `_DELAY` / `_ERROR`
    (`specs/125-unc-server-shares/contracts/probe-seam.md`); absent from Release (string search).
  - Probe `probe/unc_probe.ps1`; saltests 18,184 -> 18,277.
- 126-package-api-late-bind: **no static import of the package functions** (GitHub issue #6, for
  0.1.10). `CSalShellOsProbe::GetPackagePath` (`src/common/salshell.cpp`, feature 071) called
  `GetPackagesByPackageFamily` (Windows 8) and `GetPackagePathByFullName` (Windows **8.1**)
  directly; as static imports of kernel32 they stop the loader on older systems before the
  program's own "You need at least Windows 7" check - no window, no message (0xC0000139). Now
  `SalShellResolvePackageApi` (`GetProcAddress`, no cached state) + `SalShellPackagePath` (the
  lookup with the two functions as a table; NULL = "not found"). **Windows 11 stays the only
  supported system**; the failed start was not reproduced (no such machine) - verified were the
  import tables: 796 -> 794 static imports, the two removed, none added; 0 of 218 PE files of the
  Release tree import them.
  - `specs/126-package-api-late-bind/probe/pe_imports.py`: a PE import-table reader in pure
    Python (`list`, `delay`, `find`, `diff`, `check`) - use it when a "does not start" report
    names a missing function.
  - Known, outside the change (review): the installer ships no UCRT (Windows 7 needs
    KB2999226); `codeview.spl` / `mdview.spl` import `advapi32!EventSetInformation` (Windows 8+)
    through `WebView2LoaderStatic.lib`.
  - saltests 18,277 -> 18,304; `saltests --package-path <family>` prints the real lookup
    (compared with `Get-AppxPackage` by `probe/package_live.ps1`).
- 127-mixed-template-texts: **a `LoadStr()` template with a UTF-8 name or `GetErrorText()`**
  (GitHub issue #7, for 0.1.10). The composed bytes are not valid UTF-8 when the translation has
  non-ASCII letters; UTF-8 sinks fall back to the code page and the name / Windows error text
  comes out as mojibake (English cannot show it). Measured on 0.1.9 in Czech first: Find log,
  Find status line, a Copy error box - all three of the report. The report listed 21 + 4 places;
  an inventory of every such composition (`specs/127-mixed-template-texts/probe/scan_mixed.py`,
  46 of 130 in the core) and a read of every sink found about 45, among them **a generated file
  name** (`IDS_NEWNAME_COPY`), the Find window's title, the View With / Edit With menu, and five
  Registry Editor messages. Fix: template through `LoadStrU8`, bounded composition,
  `SalU8TrimIncompleteTail` after a composition with a path; `LoadStrU8` wraps and converts again
  instead of answering `ERROR LOADING STRING` at the end of its buffer.
  - **The reverse rule** (the review rejected the first version, which was green everywhere):
    when a template becomes UTF-8, every other piece and the sink must be UTF-8 too. Three
    regressions were caught: the Copy / Move subject ends in `CProgressDialog::SetDlgTitle`, which
    used `SetWindowText` (A) and a 200-byte buffer - now composed wide (`ProgressTitlePieceToW`,
    `SalSetWindowTitleW`, compare with `InternalGetWindowText`); `codetbl.cpp` had a `LoadStr()`
    argument and A-API paths (`MsgPath()`); `salamdr1.cpp` a second code-page piece.
  - **Right as they are** (both parts code page - do not "fix"): the font description
    (`dialogs4/5.cpp`, `LOGFONTA`), plug-in file names in the start-up progress (`plugins2.cpp`,
    069), `callstk.cpp` (`RegEnumKeyExA`, marked for the guard). After the fix the inventory lists
    exactly 18 rows.
  - Deferred to NEXT-WORK: `GetCommonFSOperSourceDescr` and `salamdr3.cpp` folder-creation texts
    (wrapped by plug-ins in code-page sentences), the other plug-ins (137 candidates, FTP 86).
  - Guard: `mixed-composition` counts `GetErrorText(` as a UTF-8 argument and `params.Text =` /
    `log.Text =` as sinks (22 findings before, 0 after). It is a 14-line heuristic; it has no
    reverse rule.
  - Traps: `_snprintf_s(buf, _TRUNCATE, ...)` needs an array, not a pointer parameter; a line
    inserted after the body of a brace-less `if` / `else` lands outside it; a function with
    `__try` cannot hold an object with a destructor; PowerShell `(F 1 'a' + "b")` passes `+` as an
    argument; "Copy to the same folder" is refused - the generated copy name comes from Paste.
  - Probe `probe/mixed_probe.ps1`: 0.1.9 Czech FAIL 6, fixed PASS 13 / FAIL 0 / NOT DRIVEN 1
    (the copy name: the clipboard held data the probe may not overwrite).
- 128-shortcut-target-unicode: **Enter on a `.lnk` reads the target wide** (GitHub issue #8, for
  0.1.10). The report had a picture only (`ARCHIV.lnk`, error 123). Cause found by measuring:
  `CFilesWindow::Execute` (`fileswn2.cpp`) and `FocusShortcutTarget` (`fileswn0.cpp`) used
  `IShellLink` = `IShellLinkA`; the target arrived as code-page bytes into UTF-8 code and the path
  check answered `ERROR_INVALID_NAME` for **every target with a non-ASCII letter**. Feature 069
  had fixed the same thing for the drop-target code only. Now `IShellLinkW` through one
  header-only rule, `SalShellLinkGetPathU8` (`src/common/salshelllink.h`: whole path or failure,
  `S_FALSE` = no path), with the real buffer sizes instead of `MAX_PATH`.
  - Probe `probe/lnk_probe.ps1`: 0.1.9 FAIL 7 of 18, fixed PASS 18. saltests 18,304 -> 18,343
    (real shortcuts to Czech, Greek, Chinese + emoji folders).
  - Traps: `WScript.Shell.CreateShortcut` refuses a target outside the code page - write test
    shortcuts with `IShellLinkW`; *Go to Shortcut Target* enters a folder target; a saltests
    check against `%TEMP%` must use the long path form and a case-insensitive compare.
  - Left (NEXT-WORK D): `GetSHObjectName` returns code page (server links, Network plug-in only);
    drop-target code still `MAX_PATH`; A shell calls returning paths (`SHGetFolderPath`,
    `GetOpenFileName`).
- 124-128, **second verification** (2026-10-13, asked for by the maintainer): clean rebuilds,
  every probe again on the fixed build and on 0.1.9, one refute-first agent per feature with
  tests of its own, a review of the follow-up. No blocker; what it changed:
  - 124: *Copy Name / Full Name / Path* of the Registry Editor went through the code-page
    `CopyTextToClipboard` with UTF-8 text (a regression for the translated `(Default)`) -
    `CopyTextToClipboardW`; the Find window's size cell read the core's UTF-8 number text in the
    code page.
  - 125: `SalUncShareNameUsable` (no slash, no `.` / `..`); a refused list is not reported as
    "no share" when the fallback answers with nothing; the `ERROR_MORE_DATA` loop ends.
  - 127: **the inventory script had missed whole forms** - `FormatMessage` (`PackErrorHandler`,
    89 calls, now `src/common/salinserts.h`), `sprintf` with the `LoadStr` on another line
    (viewer "not found", regular expression errors, unknown variables), and the byte-wise join
    in `CMessageBox::CopyToClipboard`. Three new probe rows fail on 0.1.9.
  - Traps: a zero from `check_encoding.py` or from an inventory script is not "complete" - have
    someone search with another method; the hidden desktop cannot read the clipboard at all
    (`GetDataObject` fails), so every clipboard row is a person's step; a probe started from the
    PowerShell 7 tool needs the Windows PowerShell `PSModulePath` (`Get-FileHash` missing
    otherwise); an external archiver whose program is not found makes its extension an ordinary
    file (feature 084) - to reach the archivers' error handler point it to a file that is no
    program; `.txt` opens in the Code Viewer plug-in, the internal viewer needs an unclaimed
    extension.
  - The visible desktop does not help while the workstation is **locked**: `OpenClipboard` is
    "access denied" and nothing can be made the active window (the active one is `LockApp`). A
    probe row that presses a real key must check that the program under test is the active
    window first (`unc_probe.ps1` row W2 does).
  - Evidence: `specs/12N-*/fix-log.md`, section *Second verification*; `probe/*_verify2.txt`.
- 129-regedt-wide-inserts: **a narrow printf with `%ls` fails at the first letter above U+00FF**
  (the "C" locale; `_vsnprintf_s` gives -1 and an empty buffer, `vsprintf` stops there). In the
  Registry Editor that made the "create the target key?" question and the self-copy message
  **empty boxes**, cut the "unable to open / access key" errors, and - not a text at all - gave
  the values of different keys one name in the disk cache (F3 on `v` of two keys: one file).
  Found by the second verification of 124-128, fixed for 0.1.10. New header-only rule
  `src/common/salwideinserts.h` (`%ls` -> UTF-8 of the wide insert, whole text on the heap;
  `SalWideLowerToU8Alloc`), `FormatWideU8` and `ErrorHelperWide` in the plug-in. No new strings.
  - Probe `probe/wide_probe.ps1`: 0.1.9 FAIL 4, fixed PASS 19 in Czech and English; saltests
    18,395 -> 18,447.
  - The review refuted the first version: a UTF-8 name kept `SG->ToLowerCase`, a **byte table of
    the code page** - on UTF-8 it changes continuation bytes, so `ê` and `ú` (C3 AA / C3 BA on
    1250) became one cache name, a pair that was distinct before. Fold case on the wide text.
  - Traps: letters up to U+00FF pass `%ls` by accident - test with `č`, not `é`; a probe that
    answers boxes must press buttons in ITS order of preference (the window's order put OK
    before Cancel and the probe copied keys), and check the state afterwards; the internal
    viewer's title is the cache file of a viewed plug-in item.
  - Left (NEXT-WORK D): `peviewer/pefile.cpp` narrow `%ls`; Move and the class-name question
    not driven.
- 130-plugin-mixed-templates: **the mixed-template defect of 127 (GitHub #7) in the plug-ins** -
  a plug-in's `LoadStr` (code page) composed with a UTF-8 name or `GetErrorText`. 13 plug-ins
  changed (7zip, checksum, tar, uncab, uniso, zip, sftp, renamer, dbviewer, pictview, peviewer,
  diskmap, portables); filecomp, regedt, codeview, mdview, folders, undelete right as they are.
  **FTP is not done** (`triage/ftp.md`: facts and an eight-step plan; needs a test server and a
  decision about the log's bytes).
  - New shared header `src/plugins/shared/splloadstru8.h`: `SplLoadStrU8(gen, module, id)` (a
    per-module cache, pointer valid until unload, any thread), `SplLegacyToU8Alloc` /
    `SplLegacyToU8`. Each plug-in: `const char* LoadStrU8(int)` next to its `LoadStr`.
  - Core `src/zip.cpp`: the progress dialog a plug-in opens set its **title through the code
    page** (wrong for an accented archive name in every language) - now wide; a line cut at 299
    bytes ends at a whole character.
  - Probe `probe/plugmix_probe.ps1` (plug-in menu commands by a hot key written to the registry
    for the run, the method of 117): 0.1.9 Czech FAIL 4, Slovak FAIL 2; fixed 19 / 0 and 4 / 0;
    English identical on both builds. saltests 18,447 -> 18,471.
  - Traps: **a sentence without an accented letter works by accident** - Czech `Archiv '%s' je
    OK.` passes on the old build, Slovak `Archív` fails: pick the language per row; a locked
    archive is reported by the core, not the plug-in; a slim lock does not compile in plug-ins
    built for an older Windows macro; `SplU8TrimTornTail` on code-page text drops a final
    accented letter - trim only what was cut; a "local path" on download ends with the remote
    name (the server's bytes) - the review found it as a regression (a readable box would have
    been garbled).
  - Per-plug-in records with every composition and its verdict: `triage/*.md`; defects seen on
    the way are in NEXT-WORK D.
- 131-plugin-defect-batch: **about thirty notes of 130 ("seen by reading"), each measured first**,
  a verdict per item in `items/*.md`. Real and fixed, the serious ones: **FTP crashed on a host
  name with `%`** (`ftp://a%sb/`: the name was printed into a buffer then used as a printf format;
  `FTPDoublePercents` in `ftputils.h`); **a ZIP self-extractor favourite with a name of 50+ UTF-8
  bytes did not load and was deleted with its options at the next save** (names are UTF-8 from the
  dialog to the registry now, compared with `SalNameOrderCompareCI`); **SFTP acted on cut paths**
  (`PosixPathAppend` / `LocalPathAppend` return nothing when the result does not fit and every
  caller refuses; a move deletes nothing) and showed no or a stale reason (`SetLastErrorFromSftp`
  reads the server's status); PictView *Update Thumbnail* could not open accented paths (a
  code-page path for an engine that reads UTF-8) and cut paths at `_MAX_PATH` without a
  terminator; PE Viewer's narrow `%ls`; Undelete's virtual folder names (code page used as names);
  Renamer's stale Windows reason and its histories read with 260 bytes; DiskMap's
  `CZStringBuffer` off by one; File Comparator's 32-byte font field; 7-Zip's `((int*)&err)[1]`.
  Core: the last three code-page templates of `CheckAndCreateDirectory`, the plug-in dialog
  subject cut at `MAX_PATH`. Spanish 7-Zip "es Aceptar", "SFTP error" in seven languages (pinned).
  - **Not defects / unreachable** (recorded): the three FTP notes called most serious - `char` is
    unsigned in every plug-in (`/J` in `plugins/shared/vcxproj/plugin_base.props`), and the core
    never passes a user part of 260 bytes or more; 7-Zip's `SetWindowText` (A) on a core
    `CStaticText` is right (the control reads the bytes as UTF-8 - the W call would be wrong).
  - Probe `probe/batch131_probe.ps1`: 0.1.9 crashes, the new build shows the message. Most rows
    need a server, a volume or a special file and were not driven (list in the fix-log). SFTP
    harness 85 / 0; regressions 113, 117, 127, 129, 130 clean.
  - Three reviews, no blocker: `StrICmp` on UTF-8 folds continuation bytes through the code
    page's table (`VÍR` = `VÝR`) - a UTF-8 name is compared with the name rule; a third template
    site in the core was missed; one unchecked join in SFTP.
  - Left: NEXT-WORK D (PictView's EXIF writer can replace a malformed JPEG by a truncated one;
    SFTP's silently ended listing; FTP autorename).
- 132-pictview-thumbnail-verify: **Update Thumbnail repaired, with a rule that it cannot lose
  anything**. Measured first: EXIF.DLL (the old libexif "libjpeg" reader/writer) reported success
  for 6 of 13 shapes of JPEG it had spoiled (every APP1 parsed as Exif - **XMP became an empty
  Exif block**; the loader returns at the first thing it does not understand and the writer
  writes what was collected; 16-bit lengths wrap) - but **the command never reached it**: the
  built-in engine refused the scaled JPEG in memory since 006 (the note of 131 "possible loss,
  more files reach it now" was wrong - a premise not measured). Three independent layers:
  `src/common/saljpegkeep.h` (`SalJpegRewriteKeepsFile`: the new file differs only in ONE
  thumbnail carrier - an Exif APP1 or the JFXX APP0 blocks; bytes from SOS to the end of the file
  identical; not understood = no), the plug-in's check before `SalReplaceWithTempW`, and the
  library (no APP1 is parsed on load - raw bytes until `jpeg_data_set_exif_data` replaces the
  first Exif block; incomplete data and oversized blocks fail the save).
  `WicSaveJpegThumbnail` in `wicengine.cpp`.
  - Probe `probe/thumb132_probe.ps1` in three modes: `fixed`, `before` (0.1.9: nothing happens),
    **`oldlib`** (new plug-in + EXIF.DLL of 0.1.9: what the old library spoils is refused by the
    plug-in alone). `probe/exifdll_measure.py` calls the DLL directly (ctypes, Pillow).
  - Review (own ASan harness, 24,000 mutated files): an Exif block behind APP12 "Ducky" / APP14
    was serialised again with private tags dropped while only a JFXX block was added, and the
    rule said "same" - hence "one carrier changes" and raw Exif blocks; a wild read in libexif
    (IFD offset near 4 GB) guarded.
  - Traps: `jpeg-data.c` is ISO-8859-1 (edit bytes); the engine never sets `PVFF_EXIF` (the
    viewer's Exif dialog and auto-rotation are dead - left); owed: real camera files (MakerNote).
- 133-sftp-server-verify: **the first GUI probe of the SFTP plug-in against a server**
  (`probe/sftp133_probe.ps1` + `probe/fixture133.sh`: container `tandem-sftp`, address typed into
  Change Directory, password dialog answered, the core's commands 727-730 posted, the server's
  state read through `docker exec`). It showed 131's SFTP fixes working (on 0.1.9: no reasons, a
  file stored under a cut local name, a directory created with a 155-byte name instead of 250).
  **`CSFTPSession::ListDir` returned TRUE for a listing that ended with an error** (`rc <= 0`
  was "end"): a copy took 9 of 30 files without a word. Only `rc == 0` completes a listing now;
  `DeleteRecursive` removes a directory only when every item of it is gone (no request to the
  server "it will refuse if not empty"); messages are composed on the heap (`SFTPShowPathError`
  - 1,200 bytes lost the reason behind a long path); `sftp://` with two slashes is accepted.
  - **Premises corrected by measuring**: a move does not delete what it did not download - it
    deletes only top-level files, **a moved directory stays on the server whole** (left,
    NEXT-WORK); OpenSSH's `sftp-server` does not list names whose full path passes its `PATH_MAX`
    (4,096 = the plug-in's own limit), so the remote "too long" refusal cannot be reached with
    it - the local join can (a long target folder).
  - Seam `TC_SFTP_PROBE_LIST_FAIL` (debug only) built in FIRST with the old logic, so before and
    after come from one tree. libssh2 does not record an error for `BUFFER_TOO_SMALL` - the
    session's text is used only when its code is the call's code (review).
  - Probe notes: F-keys posted to the panel do nothing on the hidden desktop - post the command
    ids; a re-opened input dialog after an error must be cancelled, or the probe loops.
- 134-ftp-mixed-templates: **the FTP client on the rule of 127 / 130, and its log as UTF-8**.
  Map = the read-only triage of 130 (`specs/130-plugin-mixed-templates/triage/ftp.md`, about 104
  sites); measured first with a probe and **its own FTP server** (`probe/ftp134_server.py`,
  standard library: an accented tree, refusals with the name as UTF-8 / code page 1250 / none,
  a slow file, every received line logged as hex): 9 garbled texts in Czech, **2 in English**
  (the log, and a message with a code-page reply) - both only deduced by the triage. Shared
  pieces first (`LoadStrU8`, `FTPTextToU8`, the core's `GetCommonFSOperSourceDescr` as UTF-8),
  then **four parallel packages by file group with written contracts between them** (who gives
  UTF-8 after the feature: `GetProxyError`, `GetTypeNameForUser`, the log sink) - the build of
  37 files was clean at the first attempt. The log: `CLogs::LogMessage` makes every message
  UTF-8 on its own, so 85 plain texts needed no change; Save writes a BOM, Copy is Unicode.
  - SC "nothing sent changes" is measured: the server's byte logs before / after are identical
    (`probe/compare_server_logs.py`).
  - Review found one real regression: **`SplU8ToW` into a list view's 260-unit buffer returns 0
    also when the text does not fit** - a long cell that had become valid UTF-8 fell back to
    the code page with every accented letter doubled (`FTPCellTextToW`). And: a "torn tail"
    rule must not drop a code-page letter - convert the tail, do not cut it.
  - Probe traps: the `ftp\.spl$` pattern also matches `sftp.spl`; the welcome-message window
    and the "queue still holds operations" question at exit; a PowerShell 5.1 script must stay
    ASCII (a literal U+FFFD slipped in through the editor).
  - Not driven: bookmark dialogs, password prompt, Save / Copy log, FTPS - fix-log, section 5.
- 135-pictview-real-photos: **132 measured on real camera files - and it damaged a third of
  them.** `probe/exif_real_measure.py` over 91 files of the public collection
  `ianare/exif-samples`: libexif's parse-and-serialise changed or shortened the MakerNote in 23
  of 82 (Nikon 28,378 bytes -> 1,413), moved it in 3, lost IFD0 tags; the rule of 132 passed
  them all because it did not look inside the Exif block ("by design", and the 132 review had
  listed MakerNote as not checked - **a "not checked" on user data is a task, not a note**).
  Now `src/common/salexifthumb.h`: the thumbnail swapped with **no other byte moved** (cut and
  append at the end, or a new IFD1 appended and relinked), and `SalExifRewriteKeepsData` as the
  writer-independent check inside the rule. 82 of 82 the same; Pillow and WIC agree.
  - Review (ASan fuzz, 2.8 M calls): the "append" way left **the old thumbnail readable in the
    file** (privacy: people update a thumbnail after cropping) - zeroed now; allowed-to-change
    ranges must be proved to lie apart from real data (`SalExifIfdMeets`) or a wrong length in
    the file turns the Exif IFD into "thumbnail bytes".
  - Traps: `far` is a Windows macro; a Bash here-document turned `\\xFF` of a Python string
    into the byte itself inside a C++ source; `python -I` hides user-site packages (Pillow).
  - Real sample sets for file formats are worth fetching before a writer ships, not after.
- 136-ftp-verify-rows: the rows 134 left "read and reviewed only" driven in the program -
  bookmark dialogs (New / Rename / Remove), the password prompt, the login error with a UTF-8
  and a code-page refusal, Save log read back from the file. Rows live in 134's probe
  (`ftp134_probe.ps1`: BMK, PWD, LOGINU8, LOGINCP, SAVELOG; the server refuses users named
  `refuse-u8*` / `refuse-cp*`). 0.1.9: 6 FAIL in Czech, 3 in English; final build 31 / 0 in
  both. No defect found - the value is that the dialogs were started at all.
- 137-names-cut-at-byte: the two "name cut at a byte" notes of 131, measured: **Quick Rename on
  a plug-in file system** cut a typed name at 259 bytes and sent it (`lstrcpyn(newName, ...,
  MAX_PATH)`, `fileswn5.cpp`) - refused now; the review found the worse twin in the **in-place
  rename line**: when the UTF-8 form did not fit 259 bytes a "legacy A call" supplied the name
  through the code page, best-fit and cut. **FTP automatic rename** cut the shortened name at a
  byte: with an accented name the download failed with error 123 (not "another name", as the
  note said) - `SplU8WholePrefixLen` in `splunicode.h`. Rows QR250 / QRLONG in the SFTP probe of
  133 and AUTOREN in the FTP probe of 134 (the plug-in's setting written to
  `Plugins Configuration\FTP` for the run).
  - A whole-character cut can keep ZERO characters - then fail, do not create `.txt`.
  - Linux servers hold 255 bytes per name, so the cut 259-byte name was refused by the test
    server; the defect needs a server with longer names. Measured facts beat the note.
- 138-sftp-move-directory: **Move from an SFTP server moves directories** (they were copied and
  stayed whole). Each item removes its own source: a file after `RemoveMovedFile` confirmed the
  local size equals the server's (asked again), a directory when every item was moved. **The
  review found the loss path before the commit**: two remote names that are ONE local file
  (case, `a:b`/`a?b` -> `a_b`, trailing dots, 8.3 alias) - the second download overwrote the
  first after an ordinary "overwrite?" question and both sources were removed. The operation
  now remembers what it wrote **by file identity** and never writes such a file again. Also: no
  resume in a move; the local directory must really exist; one box for refused removals.
  - Rows M1, MTREE, MKEEP, MSKIP, MCASE, MBLOCK in the SFTP probe - the verdict is the server's
    and the disk's state, file by file.
  - Whenever a download becomes a delete: think of name collisions on the receiving side.
- 139-sftp-no-silent-overwrite: **SFTP replaces nothing without a question and never before
  the replacement is whole** (final review of the cycle; all of it in 0.1.9). Upload: `lstat`
  the target, ask (`ConfirmOverwriteRemote`), write to `.tcpart-<8 hex>` in the same directory
  (`OpenWriteNew` = CREAT|EXCL; the name does not derive from the target's - NAME_MAX), confirm
  the size, `Rename(temp, target, replace)`. **The route is decided on the EMPTY temporary
  file** (owner, group, permission bits made equal to the old file's, or else in place at
  once) - the first version decided after the data and sent a file twice; between its two
  passes a cancel truncated the target, and the complete temp was deleted before the in-place
  write was confirmed (second review). In place (after the question, logged) only for: a link
  or non-regular target, no right to create / rename there, another owner, set-id bits.
  Download over a local file: `SalCreateTempNextToW` + `SalReplaceWithTempW`. Quick Rename:
  `Rename(from, to, FALSE)` = plain `SSH_FXP_RENAME` after an `lstat`; a case-only rename is
  decided by listing the directory. Upload restructured like 138's download (tri-state, each
  item removes its own source, `DeleteLocalTree` gone, failed `Mkdir` / listing = failure,
  only name-surrogate reparse points skipped - aloud, heap block per level).
  - Rows UPASKNO, UPASKYES, UPFAIL, UPNEWFAIL, DLFAIL, RENEXIST, RENCASE, UPSYM, UPMV, UPMOVE,
    UPLINK; seam `TC_SFTP_PROBE_XFER_FAIL="<suffix>;<bytes>"` (debug). `Row-Up`: the probe's
    keys reach the LEFT list only - the local source is on the left.
  - "A plain rename never replaces" is OpenSSH's behaviour, not the protocol's: never rely on
    it alone. After a timeout libssh2 answers the next request of the same kind with the old
    reply - a failed request must mark the session dead (`NoteTransportError`).
  - The core shows its Copy / Move dialog again when a plug-in's operation fails: a probe
    that answers OK to everything loops.
- 140-sftp-dead-session: **after a timeout libssh2 leaves the request "sent" and answers the
  next request of the same kind with the OLD reply** (`session.h` `BLOCK_ADJUST`, `sftp.c`
  per-request `*_state`; stat / lstat / setstat share one). So a timed-out request ends the
  session: every `CSFTPSession` request returns at once on a dead session without calling the
  library (`NoRequest`), handles of a dead session are not closed through it (a leak until
  exit, never a double free), every loop in `operats.cpp` stops and removes nothing after it,
  one box. **Dead = every negative return code except SFTP_PROTOCOL, BUFFER_TOO_SMALL,
  BAD_USE** (`SftpRcIsDeadTransport`; the first version listed the dead codes and missed the
  raw keepalive / re-key results - review); a code read from `libssh2_session_last_errno` is
  judged by the narrow list of 051 and never EAGAIN (the library leaves EAGAIN there after a
  successful read). `ChangePath` reconnects once instead of returning FALSE - on a refresh
  the core would leave the file system. Special files: `SftpDownloadKind`, a stat following
  links before anything local is created (also `ViewFile`). Refused chmod / chown / mtime:
  counted, one box.
  - Rows DEADCOPY, DEADDEL, DEADMOVE (seam `TC_SFTP_PROBE_TIMEOUT_AT="<path suffix>"`, debug),
    SPZERO, SPFIFO. On 0.1.9 a link to `/dev/zero` reached 392 MB while the probe waited.
  - The 133 listing seam does not mark the session dead on purpose (its rows test the
    listing error path).
- 141-mask-name-cut: **`MaskName` cut silently at its buffer** (`lstrcpyn` for a NULL mask,
  `endBuf` otherwise) and its callers gave it `2 * MAX_PATH` (+200): measured on 0.1.9 - Copy
  / Move of a 250-CJK-letter name failed with error 123 (cut inside a letter at byte 719),
  Quick Rename likewise at 519, and a 256-letter name was renamed silently to 173 letters.
  The rule is now `src/common/salmaskname.h` (`SalMaskNameU8`: the whole result or an EMPTY
  buffer + "cut"); the core calls `MaskNameChecked`; `RenameFileInternal`, the Copy / Move
  script builder (two sites + the typed-mask buffer in `BuildScriptMain`) and Edit New File
  refuse instead of cutting; a result over 255 UTF-16 units is "name too long"
  (`SalNameTooLongForFileSystemU8`). `?` and literals consume whole UTF-8 characters (ASCII
  name + ASCII mask byte-identical to before: 12 million differential cases; the plug-in
  service `MaskName` follows). FTP upload autorename: `src/common/salftpautoren.h`
  (`SalFtpWholePrefixLen` steps back at most 3 bytes and only onto a lead byte - code-page
  names must not shrink to nothing as with `SplU8WholePrefixLen`).
  - Probe `specs/141-mask-name-cut/probe/maskname_probe.ps1` (CP250, MV250, CPD250, CP200,
    QR250, QR200, QR256). A one-element array handed to a PowerShell script block arrives as
    a string - `$x[0]` is then its first letter: cast `[string[]]`.
  - Old crash fixed on the way: OpenVMS autorename, `a_123;1` already renamed (`semicol` not
    moved with the text; `memmove` size -1).
- 142-pictview-thumb-unicode: **EXIF.DLL got wide exports** `EXIFReplaceThumbnailW`,
  `EXIFGetInfoW` (appended; the old ones are CP_ACP wrappers over the same code, converted
  with `MB_ERR_INVALID_CHARS` like the CRT's `fopen`). The plug-in looks the wide export up
  first and passes the `SplU8ToWExtAlloc` form - the same form its own read / compare /
  replace use - and falls back to `U8ToDLLPathAlloc` with an older DLL. Before: on a volume
  without 8.3 names a name outside the code page could not be updated at all (OK-only "Disk
  full?" box per file). **The six old ordinals are pinned in `exif.def`** - appending two
  exports made the linker renumber three of them. After FALSE the library sets
  `GetLastError` (`ERROR_INVALID_DATA` = refused file); the new file is created over the
  plug-in's temporary file (`CREATE_ALWAYS`, no delete first - the name stays reserved).
  `ThumbWriteFailed`: Skip / Skip all / Cancel; three separate skip-all flags (`FL_SKIP_ALL`
  replace, `FL_RO_SKIP_ALL` read-only question, `FL_WRITE_SKIP_ALL` write); read-only put
  back after an agreed replace.
  - Rows UNI, UNIXMP in `thumb132_probe.ps1` (`-UniRoot <folder on a volume without short
    names>`; on this machine C: has short names, D: and E: do not).
  - `jpeg-data.c/.h` are ISO-8859-1: edit by bytes.
- 143-diskmap-release-guard: **a Disk Map window is never destroyed inside one of its loops.**
  Measured on 0.1.10 (`probe/result_pre143.txt`): the program's normal exit crashed (access
  violation in freed `CShellMenu`) with the map's context menu or a shell command's window (the
  Delete confirmation runs on the map's thread inside `InvokeCommand`) open, and an installer's
  close with the menu open was NOT declined (a popup menu is no undeclared window) and crashed the
  same way - 118's record "milliseconds" was wrong. Rule `src/common/salloopclose.h` (header-only,
  `TestLoopClose143`): the window counts its loops (menu, own box, shell command;
  `GUI.LoopGuard.h` RAII scopes - the shell scope covers the WHOLE shell menu functions, shell
  extensions may pump messages in an STA call); `WM_CLOSE` first in `WndProc` (before
  `HandleMenuMessage`, which gets every message while a menu is open): inside a loop the close is
  pending, `EndMenu`, `IDCANCEL` to the thread's enabled `#32770` owned by the map (never while a
  shell command runs), closed by a posted `WM_CLOSE` when the last loop ends. File > Exit and Esc go
  the same way (`CloseOrDefer`; review MEDIUM). While inside a loop the map withdraws its 107
  declaration (`SetWindowClosesUnattended(h, FALSE)`), `DiskMapLoopsOpen` counts it and `Release`
  refuses an unattended close; when `KillAll` gives up, `Release` posts `WM_APP_CLOSEABANDONED`
  and the pending close is dropped (review LOW: the map closed by itself after "force? No"). A
  forced unload during a shell command still terminates the map's thread (Debug: leak reports) -
  the force semantics of every release. Probe `probe/release_guard_probe.ps1` (E0-E6, M1-M3,
  U1-U4): 34 / 0, control 27 / 7; 118 rows M1-M4, X1 11 / 0. saltests 21,794 -> 21,829. Review: File > Exit / Esc through `CloseOrDefer` (MEDIUM); the abandon drops only Release's request (`DISKMAP_CLOSE_FROM_RELEASE` in `wParam`; second round).
- 144-archive-key-repointed-drive: **the key choice of 109 compares with the identity the other panel
  read at ITS open.** Measured on 0.1.10: both panels on `T:rc.zip`, the SUBST letter re-pointed
  from A to B between the opens (twins: equal size and time) - the second panel's F3 showed A's
  member and its F4 edit was packed into B (B's member replaced, silently): `SetArchiveCacheKey109`
  read BOTH identities through the names at the second open, and both names named B. Now
  `CFilesWindowAncestor::ZIPArchiveIdentity` is taken from the very handle that gives the archive's
  date and size (`SalFileIdentityFromHandle` + `SalFileIdentityVolumeTraits`, passed to
  `SetArchiveCacheKey109(listedIdentity)`), the other panel's archive is never read by name there
  (also no wait on a dead share); `SalArchiveCacheKeyChoice` unchanged. `ZIPArchiveCacheKeyFailed`:
  a key that could not be built (memory) is never rebuilt from the name (it could equal the other's)
  - uses of the key refuse until the archive is reopened. 109 probe case `resubst-both`. Results:
  109 probe 19 / 0 / 0 (renet driven), 108 30 / 0 and 2 / 0, 112 14 / 0. **Left (review MEDIUM,
  feature 145)**: pending F4 edits are packed back into the file the name names NOW.
- 145-pending-edits-repointed: **a pending edit is packed back only while the archive's name still
  leads where it led at the open.** Measured (control `Debug_x64_pre145`): a panel on `T:\arc.zip`
  with an F4 edit pending, the letter re-pointed to a twin - leaving packed the edit into the twin
  (its member replaced); a refresh did not notice (size and time only). The decision is the FINAL
  PATH, not the file id: archivers update by renaming a new file over the archive (a new id at the
  same place - control `replace-pending` must keep packing). The panel keeps `ZIPArchiveFinalPath`
  from the open's handle (`SalGetFinalPathOfHandleU8Alloc`, split from 107's helper);
  `ArchiveNameLeadsElsewhere(name, h)`: the final paths differ (both known) or 144's volume serial
  differs (another volume at the letter). Used in the refresh's change test (reopen) and in
  `CheckAndPackAndClear` before `PackCompress` (refused like a failed pack: `IDS_UPDATEFAILED` -
  Yes retries, No = Archive Update with *Copy Selected To...*); `RereadZIPArchiveFinalPath` after
  a successful pack (a symlinked archive replaced by a file). 109 probe: op `replace`, per-step
  `Want`, a `PackFailedHook` in `Serve`; cases `resubst-pending`, `replace-pending`,
  `resubst-refresh`, `resubst-back` 4 / 0 (control 1 / 3); whole 109 23 / 0; 108, 112 unchanged.
  Left: archive operations through a re-pointed name (146); false refusals after a server
  re-spelling / DFS failover (one refused pack, recorded).
- 146-archive-ops-repointed: **no archive operation through a name that leads elsewhere than when the
  panel listed it.** Measured: F8 on x.txt through a re-pointed `T:` deleted the twin's x.txt; F4
  through it, then the letter pointed back, put the twin's member into the first archive (review).
  `CFilesWindow::RefuseOperationIfArchiveMoved(parent, name)` - the ACTING panel only, 145's
  `ArchiveNameLeadsElsewhere`; the existing `IDS_ARCHIVEREFRESHEDIT` note (not when edits are
  pending - the refresh shows it) and `WM_USER_REFRESH_DIR`. Checked RIGHT BEFORE the archive is
  touched (after the confirmations): `PackUncompress` / `PackDelFromArc` in `UnpackZIPArchive`,
  both `PackUnpackOneFile` (F3 / F4, as a failed unpack), packing into the target panel's archive
  (`FilesAction`, `fileswna.cpp`), the paste of copied archive items (`salshlib.cpp`). Do not post
  `CM_LEFTREFRESH` / `CM_RIGHTREFRESH` from code - they zero the stop counters. 109 probe ops
  `delete`; cases `resubst-delete`, `resubst-f4back` (controls FAIL); whole 109 25 / 0; 108, 112
  unchanged. Left: paste of items copied before the panel left / reopened; no final path from
  the redirector = only the volume serial.
- 147-plugin-close-boxes: **measured first: with a File Comparator or Checksum box OPEN, a normal
  exit closes cleanly and an installer's close declines** (both defer their close while a box is
  open - `CM_EXIT` / `WM_CLOSE` close the owned dialogs and repeat); probe K1-K3 7 / 0 before and
  after. By reading: Checksum's `WM_DESTROY` waited `INFINITE` without handling messages while a
  worker's `DialogError` (owner = that window, `DialogBoxParam` -> `EnableWindow` = a send to it)
  could block - a deadlock; now the wait handles SENT messages only (`PM_QS_SENDMESSAGE`) and
  closes a box that slipped through, and `SafeReadFile` / `SafeOpenCreateFile` show no box once the
  worker's `Terminate` is set. File Comparator: the fcremote receiver ended at the start of
  `Release` is started again when `Release` returns FALSE without force. 118 probe 58 / 0. Left:
  the comparator's hex view may show a stray box during `WM_DESTROY` (no crash);
  `CFileMapping::Destroy` keeps `FileSize`.
- 148-undelete-numbering: **equal deleted names are numbered past every name the list holds.**
  Measured: two deleted `a.txt` and a deleted `a (1).txt` restored together - "overwrite
  `a (1).txt`?" (Yes lost the third file's content). `src/common/salnumbername.h` (header-only):
  `SalNumberedNameAlloc` (AddNumberSuffix's rule, byte-identical without a collision),
  `SalPickNumberedNames` - per original name the next number whose result is neither a kept name
  nor one chosen before (`SalNameOrderCompareCI`); sorted sets with binary search (the first
  version was quadratic - {All Deleted Files} holds thousands of `Thumbs.db`). Used by
  `CFileList::RenameDuplicateFiles` (fs2.cpp, the restore list) and the FAT listing (`fat.h`, only
  deleted items numbered); the FAT recursion no longer stops at a one-item folder (pre-existing).
  114 probe: image kind `num`, row `num`; 114 33 / 0 / 4, 115 23 / 0 / 2; saltests +13.
- 149-checksum-long-lines: **Checksum Verify takes a list line of any length.** Measured: a line
  whose relative path had 817 bytes stopped the whole Verify ("Cannot finish operation because
  of too long name.", no window). `FILEINFO::fileName` is a malloc'ed `char*` (destructor); the
  loader sizes the name by the line and the path by the folder + name (`ParseDigest`,
  `SalCslBuildPath` fail only for a small buffer); the Focus button refuses a path longer than
  `Focus_Path` instead of cutting it; `SetDispInfoText` shows a name longer than the list view's
  260-character label with a leading ellipsis (it was EMPTY - review). Probe L1; 117 82 / 0.
  Left: the core's `FocusNameInPanel` cuts at `MAX_PATH + 200` (NEXT-WORK 5a).
- 150-focus-name-long-folder: **"show this file in a panel" never cuts the path.** Measured:
  Checksum's Focus of a file in a 589-byte folder - "Error Changing Directory" with the path cut at
  byte 459 (`FocusNameInPanel`: `lstrcpyn` into `MAX_PATH + 200`). Whole `CSalHeapString` copies;
  a name of `SAL_FIND_NAME_U8` or more (no file's name; `NextFocusName`) refused. Review: the same
  in `PostFocusNameInPanel` (the "name is too long" boxes' Focus - static buffers of the panel's
  limits, the message is posted), PictView's `Focus_Path` (MAX_PATH -> 3 x MAX_PATH, refused
  beyond), the Plugins / Shares dialogs. Probe F1; 149, PictView 120 unchanged.
- 151-plugins-dialog-focus-path: **the Plugins dialog's Focus builds the plug-in's path whole in
  UTF-8** (`GetModuleFileNameU8`, `CSalHeapString FocusPlugin`) - it was `GetModuleFileName` A +
  an unbounded `strcat` into `MAX_PATH`. Regression row P1. The loader's same pattern: NEXT-WORK
  item 19 (the install-path chain).
- 152-pictview-print-preview: **PictView's print preview shows the picture** - empty since 006:
  `CreatePreview` asked `PVSaveImage` for scaled raw rows, which the WIC engine refuses
  (`PVC_UNSUP_OUT_PARAMS`). Drawn now like the print: `PVSetStretchParameters` (signed = mirror) +
  `PVDrawImage` into a DIB, the viewer's stretch given back (`CPrintParams::DisplayStretchX/Y`, and
  the live one again after the dialog). `SelectRect` is in the coordinates of the picture *as
  shown* (mirrored). The cache is keyed on `bSelection` too. **Trap:** the preview control answers
  `WM_PRINTCLIENT` so a probe can capture it - `PrintWindow` of the *dialog* (flags 0) works on the
  hidden desktop, `PrintWindow` of a child control returns FALSE; a viewer check comparing only the
  picture's box passed the negative control (compare the colors' counts). Probe 21/0, control 7
  FAIL. Print-side leftovers: NEXT-WORK 6a.
- 153-archive-member-changed-warning: **the Archive Update dialog marks a file whose member
  another program changed in the archive since the F4** (112's trade-off SF1). The F4 keeps the
  member's listed size/time and the archive file's time/size (`CFileTimeStampsArcStamp`);
  `CFileTimeStamps::MarkChangedInArchive` compares the archive file first and lists it again
  (`PackList`, a temporary directory) only when it changed; rules in `salarcedit.h` (+ saltests).
  New string 12174 (`IDS_ARCUPDATECHANGEDINARC`), eight languages; the list's horizontal extent is
  set now. **Trap:** after a FAILED `ListArchive` the plug-in data must not be released - the
  7zip plug-in deletes them and leaves the pointer set (review CRITICAL, measured: a crash).
  Limit: the same size and time = unchanged. Probe 11/0, the build before 5/6.
- 154-drain-loops-wide: **typed text survives the core's drain loops** (093's leftovers). Nine
  loops that dispatch to windows during an operation take the wide forms (the end of suspend
  mode, the worker's suspension, start-up, `WM_QUERYENDSESSION`, the external archiver's wait,
  registry work, Compare Directories' and ZIP's progress, the viewer thread). Measured: Cyrillic
  typed into the command line while the suspend-mode drain runs arrived as `???`. **Trap:** a
  probe that posts after a sent activation races the main loop (2 of 4 caught) - hold the
  target thread (SuspendThread) while posting. Menus unchanged (code-page mnemonics against
  code-page texts). Probe 7/0, before 6/1 (7 of 7 runs).
- 155-refusal-texts: **refusals say what is refused** (item 10). Core 12161-12163 (folder copied
  onto itself, moved into itself / a subfolder, pack into itself with "leave it out of the
  selection"), Renamer 1243/1287 (a file / a folder moved onto itself; the Renamer has no copy
  mode - its copy onto itself is a cross-root rename). A folder copied onto itself BY NAME is now
  refused at the folder (it descended and the first file was refused "a file"; an empty folder
  not at all). **Traps:** DeepL's informal register (pins); `translate.merge --module renamer`
  re-lays out 159 controls - keep only the string entries. Probe 10/0, before 3/7.
- 156-drag-image-text: **the selection's "N files" text in languages with accents** (a user report
  for 0.1.9: the drag image read "vybran? 2 soubory"). `ExpandPluralFilesDirs(..., u8 = TRUE)` in
  `CreateDragImage` (drawn as UTF-8 since 043) and in the Copy/Delete-from-archive and Pack subjects
  (`LoadStrU8` templates - the mixed string was shown through the code page: "Kop?rovat 5 soubor?
  z archivu do" garbled in the template). **Rule:** a text built by `ExpandPlural*` takes the
  encoding of its sink. Probe 10/0 (Czech UI), before 8/2; the drag image is a person step.
- 157-ftp-infoline-plural: **the plug-in API `ExpandPluralBytesFilesDirs` returns UTF-8** (contract
  in `specs/157-*/contracts/`; interface 107 unchanged): the FTP client's information line read
  "bajt? v 3 vybran?ch souborech" (a code-page template around UTF-8 numbers, drawn as UTF-8).
  By reading (the information line exposes no text); a person step.
- 158-case-sensitive-overwrite: **a case-sensitive folder offers the overwrite of another file**
  (item 11): Quick Rename / F6 `a.txt` -> existing `A.txt` (another file) asks to overwrite instead
  of "(183) already exists" - only when `SalFileIdMatch` proves two files (`provenOther`, also for
  the 8.3-name clean-up); 092's case-only exclusion stays otherwise. A decision recorded. Probe
  10/0, before 7/3.
- 159-portables-infoline: **the Portables information line at the device level as UTF-8**
  (`SplLoadStrU8`; it was code page - "vybran? za?izen?"). By reading; a person step.
- 160-drop-into-long-archive: **drop / paste into an archive of a 260+ byte name** (item 12):
  `CTmpDragDropOperData::ArchiveOrFSName` on the heap; the packer is asked before an empty archive
  is deleted and recreated (review). The clipboard copy FROM such an archive needs the shell
  extension - not shipped, unreachable (its copy hook is code page and cuts at `MAX_PATH`).
  By reading (no OLE drag or clipboard on the hidden desktop); a person step.
- 161-portables-plural: **Portables "N selected devices" takes its plural** (upstream): the
  pattern `{2:s|0||1|s}` named a parameter that does not exist, `ExpandPluralString` stopped at
  the brace; a pattern per language pinned in `ui-overrides.json` (cs "2 vybraná / 5 vybraných
  zařízení"). **Trap:** `{n:...}` is 1-based and a group without an index takes the NEXT
  parameter. Checked with a port of the expander (`probe/plural161.py`).
- 162-ftp-long-typed-path: **a typed FTP path is never cut at `FTP_MAX_PATH` - measured, no
  change** (item 13). The core hands a plug-in at most 259 bytes of user part
  (`ChangePathToPluginFS`, `ChangeDir` "plugins do not support longer paths",
  `ChangeAndListPathOnFS` `user[MAX_PATH]`; the F5 target field, 121): 242 bytes of path reach the
  server whole, 243 are refused by the core; the plug-in keeps 300 / 609. Find *Look in* has no
  maximum (`CSalPathBuf`). **Trap:** a plug-in's own buffers over `MAX_PATH` are not reachable
  through the core - judge a plug-in cut by the core's cap first (121 had judged by reading).
- 163-identity-leftovers: **a long name no longer stays selected after a dialog** (item 14).
  `SelectFocusedItemAndGetName` cut the temporarily selected name at `MAX_PATH` bytes: a 260+ byte
  UTF-8 name stayed selected after Quick Rename / Change Attributes / Change Case / Pack / Email /
  Convert, and the next Delete with the focus elsewhere asked to delete it (probe 9 / 3 before,
  12 / 0 after). Now `CSalHeapString`; `UnselectItemWithName` on `SalNameEqualOrdinalCI`; Find's
  relative ignore kind on `SalFindIgnoreRelativeMatch` (`salfindignore.h`; the old byte fold
  missed Č/č and merged ĥ/Ĺ); Undelete's view key on the heap. **Trap:** a probe that deletes
  `*.txt` here sends them to the maintainer's Recycle Bin ("Use Recycle Bin For") without a
  question - use another extension and switch the bin off.
- 164-zip-delete-cost: **deleting many members from a large ZIP in n log n** (item 15). Per
  deleted member `DeleteFiles` walked the central directory twice (113's bound
  `SalZipNextMemberOffset`, `UpdateCentrDir` with a memmove): 30,000 / 15,000 took 21.9 s (Debug),
  quadratic. `salzipdelete.h`: a sorted offset index (binary search) and one pass
  `SalZipApplyDeletions` after the loop for the members processed so far; only when the directory
  reads whole, the members ascend strictly and memory suffices - else the old code. After: under
  0.5 s, 100,000 / 50,000 1.0 s. saltests compare it with a byte-level port of `UpdateCentrDir`
  on random directories (a mutation control fails them). **Trap:** the plug-in's entry counts are
  16-bit (165).
- 165-zip-entry-count: **ZIP archives of 65,535+ entries get the right count** (found by 164's
  review). The counts lived only in the end record's 16-bit fields: Pack of 70,000 wrote 4,464,
  Add to 66,000 wrote 464, deletions counted down from 0xFFFF; zip64 end records only for size or
  offset. Now 64-bit counts in `CEOCentrDirRecordEx`, derived when written
  (`salzipcount.h` `SalZipEndRecordCounts`, zip64 from 65,535 on), a changed archive is written
  with its walked record count (repairs archives earlier versions wrote). **Traps:** a
  self-extracting archive keeps 16-bit counts (its stub reads the end record where zip64 records
  would go); the data was intact all along - Python's zipfile walks by size, so a count check
  must read the end records themselves (`probe/zipcount.py`).
- 166-translation-layout: **the translation drift measured; the Markdown Viewer's configuration
  translated** (item 16). The ZIP drift is 063's check box allowance (about 20 lines per
  language). The Markdown dialog 310 (088) was English in all 8 languages - translated, the notes
  that needed three lines in two pinned. `widen` no longer grows past a group box frame.
  **Measured: 711 clipped labels** in the shipped translations (English 0) -
  `probe/layout_check.py`; the merge cannot fix them (no free space). **Traps:** `--dry-run`
  writes nothing - measure drift with a real merge and `git checkout`; the program's dialog font
  is `MS Shell Dlg` (not `2`); a probe must not run while the maintainer's own instance runs.
- 167-binary-cosmetics: **the 076 cosmetics** (item 17): `utils\sqlite.dll` has a version resource
  (`src/vcxproj/sqlite/sqlite.rc`), every Release binary is built with `/guard:cf`
  (`src/Directory.Build.targets`; `fcremote` opts out with `TcNoControlFlowGuard` - no CRT, no load
  config, LNK4266), the dead `SalGetProcessId` (`ZwQueryInformationProcess`) removed. Release
  probes 097, 119, 127, 088 identical to Debug. **Trap:** a project without the CRT gets the CFG
  flag without effect - check `dumpbin /headers /loadconfig`, not the flag alone.
- 168-probe-artefacts: **item 18's probe artefacts explained** - 088 `viewers_probe` N3 counted
  Windows 11's UAC input indicator windows; 093's Find-menu rows broke after the first popup was
  closed by the Find window's start-up (the probe now lets it settle: 6 / 6 clean). **Trap:** a
  posted Esc to any window of the thread ends `CMenuBar`'s loop (`PeekMessage(NULL)`) - a
  hypothesis that the loop survives was wrong; log the popup's thread (0 = already gone).
- 169-change-case-utf8: **Change Case renames accented names correctly** (B-4, 068 F-P5-13).
  `AlterFileName` folded UTF-8 bytes with the code page's tables: Change Case renamed
  "žluťoučký kůň.txt" to "żLUťOUďKý Kůň.TXT" (a valid, different name), "ελληνικα" to
  "ελληνΥΪα", failed with error 123 for others; the panel's name format option showed the same.
  `salaltername.h`: whole characters via `LCMapStringEx` (invariant), only same-length mappings -
  the name keeps its byte length (callers' buffers). saltests: 168,000 ASCII cases equal to the old
  algorithm. **Trap:** `fix_probe_lib`'s `Find-Ctl` finds edits and combo boxes only - a probe
  that sets radio buttons through it sets nothing (look the button up; `BM_CLICK`).
- 170-install-path-unicode: **the program starts from an install folder outside the code page**
  (item 19, the install-path chain). `GetModuleFileName` A gave '?' (a per-user install under a
  user name in another script): the language module did not load - the program did not start -
  and no plug-in would have loaded. `SalLoadLibrary` / `SalGetModuleDirU8` (`salfileio.h`), the
  start, the language dialog, `CLanguage::Init`, the plug-in loader and its folder searches wide;
  the Add plug-in dialog wide. Probe 21 / 0 (before 8 / 4; also the first start after an update:
  20 of 20 plug-ins kept). **Trap:** a copy of the build in a temporary folder shares the registry
  key - `Plugins.ver Version (x64)` = 0 forces the first-start processing for a test.
- 171-install-path-rest: **toolbar icons, conversion tables and sqlite.dll from such a folder**
  (after 170): `svg.cpp` (the toolbar fell back to the old bitmaps - seen in a picture),
  `codetbl.cpp` (no conversion table), `shiconov.cpp` (`sqlite.dll` for the Google Drive folder)
  by UTF-8 paths, wide. **Trap:** `PreloadAllConversions` enters a critical section that
  `FreePreloadedConversions` leaves - an early return there is still paired.
- 172-core-save-dialogs: **the core's file dialogs are wide** - the export of the configuration
  (a Cyrillic name failed as `??????.reg`), the viewer's Copy to File (refused EVERY accented name,
  Czech too, with 123: the A dialog returns code-page bytes, the consumers are UTF-8) and Open
  File, `BrowseCommand` / `BrowseDirCommand` of the configuration's *Browse...*. Probe 16/10 ->
  26/0. **Traps:** the Vista dialog's name field is `Edit` 1001 in a `ComboBox` (not 1148) - a
  probe that does not find it may click Save into the user's folder (it wrote
  `%APPDATA%\Tandem Commander\config_.reg` once); `BrowseCommand`'s fields keep `MAX_PATH` bytes -
  a longer name is refused. Left (NEXT-WORK 5c-5e): the viewer's overwrite deletes before it
  moves, a failed export deletes the old file, the export writes '?' for letters outside the code
  page (reglib reads with A functions).
- 173-viewer-copy-replace: **the viewer's Copy to File replaces in one step** (`SalReplaceWithTempW`,
  rule 105; string 12164 names a temporary file that kept the only copy). **Trap for probes:** on
  Windows 11 NTFS a delete with another `FILE_SHARE_DELETE` handle open is POSIX-immediate - the
  classic "delete pending, the move fails" needs FAT or SMB; measure what delete-then-move loses
  instead (attributes; the creation time survives by NTFS name tunnelling). **Translations:**
  `translate.merge` now also re-lays out ~20 controls per language (166's `widen`) - commit only the
  new entry unless the layout is the subject.
