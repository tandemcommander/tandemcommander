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
  changed it (noted where known); open items are tracked in the backlog
  `backlog/BACKLOG.md` (since 242; entries before it cite the retired
  `specs/NEXT-WORK.md`, kept in git), user-visible changes per version in
  `CHANGELOG.md`.

**Index by area** (feature numbers)

| Area | Features |
|------|----------|
| Build, signing, installer, winget, CI | 002, 050, 072, 077, 080, 091 |
| Backlog and project tooling | 242, 243, 247, 265 |
| Releases and pre-release reviews | 056, 068, 243 |
| Translations (pipeline, policy, pins) | 038, 039, 055; string additions in 084, 101, 106, 123 |
| Rebrand, identity | 046 |
| Encoding: UTF-8 / WTF-8 contracts, names, dialogs, titles | 052, 058, 066, 068, 069, 075, 092, 093, 100, 101, 121, 248, 256, 261, 264, 283, 289, 300 |
| Long paths, buffers | 088, 095, 097, 098, 121, 251, 259, 270, 274, 276, 280, 286, 291, 293, 295, 298, 299, 301, 304, 305, 311, 315 |
| Data-loss guards (same file, links, safe replace, pack over source) | 098, 099, 103, 105, 106, 107, 119, 249, 253, 263, 268, 272, 281, 292, 294, 296, 297 |
| Archives in the core, disk cache, external archivers | 084, 095, 096, 097, 108, 109, 112, 144, 252, 260, 273, 275, 306, 308, 309, 310, 316, 317, 318, 319, 321, 325, 326, 327, 328, 329, 330 |
| ZIP plug-in | 086, 094, 106, 110, 113, 119, 271, 290, 320 |
| 7zip plug-in (engine 26.03, RAR) | 087, 089, 093, 113 |
| Plug-in interface 107/108, closing for an update (Restart Manager) | 080, 088, 118, 121, 245 |
| WebView2 viewers (Markdown, Code) | 081, 085, 262, 314 |
| Privacy and security | 083, 085, 086, 090, 123 |
| FTP / SFTP | 051, 056, 085, 090, 094, 099, 116, 121, 258, 269, 277, 279, 288, 303, 323 |
| PictView | 105, 111, 120, 267 |
| Undelete | 114, 115, 148, 324 |
| File Comparator, Renamer, Database Viewer, Checksum, Disk Map, RegEdit | 102, 104, 117, 118, 121, 143, 147, 254, 257, 266, 278, 287 |
| Crash reporting, antivirus findings | 077, 079 |
| Cloud status icons | 058, 059 |
| User-facing features (Command Shell, panel tabs, new version check, quick search filter, settings import, network drive names, UNC share lists) | 071, 078, 123, 244, 245, 246, 284, 285, 312, 313 |

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
- 174-config-export-unicode: **the configuration export is UTF-16 v5 and never deletes a backup**:
  reglib's system registry (core build) works through the W functions with UTF-8 names and
  `SalRegQueryValueExW8` / `SalRegSetValueExW8` data; the dump is composed in memory and written as
  "Windows Registry Editor Version 5.00" through a temporary file and `SalReplaceWithTempW`; a v5
  import becomes UTF-8. Before: Cyrillic values exported as '?', a Cyrillic key name made the whole
  export fail, a failed export deleted the existing file. **Compatibility:** REGEDIT4 files of older
  versions are code page and keep importing (names via `SalLegacyToU8Alloc`, data via the W8
  helper's code-page tolerance, DBCS scanning only for REGEDIT4).
- 175-replace-in-one-step: **Files > Convert and Quick Rename replace in one step** - Convert
  through a flushed temporary file and `SalReplaceWithTempW` (before: the converted file lost its
  alternate data stream - delete + move made a new file), Quick Rename onto an existing file with
  `MOVEFILE_REPLACE_EXISTING`. **Probe trap:** after a failed Quick Rename the dialog opens again
  - a probe that answers it retries the rename.
- 176-pack-overwrite-safe: **Pack with "Overwrite" keeps the old archive until the new one
  exists** - the archive is moved aside (`arcXXXX.tmp` in its folder), deleted after a successful
  pack, put back after a failed or cancelled one (before: deleted first - a failed pack lost it).
  Probe `overwrite_probe.ps1` is 119's probe with its own cases.
- 177-move-over-one-step: **closed by measurement** (no code change) - F6 Move onto an existing file
  deletes the target, then moves; a source held open without `FILE_SHARE_DELETE` fails the first
  move with 32 before that branch (probe `move_over_probe.ps1`: the target kept). Only a lock that
  appears between the delete and the move loses the target.
- 178-fsoper-descr-long-name: `GetCommonFSOperSourceDescr` keeps a name it is given whole (it was cut
  at `MAX_PATH`, possibly inside a letter - the FTP upload's caption); not driven (no FTP server).
- 179-pictview-print-fit: PictView's print mirrors by a stored negative size only with Fit off (the
  preview's rule, 152) and computes the full-image size with `MulDiv` (no 32-bit wrap); not driven.
- 180-errortext-inserts: system error texts with inserts (193, 216, 34) are formatted - every insert
  becomes "..." (`src/common/salfmtinserts.h`: FROM_SYSTEM | ARGUMENT_ARRAY; not IGNORE_INSERTS,
  which leaves a '%'); before: "System error 193, text description is not available.". Use the header
  for any new FormatMessage of a system error.
- 181-shortcut-long-folder: a `.lnk` in a folder of more than MAX_PATH bytes / characters opens
  (Enter, Focus Shortcut Target) - `SalShellLinkLoadNameAlloc` (`salshelllink.h`): the Load name on
  the heap, `\\?\` from MAX_PATH characters on.
- 182-shortcut-error-long-name: Focus Shortcut Target on a broken `.lnk` with a long name crashed
  ("Stack memory corruption": `sprintf` into `char[MAX_PATH + 300]`) - the text on the heap. Its
  review's sweep found more of the class (NEXT-WORK 5j, feature 183).
- 183-message-overruns: seven message texts with a name or path composed on the heap (ViewFile /
  EditFile, Email files, Make file list, force close, reinstall, a DOS packer) and the unpack
  dialog offered only a target that fits (measured: a Debug assertion at F5 from an archive with
  the other panel 1,062 bytes deep).
- 184-pack-unpack-name-cuts: `PackListName` (`pack1.cpp`) - a name for an external archiver's list
  file whole or refused (`IDS_PACKERR_PATH`); the `CharToOem` fallback was unbounded and could
  outgrow the UTF-8 name; a drop-unpack target over MAX_PATH refused. Not driven.
- 185-truncate-tail-trim: nine cut message texts end at a whole letter; an environment variable
  name of MAX_PATH bytes or more is not looked up cut; a message box's URL goes to the clipboard
  whole, as UTF-8. Not driven.
- 186-archiver-message-inserts: the external archivers' "command line too long" passes the whole
  command line (two routes `strcpy`-ed up to 1,040 bytes into `char[1000]`); "path too long" shows
  the UTF-8 path. Not driven.
- 187-share-name-too-long: `SalGetFullName` says "too long" (`IDS_TOOLONGPATH`) for a UNC server or
  share part over MAX_PATH - it said "a share / server name is missing" and offered the share list.
- 188-cloud-folder-detect: Dropbox and Google Drive detection read the shell folders as UTF-8
  (`SalGetFolderPathU8`) - the code-page `SHGetFolderPath` A failed `FileExists` under an account name
  with diacritics. Not driven.
- 189-regedt-multisz-end: Registry Editor - a `REG_MULTI_SZ` is one line whatever the number of NULs
  at its end (`salmultisz.h`, panel and Find); the Find window's copy of a text value is always
  terminated (it read past it: debug-heap fence bytes in the Data cell); its regexp search trims
  the NULs at the end, not a fixed 2 / 4 bytes. Windows adds a NUL when it reads back a text stored
  without one. Probe `multisz_probe.ps1` 3 / 4 -> 6 / 0 (+ RX, blocked by 190).
- 190-regedt-find-number: Registry Editor Find - `useNumber` / `number` set in regexp and hex mode
  (passed uninitialized to the search thread: a Debug run-time check box stopped the search).
  Refuted: a sign extension in the big-endian compare (plug-ins build with `/J`). Probe
  `find_number_probe.ps1` 3 / 3 -> 6 / 0; the 189 probe 8 / 0; negative control of 189's trim.
- 191-regedt-find-input: Registry Editor Find - the time fields' `char[20]` read with `MAX_KEYNAME`
  (stack overrun), a quoted hex pattern unbounded into `patternA[512]` (fatal memcpy overlap), a
  code-page pattern over 512 bytes (length -1 to memcpy) - all refused in `Validate` with a message
  (`IDS_LONGDATA` / the bad time format), `ConvertHexToString` takes its buffer size. `Error()`
  appends `GetLastError()`'s text - clear it first. Probe `find_input_probe.ps1` 3 / 1 (+ 0 / 2)
  -> 5 / 0.
- 192-regedt-find-numbers: Registry Editor Find - "0x" before a hex number (the help promised it),
  `HexStringToNumber` refuses a 17th digit (`ret >> 60`; the /10 test dropped the top digit),
  numbers compared only at their exact size; the Find item and the panel listing read a DWORD /
  QWORD only from a value that has its bytes (a `malloc(0)` buffer when all values are empty).
  Probe `find_numbers_probe.ps1` 2 / 3 -> 5 / 0.
- 193-unc-job-exit: the share list's job of a worker ended at exit (`TerminateAuxThreads`) is freed
  (`CUncSharesJob::FreeAbandoned`, a list under an `SRWLOCK`; not a job ended inside `realloc`); the
  Debug call-stack monitor queue is a `_CRT_BLOCK`. **Trap:** since Vista `TerminateThread` frees
  the thread's stack - its `CCallStack` lives there; every thread ended so (icon reader, CheckPath,
  cache handles, plug-in threads) leaves a `CallStacks` entry into freed memory: never read through
  that list's entries. Debug seam `TC_PROBE_UNC_CANCEL`; leak dumps read with `dbwin_lib.ps1`.
  Probe `unc_abandon_probe.ps1` 1 / 1 -> 2 / 0.
- 194-drop-shortcut-target: the drop target (`shellsup.cpp` `GetCurrentDir`) reads a shortcut with
  `SalShellLinkLoadNameAlloc` / `SalShellLinkGetPathU8` into a heap buffer (was `MAX_PATH` both
  ways; a long UTF-8 name went to a cut code-page fallback). Not driven (OLE drag = real mouse).
- 195-case-sensitive-copy: F5 Copy `a.txt` -> `A.txt` (or a folder) within a case-sensitive folder is
  a copy to another name (`fileswn6.cpp` `CopyTargetIsAnotherName`): a target that does not exist,
  or - in a folder whose `FileCaseSensitiveInfo` says so - one the identity read THROUGH links
  proves another file. Different ids alone prove nothing (path-derived ids on some mounts).
  Probe `cs_copy_probe.ps1` 7 / 3 -> 12 / 0.
- 196-renamer-case-sensitive: the Renamer overwrites an existing `A.txt` when renaming `a.txt` in a
  case-sensitive folder, proven another file ONLY by the temporary-name route (different ids and
  metadata are no proof before a delete: path-derived ids); the name rule `SalNameOrderEqualCI`
  instead of the code-page `StrICmp`. Probe `ren_cs_probe.ps1` 6 / 2 -> 8 / 0.
- 197-deep-junction-delete: **data loss** - F8 (no Recycle Bin) of a junction in a folder of 780+
  characters, or of a folder holding one, deleted the TARGET's files: the delete script took a
  reparse directory for a link only when `GetReparsePointDestination` succeeded, and it failed past
  `WCHAR[3 * MAX_PATH]`. Now any length, and `DeleteAsDirLink` fails closed (tag unreadable or a
  name surrogate = a link). **Rule: a destructive recursion never descends into a reparse
  directory it could not prove a plain one.** Probe `deepjunc_probe.ps1` 9 / 3 -> 12 / 0.
- 198-rename-proof-temp-name: Quick Rename and the worker's move prove an existing target "another
  file" for two spellings of one name ONLY by the temporary-name route (158 took different ids -
  no proof on path-derived-id mounts). Not driven (no such mount); 158's probe 10 / 0, 103's 46 / 0.
- 199-renamer-short-name: **data loss** - the Renamer renaming to another file's short (8.3) name
  ("LONGFI~1.TXT") asked "overwrite?" and deleted "longfilename.txt"; now the clash is moved aside
  for the rename and back (`TargetIsOnlyShortNameOfOther`, as the core's Quick Rename); such a name
  never reaches the delete branch (a failed move aside - the file held open - is a rename error).
  Probe `ren_83_probe.ps1` 3 / 1 -> 6 / 0.
- 200-pictview-rename-case: PictView's Rename of the shown image - the 092 name rule instead of the
  code-page `StrICmp`, and for two spellings of one name an overwrite only when the temporary-name
  route proves another file (as 196 / 198). Probe `pv_cs_probe.ps1` 4 / 1 -> 5 / 0.
- 201-short-name-clash-held: Quick Rename and F6 to another entry's short (8.3) name - when moving
  that entry aside fails (held open), never the overwrite question for it (Yes replaced the other
  file; F6's Retry after the other program let go would have); the move's error instead.
  Probe `short_clash_probe.ps1`.
- 202-pictview-short-name: PictView's Rename of the shown image to another file's short (8.3) name
  asked "overwrite?" and Yes replaced that file; now it is moved aside for the rename and back
  (`PvTargetIsOnlyShortNameOfOther` / `PvMoveAsideShortNameClash`, as the Renamer, 199); a failed
  move aside, or a folder where it cannot be told whose name it is, is the rename's error.
  Probe `pv_83_probe.ps1` 6 / 3 -> 9 / 0.
- 203-create-short-name-clash: the create paths' 8.3 clash - when moving the other entry aside
  fails (held open), `SalCreateFileEx` / `SalCreateDirectoryEx` report that error, never "it
  exists" (F5 asked to overwrite the other file; a copied folder was merged into the other folder),
  and `SafeFileCreate` (archive plug-ins) shows the create error instead of the overwrite question
  (Yes replaced the other file's content), at any path length (`salshortname.h`). FTP / SFTP
  downloads are not covered (205). Probe `create_clash_probe.ps1`.
- 204-unpack-short-name-folder: an archive member's folder that is only another folder's short
  (8.3) name went INTO that folder (and a same-named file there was replaced after a question
  under the member's path). During a plug-in's unpack the core knows its target
  (`CUnpackRootScope`); below it `MakeUnpackFoldersOwn` (from `CheckAndCreateDirectory` and
  `SafeFileCreate`) makes such a component a folder of its own (203's move aside); components that
  cannot be 8.3 are never looked up; the typed target keeps resolving. Probe
  `unpack_dir_probe.ps1` 6 / 4 -> 22 / 0 (ZIP, TAR, 7-Zip, Alt+F9, a drive root).
- 205-download-short-name-clash: FTP / SFTP downloads to a local name that is only another
  entry's short (8.3) name - SFTP replaced the other file and downloaded into the other folder,
  FTP's re-check turned the core's error back into "exists" (join / overwrite / resume). Now
  `SplPathIsOnlyShortNameOfOther` (`splshortname.h`, proven only); SFTP creates through the core's
  `SalCreateFileEx` / `SalCreateDirectoryEx` (203's move aside), FTP never sets `alreadyExists`
  for such a name (its automatic rename still numbers it). Probe `sftp205_probe.ps1` 4 / 4 ->
  14 / 0; FTP not driven.
- 206-renamer-short-name-folder: the Renamer's folder step (`CheckAndCreateDirectory`) - the
  backlog's "renames the other folder to its short name" is a no-op on NTFS (measured), but the
  step copied the found long name into `char old[MAX_PATH]` (a 230-letter folder: a stack
  overrun) and, in the relative-path mode, `LONGDI~1\x.txt` went into `longdirname` and offered
  `longdirname\x.txt` for overwriting (Yes replaced it). The case is adjusted only for the folder's
  own name (`SalNameOrderEqualCI`), `old` on the heap; a folder proven another's short name is
  created of its own (`SalCreateDirectoryEx`; `BuildScript` does not take the target for existing)
  - relative-path mode only (a full path is the user's own). Probe `ren_dir83_probe.ps1` -> 10 / 0.
- 207-renamer-long-source-path: the Renamer copied a path into `char dir[MAX_PATH]` on Undo
  (`MoveFile`, the source's original name) and with "Remove source path" - a selected item of 90 CJK
  letters (274 bytes, an ordinary path) failed "Buffer is too small"; heap copies now. Its review
  found worse: in a panel folder of 260+ bytes `GetPanelPath` failed unchecked, `Root` stayed empty
  and the items became `\name` in the root of the current drive - Batch Rename is refused there
  before its dialog. Probe `ren_long_probe.ps1` -> 8 / 0.
- 208-renamer-case-utf8: the Renamer's `ChangeCase` applied code-page byte tables to UTF-8 names and
  stripped diacritics through `CP_ACP` - lower / mixed / stripdia of a Czech name and upper of a CJK
  one were refused "(123)", upper changed only ASCII. Now on UTF-16 (`CharLowerBuffW`,
  `CharUpperBuffW`, `NormalizeString`), returning the new UTF-8 length (callers updated); the
  script's comparators by `SalNameOrderCompareCI`. Probe `ren_case_probe.ps1` 5 / 5 -> 12 / 0.
- 209-renamer-subdir-reload: the Renamer's `ReloadSourceFiles` expanded a folder item as `Root +
  Name` - a renamed folder lies elsewhere: after a full-path run (`Root` emptied) "name\*.*" was
  read relative to the current folder, after `x` -> `sub\x` the folder `Root\x`. Now from the
  parent of the item's full name. Probe `ren_subdir_probe.ps1` -> 8 / 0.
- 210-renamer-utf8-search: the Renamer's case-insensitive search folded UTF-8 BYTES through the
  code page (cp1250: 8A / 9A - "E-caron" replaced in "C-dot x.txt": a wrong name written, both the
  core's Boyer-Moore and the plug-in's regex); now a same-length fold by characters
  (`salu8fold.h`) over a copy, the engines case-sensitive / ASCII-only; whole words and the cut
  arguments by characters; the "nothing to do" shortcut only for identical bytes. Probe
  `ren_search_probe.ps1` 7 / 5 -> 16 / 0.
- 211-diskmap-long-name: Disk Map built an item's full name into 781 bytes and SKIPPED a part that
  did not fit - a file of a long name in a deep folder got its folder's path, and the shell menu's
  Delete offered the FOLDER for permanent deletion (measured). Now no name at all when a part does
  not fit (`GetNameAux`); the menu, the default command and Focus refuse (a beep); the shell gets
  `SplU8ToW` (WTF-8), never `CP_ACP`. Probe `diskmap_long_probe.ps1`; 143 34 / 0.
- 212-temp-dir-links: `RemoveTemporaryDir` / `RemoveEmptyDirs` (`salamdr3.cpp`) walked into every
  subdirectory - a junction or directory symbolic link inside a temporary folder had its TARGET's
  files deleted. A directory link (`DeleteAsDirLink`, 197's fail-closed decision) is now removed as
  a link and never walked, also the folder passed in. By reading only; driving it (the start-up
  `SAL*.tmp` sweep with a junction inside) is owed.
- 214-copy-dialog-text-fits: `CCopyMoveDialog` / `CCopyMoveMoreDialog` limit the field in UTF-16
  units but read UTF-8 into the caller's buffer, cutting what does not fit (also a history entry):
  F5 out of a ZIP to `tgt\A\sub\` (CJK, 263 bytes) unpacked into `tgt\A` (measured). A `Validate`
  measures the whole text and refuses (`IDS_TOOLONGPATH`). Probe `cm_text_probe.ps1` 4 / 0; 204
  22 / 0. The same cut elsewhere (Make File List, user menu, viewers / editors) is in NEXT-WORK.
- 213-attrs-case-links: `BuildScriptDir` walked into a junction for Change Attributes, Change Case
  and recursive Convert with subdirectories - the target's files (outside the selection) got the
  attributes, were renamed, were rewritten (measured, also a selected junction). A directory link
  (`DeleteAsDirLink`, fail closed) is not walked for these; its own entry still changes. Probe
  `attrs_case_link_probe.ps1` 4 FAIL -> 8 / 0. Left: the link's own op reaches the target folder
  for compression / times.
- 215-ftp-long-name-command: the FTP listing cut names over 255 bytes (the limit before interface
  104) and every command went to the cut name (`DELE` / `RNFR <255 bytes>`, measured with a local
  test server `probe/ftpmini.py`). Names up to 765 bytes kept; command buffers `FTP_CMDBUF_SIZE`
  everywhere (the worker passed 501 for 1,001); no cut or empty command; the local disk work never
  works on a cut name (`TooLong` / `NameCut`); VMS folder names, Solve Error, the lock. Probe
  `ftp215_probe.ps1` 3 FAIL -> 12 / 0. Server paths over 300 bytes and the local long-path side are
  NEXT-WORK.
- 216-ftp-ssl-error-text: `ssl.cpp` `EncryptSocket` gave `ERR_error_string` 200 bytes (OpenSSL
  1.0.1c needs 256) and made its log lines unbounded into 256 bytes with `LoadStr` (a near miss,
  not server-reachable; letters lost outside the system code page). `name[256]`, `buffer[1024]`,
  `_snprintf_s`, `LoadStrU8` (also the certificate lines of `ctrlcon1.cpp`). By reading; 215 12 / 0.
- 217-sftp-failed-handshake: the intermittent "Unable to exchange encryption keys" + Debug leak box
  (which also held the exit): libssh2's WinCNG backend hashed a raw (EC)DH secret with a leading
  zero as a non-minimal mpint (~1/256), and `session_free` kept the server's host-key object when
  the exchange failed before NEWKEYS. Reproduced by a proxy flipping a byte of the server's signed
  reply (`probe/fakessh.py` FLIPSIG); local libssh2 patches (trim, dtor, CNG handles). Probe
  `sftp217_probe.ps1` 18 / 0; the teardown's 1 ms deadline (`Disconnect`) is NEXT-WORK.
- 218-callstack-terminated-threads: a thread ended by `TerminateThread` left its `CCallStack` (on its
  freed stack) in `CallStacks`; `CallStk_TerminateThread` suspends it, `ForgetThread` NULLs the
  slots by memory region (`VirtualQuery`; never reading an entry - the first version read other
  entries and was rejected: plug-in threads' are freed too), then terminates; the report skips NULL.
  Five core sites; by reading; smoke 8 / 0, 22 / 0. Plug-in kills (`auxtools.cpp`) are NEXT-WORK.
- 219-deep-link-delete-rows: 197's rows not driven, driven: directory symbolic links in folders of
  41-874 characters and F8 on the deep folder holding one, and the Recycle Bin by masks with
  junctions - only the link removed (PASS on the build before). Found: a link whose target is stored
  as `\\?\C:\...` could not be followed (Go to Shortcut Target "path invalid") -
  `SalReparseNameAsPath` (salreparse.h, saltests) makes the long / NT form a path (not a name with a
  trailing dot / space component). Probe `deeplink219_probe.ps1` 17 / 1 -> 20 / 0.
- 220-sftp-leftovers: SFTP F3 on a file of mode 000 showed nothing - `ViewFile` says every failure
  (as the download); `Disconnect` gave a dead session 1 ms and the channel's close timed out - the
  whole session leaked (a stalled server through `probe/fakessh.py` `stallT`): a failed teardown step
  is repeated after `shutdown(SD_BOTH)`. Probes 6 / 0, 4 / 0. Left (libssh2): a partly sent packet,
  open handles of a dead session, a server's DISCONNECT.
- 221-moved-aside-restore: an entry moved aside to `salNNN` for an 8.3 clash stayed there with only a
  trace when the move back failed. `SalMoveFileBack` (retried ~1 s) on every move-back; Quick Rename
  and the worker's move say where it stays (existing strings). By reading; 201 6 / 0, 203 14 / 0.
  The create paths (no window) still only trace - NEXT-WORK.
- 222-name-length-units: a ZIP with a member of 274 bytes (90 CJK letters - a valid name) could not
  be opened: `CSalamanderDirectory::AddFile` and `SalIsValidFileNameComponent` limited a name to 255
  BYTES. Now 255 UTF-16 units for files (folders keep 255 bytes - their contents' path part is
  limited; the review's MUST: else partial listings), `SalNamePrefixBytesU8`, whole-character cuts,
  the ZIP listing skips a too-long item, uniso's path buffers widened. Contract note. Probe
  `editname222_probe.ps1` 5 / 3 -> 10 / 0.
- 223-uniso-crafted-image: the ISO plug-in used lengths from the image unchecked (an HFS+ name into
  `wchar_t[256]`, Rock Ridge entry lengths, directory records); checked now. Rock Ridge names in a
  continuation area (CE) are followed - a 200-letter name was extracted as 146 letters (measured with
  a `genisoimage -R` image); never a cut name. Probe `iso223_probe.ps1` 4 / 0. HFS+ B-tree loader:
  NEXT-WORK.
- 224-ftp-utf8-server-names: `FTPU8NameToServer` sent any non-ASCII name the code page could hold in
  the code page - on a UTF-8 server `DELE caf\xE9.txt` (550; every Czech name out of reach). Now the
  code page only for texts a listing / PWD gave in it (a process-wide set; whole names, components,
  leading parts); else UTF-8 - a policy: new names go in UTF-8 to legacy servers too. Probe
  `ftp224_probe.ps1` (ftpmini in utf-8 / cp1250) 3 FAIL -> 16 / 0. Per-server flag: NEXT-WORK.
- 225-user-menu-long-names: the User Menu's enumeration cut a panel path of 260+ bytes; for the
  up-dir item / an empty panel (no name - `ExpandCommand2` refuses only path + name) the command ran
  in the cut folder. Refused now ("name too long"). A first, wider version was rejected by the review
  (it changed nothing else and ran a partial .bat). By reading. The .bat's `CharToOem` of UTF-8 text:
  NEXT-WORK.
- 226-user-menu-batch-encoding: the User Menu's "through a shell" batch file converted its UTF-8
  command line and folder with `CharToOem` (ANSI in) - every non-ASCII name garbled; its current
  folder was set with the A `SetCurrentDirectory` (failed for such folders - System32). Now the
  text is collected (`salbatchtext.h`, saltests): ASCII as before; exact OEM form -> a chcp line +
  OEM bytes; else UTF-8 between chcp 65001 and back; an unpaired surrogate refused. **chcp.com by
  its absolute path** (review: a bare `chcp` ran a planted chcp.bat - control confirmed); `cd /d
  ... || exit /b 1` (a missing Initial Directory ran the command in the panel's folder);
  `SalSetCurrentDirectoryU8`. Probe `um226_probe.ps1` 11 FAIL -> 28 / 0. Trap: a shell with
  `NoDefaultCurrentDirectoryInExePath` set hides the planted-file case - the probe removes it.
- 227-compare-dirs-long-names: measured, no defect - Compare Directories cuts a 260+ byte subfolder
  name, but the panel path + the cut name never fits its MAX_PATH paths: refused "too long name"
  (probe `cmp227_probe.ps1`). The Find window's `CompareName1/2` likewise end empty. No code change.
- 228-dragdrop-archive-long-source: `DragDropToArcOrFS` (drag & drop / paste into an archive or a
  plug-in FS) listed the source folder cut at 259 bytes - an error, or an ancestor / a sibling with
  the same start whose items' flags were taken (the 099 link check could pass a junction on a Move).
  Whole path now (`CSalMaxPathBuffer`, heap messages). By reading (needs drag & drop or the
  clipboard). Review found the case-sensitive duplicate overrun: NEXT-WORK.
- 229-user-menu-batch-special-chars: values the User Menu inserted into its batch file (`call`
  lines) went raw - '%' expanded twice ("a%OS%b.txt" -> another existing file), quoted '^' doubled,
  unquoted '&' ran another command, lists split at ','. Batch mode in `DoExpandVarString`
  (`salbatchtext.h`, saltests): inserted values only - '%' x4 (x2 on the `cd` line, a second
  `ExpandInitDir`), '^' / unquoted `&|<>` refused (quote state incl. quotes inside the value),
  `AddToListOfNames` quotes delimiters, cmd `/V:OFF`. Probe `um229_probe.ps1` (decoys) 14 FAIL -> 34 /
  0. Trap: a command-line path has %VAR% expanded - probes enter such folders from the parent.
- 230-dragdrop-case-sensitive-names: `DragDropToArcOrFS` added a second case-insensitive match as a
  "duplicate" - in a case-sensitive folder an unselected A.txt packed (Move: deleted) beside a.txt,
  `nameFound` overrun. Byte-equal first (`salnamerun.h`, saltests); a case-insensitive-only item only
  as the unique fallback in a folder that is not case-sensitive (`SalDirIsCaseSensitive`, from 195) -
  review: sources may give another case. By reading (drag & drop / clipboard).
- 231-case-sensitive-reselect: `IsCaseSensitive()` was FALSE for disk panels - Reselect, Restore
  Selection, tabs, Hide Selected Names took a.txt and A.txt of a case-sensitive folder for one. Now
  `DiskDirCaseSensitive` (set per disk listing, `SalDirIsCaseSensitive`); Restore Selection compares
  by the panel's rule. Probe `resel231_probe.ps1` 3 FAIL -> 8 / 0. Review found 004's
  `CmpNameExtIgnCase` tie-break (Compare Directories): NEXT-WORK.
- 232-compare-dirs-case-only-names: 004's NFC/NFD tie-break in `CmpNameExtIgnCase` made case-only
  pairs unequal - Compare Directories marked Readme.txt / README.txt different everywhere, a refresh
  lost the selection after a case-only rename. Tie-break now `SalNameCompareOrdinalCI` (equality =
  the same name; NFC/NFD stay apart), result -1/0/1; the refresh merge moves flags to another case
  only without an exact old twin. Probe `cmp232_probe.ps1` 4 FAIL -> 16 / 0.
- 233-ftp-long-server-paths: measured, no defect of the audit's kind - a typed / entered FTP path of
  ~260+ bytes is refused by the core, the queue refuses sub-paths over 300 bytes (`FTPPathAppend`);
  only a PWD reply over 300 bytes is cut (an ancestor under its own name). Probe `ftp233_probe.ps1`.
  ("A tree download left nothing on disk" was withdrawn: the probe's control row shows the same -
  a probe defect.)
- 234-user-menu-item-folder: a User Menu command without an Initial Directory used the process-wide
  current folder - the Find route set none (System32, or a panel's folder set by another thread).
  Now the item's folder: `lpDirectory` (direct), cmd's start folder + a `cd /d` line per item folder
  change (batch), a differing UNC item folder refused. Find route NOT DRIVEN (a popup menu); panel
  route + 226 / 229 probes green. Two reviews (MUSTs: several folders, UNC).
- 235-find-list-of-names-folders: `$(ListOfSelectedNames)` from Find results in several folders ran
  once in the first folder with bare names - other files there. Now the full names (no fitting
  message for a refusal; decision in the fix-log); help updated. By reading.
- 236-menu-hotkeys-utf8: `AssignHotKeys` could put '&' inside a UTF-8 letter (a code-page "letter"
  byte); now ASCII letters only (`salmenuhotkey.h`, saltests); "&&" is a literal '&'. Note: the core
  builds with /J - `UpperCase[char]` never indexes negatively.
- 237-popup-menu-mnemonics: popups compared the typed ANSI byte with the byte after '&' (UTF-8 items'
  accented mnemonics never matched; C4 of "&Č" matched "ä"). Now characters: `SalMenuKeyMatch`
  (`SalMnemonicMatchW`, as the menu bar since 093). Limits: a DBCS / 65001 key byte matches nothing
  (a wide popup loop owed); `WM_MENUCHAR` passes no character (upstream) - NEXT-WORK.
- 238-literal-percent-paths: a command-line / typed path always had %VAR% expanded - "p%OS%q" opened
  "pWindows_NTq". Now the part up to the last '%' component existing as written wins (`salpctpath.h`,
  saltests); not checked: network paths (stall), a relative path starting with a defined variable
  (stray "%APPDATA%" folders). Probe `pct238_probe.ps1` 4 FAIL -> 14 / 0. Two reviews.
- 239-check-encoding-plugins: `check_encoding.py --plugins` - a report-only scan of `src/plugins`
  (never fails; third-party code skipped): 78 findings (424 draft), the list in the feature folder.
- 240-dragdrop-long-folder-name: a dragged / pasted folder of 255+ bytes (AddDir's limit, 222) ended
  `DragDropToArcOrFS` silently; now "too long name". By reading. Nested / F5: 241.
- 241-pack-long-nested-folder: `ReadDirectoryTree` ended with `SALENUM_ERROR` and no message when
  `AddDir` refused a 255+ byte folder name - F5 / F6 into a ZIP "succeeded" packing nothing. Now
  "too long name" + `SALENUM_CANCEL` (nested and selected); the custom packer gets a parent window.
  Probe `pack241_probe.ps1` 2 FAIL -> 8 / 0.

- 242-backlog-system: planned work moved out of `specs/` into `backlog/` - `BACKLOG.md` (row order =
  priority; sections In progress / Next / Decisions / Person steps / Inbox / Parked / Rejected; a
  legend that is the vocabulary), one folder per item `items/<slug>/desc.md` (15-key header + fixed
  sections), `RUNS.md`, `RELEASE.md`. `tools/backlog/backlog.py` (stdlib only) owns every change and
  the check (18 rules); skills `/tandem-backlog` (management; agents only add to Inbox) and
  `/tandem-backlog-implement` (one item through the whole Spec Kit flow; lock in `.git`, measure
  first, stop rules, fast-forward of local `main`, never pushes). `specs/NEXT-WORK.md` deleted, the
  five REMAINING-WORK files kept with a note; 128 items migrated by 7 agents with a 696-row ledger
  (`specs/242-backlog-system/migration-ledger.md`). Traps: a circular `see` between two migration
  parts lost the 072 audit (found at consolidation); the release gate of 0.1.10 and 10 Code Viewer
  person rows were lost until the review; after a stopped run the branch number (counts branches) and
  specify's folder number (counts `specs/` only) differ - the run passes `SPECIFY_FEATURE_DIRECTORY`;
  item text on a command line runs as shell code (backticks) - never on a command line; the Bash tool
  collapses a doubled backslash even in single quotes; `sync` dropped hand-written rows (fixed). Tests 58, mutation
  check `probe/mutate.py` 31 / 32 (the survivor equivalent); three refute-first reviews.
  - Extended 2026-10-17: `import-github --label 'ai backlog' [--dry-run]` imports every open issue
    with the maintainer's label not held yet; skips pull requests, `fixed` / `duplicate` / `invalid` /
    `wontfix`, and an issue whose `source: github#N` is in the git history of `backlog/items` (its
    item was removed - a removed item leaves no other record). Type from labels, `labels:` line in
    `issue.md`; the skill judges severity from the text (reference.md §3 *GitHub labels*). Tests 68;
    a refute-first review: `http.client` errors escaped as a traceback, `--dry-run` did not validate
    the area, a title with no ASCII slug had no recovery, history matched `issue.md` text (fixed).
- 243-tandem-release-skill: `/tandem-release <x.y.z>` prepares the tree so that the version is released
  the same day; `tools/release/release.py` (stdlib) owns the mechanics - `status` (state derived from
  local + remote tags, the source and the changelog; refusals: released tag, lower version, MAJOR.MINORA
  change, dirty tree, backlog lock, detached HEAD, passed copyright year), `stamp` (the eight *Release
  records* of `backlog/RELEASE.md`: version/build = previous tag's build + 1, changelog fold of every
  unreleased section into `## [x.y.z] - date`, PRIVACY chain shift, product lines, release notes skeleton;
  BOM/EOL kept, idempotent), `check` (24 rules) and `summary` (exact replica of `publish.ps1`'s winget
  summary, matches the recorded 0.1.9 manifest). The skill asks when not on `main`, for open gating person
  steps and an open release decision, reviews the delta, writes the lead `**Build N.** <Kind> release.`,
  the privacy sentence, the notes, *Status* / *Current release*, and commits once; never builds, tests,
  tags or publishes. Constitution 3.2.0 (changelog groups optional, lead required, one record list).
  Traps: a first paragraph is a lead only when it starts with `**Build ` - prose entries (0.1.9's form)
  were dropped by the first fold (review); the release notes, *Status* and *Current release* must be
  rewritten on every run (a re-run on another day folds new work in; `check` catches stale dates and
  ranges, not stale content); a newer tag only on the remote must be seen (build numbers would repeat);
  the question tool offers at most four options. Tests 44; refute-first review: 9 findings, all fixed.
- 244-quick-search-substring-filter: **quick search finds text anywhere in a name and shows only the
  matches** (option *Configuration > Panels*, on by default - a documented exception to Constitution
  II; cleared = the 0.1.10 quick search, probe-identical). While a search runs, `Dirs`/`Files` are
  non-owning *visible arrays* (whole-struct copies of the matches); the full listing waits in
  `QFFullDirs`/`QFFullFiles` with visible->full maps, and every per-copy state is written back
  whole. So commands, selection commands and plug-ins act only on what is shown, and hidden items
  keep their selection. Lifetime inverted: `CancelUI`, focus loss, menus, dialogs, scrolling and
  clicks keep the search; it ends at Esc, empty text, a path change (before `RefreshPathHistoryData`),
  a tab switch, the other panel, a refresh that leaves no match or focuses a non-matching item, the
  option switched off, and close. `RefreshDirectory` suspends and resumes; `ChangeSortType` sorts the
  full listing. Pure rules in `src/common/salquickfilter.h`: prefix as 0.1.10 (901 saltests cases),
  substring and the new mode's prefix on **keys** (NFD + invariant lower case, byte offsets per
  unit, built once per search). The searching panel is tinted (`SalQFTint`: a share of the caption
  colour kept apart from the cursor, selection and full-row backgrounds; per-panel brush; icons
  through the non-virtual `CIconList::DrawOnBk`); the directory line shows `Search: <text> (<n> of
  <total>)`. Traps:
  - `FillIntersectionRegion` took the brush argument but still filled with `HNormalBkBrush`
    (untinted icon cells, found by the capture probe).
  - Waking the icon reader that the caller had put to sleep crashed the close path (freed names);
    wake only if it ran.
  - A per-position `SalNameEqualCI` cost seconds per keystroke on non-ASCII names (review).
  - A drop from an archive/FS ended the source search before the posted unpack/copy read the
    selection (hidden selected items would be extracted - review).
  - A colour change at start added the system root to the Back history.
  - Sorting the visible arrays would break the maps.
  - Bash here-documents collapsed `\x` escapes in a saltests edit.
  - New mode drops the old comparison's linguistic extras (`ss` = sharp s).
  Tests: saltests 22,737 -> 23,037; probes `specs/244-*/probe/` (functional 45 rows, option off
  identical, captures 5 views x 5 schemes, Configuration page in 9 languages, Release perf 100k:
  <= 32 ms typing, 335 ms first keystroke over 100k non-ASCII names = the list layout, filed); two
  review rounds (four agents).
- 245-settings-import-salamander: **Options > Import Settings from Salamander** - a five-page wizard
  (source, what/how, saved passwords, preview, result) that brings settings of Altap Salamander
  2.5-4.0 / Open Salamander 5.0 into TC; offered once at the first start of a fresh configuration
  (existence check only). Constitution 4.0.0 (principle II: the old keys are never written, read only
  in a user-started import). The source root is read ONCE (`KEY_READ`, wide API, limits 8 levels /
  64 KiB per value / 32 MiB, truncation tracked per key) into a snapshot tree (`CSalCfgKey`); pure
  rules in header-only `src/common/salcfgimport.h` (saltests). Engine `src/cfgimport.cpp`: per group
  plan (lines `+ = ~ - ! x`) -> preview -> consent when anything current is replaced or removed
  (FR-010c) -> guard (other instance, Find/viewer windows) -> backup (`ExportConfiguration` into
  `%APPDATA%\Tandem Commander\Settings backups\before-import-*.reg`, restore with `-C`) -> groups
  all-or-nothing -> `RefreshAfterConfiguration` (factored out of `WM_USER_CONFIGURATION`) ->
  `SaveConfig`. Defaults never change a current setting: list groups *Add*; viewers (rows go before
  the current `*.*` row = a change), option groups, colours, templates and whole-plugin settings are
  unticked. Options come from an allow-list table (mirrored in saltests against the forbidden list);
  an option and its masks/text are one unit. Interface **108**: `SetPluginSettingsImport` +
  `CSalamanderSettingsImportAbstract` (read-only source view, report sink, password services); FTP
  (`ftpimport.cpp`) merges bookmarks, proxies and server types, builds complete copies and swaps them
  in. Passwords: source master password verified by its verifier (code-page bytes, <= 127 bytes);
  never stored weaker without consent; TC's own master password asked before the preview. The 057
  script `utils/migrate-altap-settings.cmd` is retired. Debug-only seam `TC_CFGIMPORT_AUTORUN` /
  `TC_CFGIMPORT_TEST_ROOT` (fixtures under `HKCU\Software\Tandem Commander Test 245`). Traps:
  - Add mode replaced a plug-in command's DEFAULT shortcut (it kept only user-assigned ones).
  - `AskForMasterPassword` always shows its dialog: ask only when not entered.
  - The FTP loaders validate a bookmark's proxy UID against the CURRENT list and `LoadPassword`
    reads the registry directly: the handler reads raw UIDs and password blobs itself.
  - `SALAMANDER_ROOT_REG` is NULL before the first save of a fresh configuration (the offer never
    showed); a fresh start picks the system language, so the offer needs translated strings.
  - Review: Replace re-numbered proxy UIDs (the default proxy pointed at another server); a commit
    that cleared lists before copying; a `__try` that swallowed plug-in crashes and then saved the
    half state; the preview and the import deciding passwords differently; "Use Recycle Bin" without
    its masks (permanent deletes); a program check reaching UNC paths; a failed plan still applied;
    viewer rows before `*.*` silently changing what opens files.
  - `SalWToU8Alloc(name, 0)` returns NULL: the default (unnamed) value needs its own case.
  - Translated formats that mix `%s` with `%d` crash when a translation reorders them: numbers are
    formatted to text first.
  - Bash here-documents collapse backslashes (`L'\\'` became `L'\'`): edits go through files.
  - DeepL ran with `formality=prefer_less` (informal) against a formal corpus: new strings are
    translated with `merge.py --formality prefer_more`. The rebrand step renamed "Altap
    Salamander" in our own texts (dialog captions too - they have no id of their own):
    `translations/brand-exempt.json`. `merge.py` keeps an id's machine text when its English
    changes: remove the row from the `.slt` to get it translated again.
  Tests: saltests 23,037 -> 23,491; e2e matrix `probe/ci245_e2e.ps1` (S0-S14, 94 checks), UI
  probe `probe/ci245_ui.ps1` (U1-U5, 29 checks; Release 5); two review rounds (five agents).
- 246-network-drive-labels: **mapped network drives show their Windows name** ("Archiv
  (\\server\share\path)") in the Change Drive menu and the drive bar tooltip, and the **drive
  bars' disconnected icon follows Windows** (a user report; same in Altap Salamander). Measured
  first (three agents, `analysis.md` G): Explorer's name is `_LabelFromReg` under
  `HKCU\...\Explorer\MountPoints2\##server#share#path` (rename or GPP drive map; keyed by path,
  case-insensitive; `\` -> `#`, `#` kept); the server volume label is NOT what Explorer shows.
  Every red-X state producible here has the letter ABSENT from `GetLogicalDrives` (the menu already
  showed icon 31); the stale icon was the drive bars' change detection, which compared only
  `GetLogicalDrives() | remembered` - a remembered drive's state change leaves it equal (baseline
  negative control: bar image unchanged after activation and after Alt+F1 open/close). Fix: pure
  rules in header-only `src/common/salnetdrive.h` (key name, name cleaning, "Name (path)" text with
  '&' doubling, `SalNetDriveFitU8`, state rule) with saltests; `drivelst.cpp`: remote path from
  `WNetGetConnectionW` (also returned, with 1201, for a remembered unavailable drive), name from the
  registry (wide; REG_EXPAND_SZ expanded as Explorer does), text on the heap (never cut; unnamed
  drives unchanged); disconnected = letter missing OR `ERROR_CONNECTION_UNAVAIL` OR
  `WNetGetConnection3W(WNGC_INFOLEVEL_DISCONNECTED)` (exported by mpr.dll, absent from the 10.0.26100
  SDK headers: resolved at run time); `CachedNetDisconnectedMask` compared by
  `RebuildDriveBarsIfNeeded`, also on main window activation (`WM_USER_END_SUSPMODE`, quiet - no
  message box, also in the rebuild it triggers); the tooltip reads the name at hover time and
  shortens only the NAME (whole character + U+2026) to fit the 5000-byte tooltip buffer;
  reconnection (`ExecuteItem`) takes the remembered path from Windows, never the shown text (fixed
  doubled '&'). Debug-only seam `TC_PROBE_DRIVES_DUMP` (`contracts/probe-seam.md`). Traps:
  - `DriveText + 2` was also the remote name for reconnection - a label in the text would have
    broken it; the doubled '&' and a cut path already reached it.
  - The tooltip fallback `strcpy` into the 5000-byte buffer overflowed once the stored text was no
    longer capped (review); a huge policy name cut the tooltip's path away (independent test).
  - The quiet activation check rebuilt the bars through a non-quiet `BuildData` (review).
  - The probe's own folder was emptied at start and deleted the baseline copy kept in it.
  - The tooltip hover cannot be driven on the hidden desktop (`GetCursorPos` / `WindowFromPoint`):
    the seam calls the tooltip function at each bar check instead.
  - Bash here-documents collapsed `\\` in a saltests edit again (CLAUDE.md rule 123).
  Left: the reconnection chain stays code page / MAX_PATH (backlog
  `remembered-network-drive-with-a-non-code-page-or-long-path`, pre-existing); "letter listed,
  server off", the hover and third-party network providers are a person step
  (`check-network-drive-names-and-disconnected-icons-with-a-real`).
  Tests: saltests 23,491 -> 23,731; probe `probe/run246.ps1` (fixed 0 FAIL, baseline negative
  control); independent black-box suite `test-independent/` (performance: menu +3.2 ms, activation
  no extra cost); two review rounds.
- 247-backlog-run-loop: `/tandem-backlog-implement` item after item without a person -
  `tools/backlog/loop-start.sh` (+ `loop-pause.sh` / `loop-resume.sh` / `loop-stop.sh` /
  `loop-status.sh`, one-line wrappers of `tools/backlog/loop.py`, stdlib). One fresh
  `claude -p '/tandem-backlog-implement <slug>'` per item, session id chosen by the loop, stream-json
  log per item in `.git/tandem-backlog-loop/logs/`, claude's unattended retry mode
  (`CLAUDE_CODE_RETRY_WATCHDOG=1`) waits usage limits out in-process. The outcome comes only from
  `RUNS.md` (a row of the item) and the run lock; an interrupted run (limit, error, stall, Ctrl+C,
  a killed loop, a reboot) is continued in the same session (`--resume`) with bounds, and only while
  it holds its own lock (item + taken after the run started + the same `started` once seen). The loop
  prechecks lock / `main` / clean tree / `check` / an eligible item and waits instead of starting a
  refused run; nothing eligible = wait (no `nothing-to-do` runs); 3 `blocked` in a row stop it.
  pause = finish the item then wait; stop = finish then end; Ctrl+C = hard stop (kills claude's
  tree, the next start continues). Skills: *Continued run* (§0.11), `/tandem-backlog` refuses
  changes while a run holds the lock or a loop runs unpaused. Traps:
  - the lock file has no session id: a manual run of the same item taking the lock first made the
    loop's refused run look stalled and be continued into the other run's tree (review MUST); the
    fix then dropped a refusing *continuation* and waited for ever on its own lock (review 2).
  - Git Bash kills loop and claude together without the signal handler - the next start must
    say what happened (registry of a cut GUI probe) and continue; process groups do not help there.
  - a `rejected` rate event before a successful end only means claude waited; `Context limit
    reached` is not a usage limit; each attempt is judged by its own part of the log.
  - Git Bash collapses `\\` of a JSON argument to a native program (rule 123 again).
  - `test_backlog.py` fails at `main` (fixture folder not in git) - Inbox item
    `backlog-fixture-empty-specs-folder-missing`.
  Tests 57 (fake claude; Ctrl+Break, pause/stop, orphan claude as processes), mutants 38/39 caught
  (1 near-equivalent), e2e with the real claude 5/5 three times; two refute-first reviews. Person
  step `backlog-loop-person-checks` (typed Ctrl+C in mintty, the first real usage limit).
  - Amended 2026-10-23 (maintainer session, after 312 / 314 blocked only for translations and 320
    idling ~1.5 h on a killed reviewer): a run does the two-stage `.slt` refresh itself (stop-rules
    §2.13: `--formality prefer_more`, changed English set to `english_fallback` by the template's
    `[KIND n]` key, gap and `--budget` guards, read-back pins, layout drift committed), records an
    unreachable secondary part of *Expected* as an Inbox item and closes (§2.14), merges a moved
    `main` into its branch (SKILL.md step 9, conflict table + backlog recipe, guard on the item),
    carries over a stopped branch's work (4.6, also from `origin/`), closes a confirmed
    not-reproduced item and a split parent, three review rounds, never idles on a reviewer that
    stopped. The loop kills and continues a run whose wakeup ticks report nothing changed twice
    with no background task (`IDLE_WAKEUPS` 2, `MAX_NUDGES` 3; only a tick started by
    `loop_wakeup` counts, any other turn start resets): replayed over all 111 run logs it fires
    once, in 320 (log line 967). Three refute-first reviews of the rules, one of the watchdog.
- 248-folders-column-names: **the Desktop view's column headers were mojibake** on a non-English
  Windows (GitHub issue #13): the Folders plug-in (`fld:`) handed the shell's column names to the
  core as UTF-8 (feature 004), the core draws column names in the code page (MBCS build, `TextOutA`)
  - "Typ položky" showed as "Typ poloĹľky". Now the plug-in converts them to the code page with
  `SalWToCodePageWhole` (new header-only rule `src/common/salcpfit.h`, usable by plug-ins): no
  best-fit (a character outside the code page shows as "?", never a lookalike letter), a name that
  does not fit is cut at a whole character (never half a surrogate pair or a double-byte
  character, never empty - `CColumn::Name` must not be empty), no flag on the UTF-8 system code
  page and a retry without it on `ERROR_INVALID_FLAGS`. Maintainer's decision: fixed in the plug-in
  only, plug-in interface unchanged; cell texts stay UTF-8 (104). Every core reader of
  `CColumn::Name` is code page (header paint and width in `filesbx2.cpp`; menu, sorting, view
  configuration use the ID). Traps: `WideCharToMultiByte` with an output size of 0 returns the
  needed size instead of failing; the header line is the top of the panel's list window (a crop
  above it reads the directory line); a probe that OCRs the list must not log what it read (the
  user's file names). Limits: code points, not graphemes; Czech UI on a 1252 system shows "?".
  From backlog item `drobna-chyba-textu-v-hlavicce-pro-zobrazeni-plochy-v-cestine`. Probe
  `folders248_probe.ps1` COL2 / COL3 FAIL -> PASS 6 / FAIL 0 (OCR of the header on the hidden
  desktop, cs-CZ, ACP 1250); saltests `TestCpFit248` (22 checks, 24,297 -> 24,319, negative
  controls caught); two refute-first reviews (no MUST; empty name -> whole-character cut, checks
  that pin the pair cut and the flag retry). Inbox: duplicate shell columns after a view-mode
  switch; the interface does not document column names as code page.
- 249-temp-walks-junctions: copying files out of a folder inside an archive browsed through an
  external archiver (Archive associations -> 7-Zip, F5 / drag & drop) moved the files of a junction's
  TARGET into the target folder, without a question, when the unpacker restored that archive folder
  as a junction: `PackUniversalUncompress` (`pack1.cpp`) finds the extracted subfolder by taking the
  first directory at every level of its `PACK*.tmp` folder, and `MoveFiles` then moved that
  folder's content (the link was the root of the move, so the link question never came). Now a
  directory on the archive path that `DeleteAsDirLink` takes for a link (197, fail closed, cloud
  placeholders are folders) refuses the unpack before anything moves: `IDS_PACKERR_GENERAL` with the
  path and the system text of `ERROR_REPARSE_POINT_ENCOUNTERED` (no new string), the temporary
  folder removed by 212 (the link as a link), `FALSE` to the caller. 212's start-up `SAL*.tmp` sweep
  is now driven (a junction inside, its target kept). The ZIP self-extractor's own
  `_RemoveTemporaryDir` (`selfextr.cpp`) removes a reparse directory as an entry - source only: its
  standalone `selfextr.vcxproj` does not build here (D8003) and no `.sfx` ships; `sfx7zip/install.c`
  has the same walk, unreachable (Utils configuration only). Reach: 7-Zip 22.01's own `x` refuses
  "dangerous" links and re-targets a WIM junction inside its output, so it needs an unpacker that
  restores a junction (another executable set as the 7-Zip executable). Traps: "Reload Environment
  Variables" (on by default) rebuilds TMP from the registry at start - a probe that points TMP at a
  fixture must turn it off; the start-up question comes seconds after the main window; a probe
  answers Yes only to "delete 1 temporary directory". Limits: the message names the removed
  temporary path (Inbox); a link restored outside the archive path is moved as a link or asked
  about (existing Move). From backlog item `temp-dir-walks-follow-junctions`. Probe
  `tempjunction249_probe.ps1` (fake `7z.exe`: `l` -> real 7-Zip, `x` -> a junction) UNPACK FAIL ->
  PASS, DEEP (second level) FAIL -> PASS on a control build, SWEEP / PLAIN PASS; 8 / 0; one
  refute-first review (no MUST; its variant MERGE row confirmed the link question; the fix-log's
  claim about the self-extractor's project corrected).
- 250-damaged-highlight-entry: a damaged entry of the panel item highlighting list (no readable
  `Masks`: missing, empty key, wrong type, over `MAX_PATH` bytes) hung the start-up - `LoadConfig`
  advanced and closed the entry key only after a readable `Masks`, so it re-opened the same key forever
  (silent 100 % CPU, or the same "Error Loading Configuration" box again and again); the low-memory
  `continue` did the same - now every round advances and closes its key and the damaged entry is skipped
  (the existing box at most once). Traps: the splash is a button-less `#32770` - a probe must not count
  it as a box; the shared probe library only *notes* the Debug handle monitor ("monitored handles"), a
  probe that claims no leaked key must fail on it itself. Limits: a skipped entry is not written back
  on exit; the settings import still ends its list at a damaged source entry, and the viewers, editors
  and User Menu loaders end theirs and the save erases the later entries (both Inbox). From backlog item
  `a-damaged-highlighting-entry-hangs-the-program-at-start-up`. Probe `hlt250_probe.ps1` 3 / 5 FAIL
  (no main window) -> 28 / 0; one refute-first review (no MUST; its negative control on an unfixed
  build and on a leaked User Menu key confirmed the probe; KEYS rows added).
- 251-dialog-text-fits: text typed into a field that fits the field (UTF-16 units) but not the
  program's buffer (UTF-8 bytes, CJK three each) was cut at a whole character and used - Make File
  List wrote its list into another file (a 274-byte name cut to 67 letters, no `.txt`) and lost a
  long line format's tail; the user menu / viewers / editors stored a shorter Command, Arguments or
  Initial directory (another program would run); hot paths stored path and name as `?` (a code-page
  fallback); the drives page's "go to" path and Edit New's "Save as default" were stored cut; the
  browse buttons started from a cut path - now each refuses with "The path specified is too long."
  (no new string), the dialog open, the item selected, the field marked. One rule `SalWTextFitsU8` /
  `SalU8TextFits` (`salunicode`, saltests), `SalWindowTextFitsU8` / `SalGetWindowTextU8Alloc`
  (winlib), `DlgItemTextFitsU8` (214's check generalised). Pages that store on every keystroke keep
  the whole text in their (heap) items and refuse in `Validate`, which runs on OK and on leaving the
  page; their loaders' sizes are the limits (`MAX_PATH`, `USRMNUARGS_MAXLEN`, `HOTPATHITEM_MAXPATH`).
  Traps: the Configuration dialog's OK button is id 5 - a posted IDOK reaches the page only; a page
  that keeps whole text must also *reload* it whole (`CHotPathItems::PeekName` / `PeekPath`; the
  fixed-buffer reload showed mojibake and let one more edit store a cut path - review 1); hot path
  labels now end at a whole letter (`GetDisplayName`). Limits: the masks, the filter, the volume
  label and the hot path in-place label edit (stores a cut name) still cut (Inbox, `leftover:251`);
  the directory menu's and `CCompareArgsDlg`'s browse checked by reading. From backlog item
  `dialog-typed-text-cut-to-caller-buffer`. Probe `dlg251_probe.ps1` 26 / 16 FAIL -> 42 / 0 (4
  exact-fit controls and a short one); 214's probe 4 / 0; two refute-first reviews (one MUST fixed, rows added; the
  second without MUST).
- 252-archive-case-sensitivity: 7-Zip (7z, rar), TAR and SFTP listings never declared
  `SALDIRFLAG_CASESENSITIVE` - in an archive holding a.txt and A.txt, Paste could extract the other
  twin, Store / Restore Selection and Reselect took both, Hide Selected Names hid both; folders D and
  d were merged and TAR (byte-exact extraction) extracted only one of them, silently. Now 7-Zip and
  TAR build the listing case-sensitively and clear the flag afterwards unless a folder holds case
  twins (`salcasetwins.h`, saltests: byte-different names equal by `SalNameOrderCompareCI` or by the
  legacy fold `StrICmp` - both are used on archive names); SFTP always (as FTP). Traps: deciding
  after a case-insensitive build is too late (the merge hides the twins), a second read of a TAR is
  costly - so build CS, then clear; an archive spelling one folder in two cases is split now (known
  change); 7-Zip needs `-ssc` to make twin fixtures. Limits: Paste and SFTP by reading (person step);
  ZIP keeps its Unix-only rule; a TAR folder entered in another case extracts nothing (pre-existing,
  Inbox). From backlog item `archive-plugins-declare-case-sensitivity`. Probe `arc252_probe.ps1`
  6 FAIL / 10 -> 16 / 0 (negative control: TAR always case-sensitive fails TAR-CONTROL); one
  refute-first review (no MUST; rationale corrected, content check added).
- 253-attrs-link-own-entry: Change Attributes on a junction / directory symbolic link compressed,
  uncompressed and re-timed the folder the link points to (213 had stopped only the walk into it) -
  now `DoChangeAttrs` takes a directory link (`DeleteAsDirLink`, fail closed, asked only for an
  entry listed with the directory and reparse bits) and opens it with `FILE_FLAG_OPEN_REPARSE_POINT`
  for compression and times (the link's own state, measured on NTFS); an encryption change of such
  a link is refused (`ERROR_NOT_SUPPORTED` under "Error Changing Encryption" - EncryptFile / DecryptFile
  follow a link; not `ERROR_INVALID_FUNCTION`, which switches encryption off for the rest of the
  operation). Decisions in `salreparse.h` (saltests). Traps: `$PSScriptRoot` is empty in a probe's
  parameter default (PS 5.1); a cross-process `DTM_SETSYSTEMTIME` needs the SYSTEMTIME in the
  target process; no EFS certificate may be created on the build machine. Limits: encryption not
  driven (person step); file symbolic links still reach their target (Inbox). From backlog item
  `change-attrs-on-link-reaches-target`. Probe `attrs_link253_probe.ps1` 4 FAIL -> 10 / 0 (1 NOT
  DRIVEN), 213's probe 8 / 0; one refute-first review (no MUST).
- 254-renamer-regex-letters: the Renamer's regular expressions stepped and classified BYTES of
  UTF-8 names - `.`, `[ž]`, `[^l]`, `\w`, POSIX classes, a global empty match took a piece of a
  letter (the new name refused "(123)"), `а\b` replaced the FIRST Cyrillic а ("ЖAба" - a wrong name
  written), `ž+` / look-behind / case-insensitive `\xC5\xBD` / "Σ" vs "ς" missed; plain Whole words
  took a combining accent for a word end ("Cafe" -> "Tea" made "Teá"). Now units (`salu8letter.h`:
  a valid character, a WTF-8 surrogate, else one byte; stepping back = stepping forward), the class
  a variable-length operand (ASCII / lone-byte bitmap, explicit byte members, NEG, type tests,
  code-point ranges), letters classified by `GetStringTypeW` and, outside the BMP and for marks,
  `icu.dll` (System32, optional); `\x` escapes forming one letter and `\ž` are one folded letter;
  `SalU8FoldCodePoint` folds the final sigma; history by `SalNameOrderEqualCI`; the preview sort was
  already by letters (004). Traps: ASCII ranges keep the old byte loop exactly (an escaped end is
  exclusive, reversed wraps) - checked 330,000 ASCII cases identical; byte ranges like
  `[\x80-\xFF]` cover a letter all of whose bytes they hold (review 2); Windows calls a precomposed
  "é" C3_NONSPACING and gives no type to Mc marks or non-BMP letters; Python edits of C sources
  turn `\x..` in replacement strings into bytes - use chr(92). Limits: case-insensitive ranges
  compare folded letters; `(?<=ab|ž)` now refused. From backlog item
  `renamer-regex-single-byte-classes`. Probe `ren_regex_probe.ps1` 17 / 19 FAIL -> 25 / 0 (50 / 0
  with END rows); 210 16 / 0, 196 / 199 / 206-209 pass; two refute-first reviews (M1 escaped
  letter taken as its lead byte - fixed; S1, S2, review-2 S1 fixed).
- 256-popup-wide-mnemonics: a popup menu took the typed key through a code-page loop - a character
  outside the keyboard layout's code page arrived as '?' (and ran an item whose hot key is '?'), a
  posted U+010D as 'c', a DBCS one as bytes; the owner question (`WM_MENUCHAR`) carried no character,
  so owner-drawn shell-extension items (TortoiseSVN) never answered; the Find window compared a
  hidden control's code-page hot-key byte with a virtual key ("R&&D" gave 'D'). Now the popup loop is
  wide (`PeekMessageW` / `DispatchMessageW`, `OnChar(WCHAR)`), the question is
  `MAKEWPARAM(key, MF_POPUP)` sent in the owner's own kind (a W send to a code-page window scrambles
  wParam - measured), select / execute answers are carried out for a valid item of a popup built from
  a Windows menu (`SalMenuCharAnswer`), and Find matches by virtual key (ASCII, as before) and by
  `WM_SYSCHAR` character (`SalDlgHotKeyW` and friends, `salmenuhotkey.h`, saltests). Traps: honouring
  MNC_EXECUTE made an uninitialized `LRESULT` in `CFilesBox` dangerous (review 1 MUST - all answers
  start at 0 now); `DefWindowProc` answers 0. Limits: the menu bar's own loop (F10, then a letter)
  stays code-page (Inbox `menubar-loop-wide-mnemonics`); the panel's background / New menus and the
  Find window lose the owner's answer (Inbox `menuchar-owner-routing`); real keyboards, IMEs,
  DBCS / UTF-8 systems and TortoiseSVN are a person's (`popup-hot-keys-real-keyboard-256`). From
  backlog item `menu-popup-loop-wide-mnemonics`. Probe `pm256_probe.ps1` 3 FAIL -> 6 / 0; two
  refute-first reviews (M1, S1 fixed; S2 recorded).
- 257-regedt-find-words-hex: Registry Editor Find - a regexp with Whole words judged the characters
  around a match from the start of the value, not of its line (on the 2nd+ line of a list a whole
  word was missed and a fragment found); an empty regexp with Whole words found nothing; a letter
  of 2+ code-page bytes inside `'...'` of a HEX pattern became one 0x00 byte (every non-ASCII
  letter with a UTF-8 code page) and the length check counted one byte. Now the rule gets the line
  (`SalRegFindWholeWordInLine`), an empty regexp is the empty pattern (everything), and
  `SalHexPatternToBytes` (`src/common/salregfind.h`, saltests under 65001 / 932 / 1250) converts
  each `'...'` at once with the plain pattern's `WideCharToMultiByte(CP_ACP, 0)` and counts the same
  bytes (too long refused, never cut). Traps: a regexp's `patternALen` carries its NUL for
  `Set(PatternA)` - only the empty one gets 0; a whole-file clang-format re-flows `saltests.cpp`
  (format `--lines` only). Limits: the GUI with a UTF-8 code page is a person's
  (`regedit-find-hex-utf8-code-page-check-257`); the regexp's text buffer is still sized by UTF-16
  units on a multi-byte code page (Inbox `regedit-find-regexp-multibyte-code-page-buffer`); Whole
  words ignores the punctuation the help names (Inbox `regedit-find-whole-words-punctuation`). From
  backlog item `regedit-find-whole-words-and-quoted-hex-letters`. Probe `find_words_hex_probe.ps1`
  7 / 2 -> 9 / 0; saltests negative control 9 failed; one refute-first review (no MUST).
- 258-sftp-drop-folder-upload: an SFTP upload into an upload-only ("drop") folder - the server lets
  an account create files there but refuses `stat` / `lstat` / listing / rename / remove (SFTPGo
  "upload" without "list", hosted drop boxes) - failed for every file with "Permission denied" at
  the first `lstat` (139 refuses when it cannot tell whether the target exists; a Unix 0733 folder
  on OpenSSH already worked - measured). Now an `lstat` refused for want of a right on a live
  session takes the drop route: WRITE|CREAT|EXCL|TRUNC under the name (never a temp, no fallback),
  confirmed by size or - when the size request is refused the same way - by the acknowledged bytes
  and the checked close (`SftpUploadConfirmation`, every route; libssh2's `sftp_write` returns
  acked bytes); a failed one is unlinked once or named as a partial file. The overwrite question
  states the limits of 139's replacement (hard links keep the old content; ACL and extended
  attributes not carried - SFTP v3 cannot see them, the long name's link count must not be
  parsed). A `.tcpart-*` that a lost connection kept from being removed is remembered on the
  `CSFTPSession` (memory, 16) and offered (Yes / No) at the next upload of that session; only-copy
  temps are never recorded. Traps: TRUNC with EXCL matters only on a server that ignores EXCL -
  without it the new bytes landed over the old tail and were "confirmed" (review 3); taking a
  refused-and-hidden folder as there let a Move delete an empty local folder that never arrived,
  also on OpenSSH via a link into an unreadable folder (review 2 - reverted; Inbox
  `sftp-a-folder-uploaded-again-into-an-upload-only-folder`); the probe's test server must allow
  what the product must prevent (review 1: DROPEXIST passed by the server's own refusal); a Copy
  posted right after the reconnect of a failed upload opened nothing (Inbox
  `sftp-a-copy-posted-right-after-a-failed-upload-and-its`). Limits: earlier runs' temps are not
  looked for; a real service is a person's (`sftp-drop-folder-on-a-real-upload-only-service-and-an-acl-on`).
  From backlog item `sftp-replace-keeps-links-acls-drop-dirs`. Probe `sftp258_probe.ps1` (paramiko
  server `dropsftp.py`) 7 / 5 -> 20 / 0; negative controls CUT, DROPNOEXCL; 133's probe 76 / 0;
  three refute-first reviews (review 2 one MUST, fixed by the revert).
- 259-long-name-refusals: Paste of a file or folder into its own folder said "Cannot copy a file
  to itself." when its "- Copy" name reached 260 bytes - also for a valid name (84 CJK letters +
  ".txt"); Edit New File refused every path of 260+ bytes (a relative name in a deep folder, a
  typed long path, a 100-letter CJK name); `IsSimpleSelection` fell back to the ANSI code page
  (cut at 259 bytes) and told a too long source folder as a Unicode problem - now the copy name
  is built whole by `salcopyname.h` (`SalMakeCopyNameU8`, the Explorer rule ported) and judged
  by 255 UTF-16 units, a too long one gets the "name is too long" question (Skip / Skip all /
  Focus, 141's route) and never targets its source; Edit New File takes paths up to
  `SAL_MAX_PATH_UTF8` and says "too long name" for a name over 255 units (Windows itself answers
  "invalid name" - measured, the first answer was revised); a failed conversion refuses the
  selection and `SrcPathTooLong` says "The path specified is too long.". Traps: the probe rows
  shared a folder (ABS saw REL's file); the OVER row first accepted the old wrong "path too long"
  (review). Limits: a name with a zero-padded "(001)" stops at the first too long attempt; a new
  name of 260+ bytes is not focused; the Paste rows need the clipboard (person step
  `paste-of-a-long-name-into-its-own-folder-check-the-copy-name`); Inbox
  `paste-and-drop-of-our-own-files-keep-a-code-page-fallback`,
  `create-directory-refuses-a-relative-name-in-a-folder-whose`. From backlog item
  `core-long-name-wrong-refusals`. Probe `editnew259_probe.ps1` 7 / 3 -> 14 / 0; `TestCopyName259`
  (negative control: the old 260-byte limit fails 5); one refute-first review (no MUST).
- 260-archive-cache-long-names: F3 / F4 of an archive member with a long valid name (90 CJK letters
  = 274 bytes) said "resulting filename is too long" - the disk cache limited its temporary copy to
  259 BYTES; a .gz file's stored name was cut at 259 bytes and extracted under the cut (or, cut
  inside a letter, garbled) name - now the core's F3 / F4 ask the cache's long mode
  (`salcachename.h` `SalCacheTmpPathFitsU8`: at most 259 UTF-16 units; the plug-in services and the
  User Menu keep the byte rule - plug-ins may copy the path into 260 bytes), the edit's way back
  holds the copy's path whole (`CheckAndPackAndClear` cut at 620 bytes with `_TRUNCATE`;
  `CopyFilesTo`), the start-up cleanup walks long names (bounded at 128 levels, review 2), and the
  gzip name is read whole (64 KiB bound) and refused over 255 units with the system's "(206)"
  text. Long folders in archives: measured already reported by every route - no change. Traps:
  feature 095's 520-byte limit of the name handed to the archiver still refuses longer members
  (review 1 MUST - kept, claims corrected; Inbox
  `f3-f4-refuse-archive-members-whose-path-inside-the-archive`); the program regenerates its
  environment from the registry, so a probe cannot give it another TEMP; Bash here-documents and
  MSYS `//` arguments garbled a test insertion. Limits: the long-%TEMP% edit-back, "Copy selected
  to..." and the crash cleanup are a person's
  (`editing-long-named-archive-members-the-rows-the-feature-260`); Inbox
  `unrar-plug-in-a-member-name-over-259-bytes-overflows-a-stack`,
  `focusing-an-archive-member-with-a-very-long-name-shows`, decision
  `a-gz-file-whose-stored-name-is-too-long-for-windows-refuse`. From backlog item
  `archive-long-names-cache-folders-tar`. Probe `cache260_probe.ps1` 10 / 4 -> 16 / 0; 222's probe
  10 / 0; `TestCacheTmpPath260`; two refute-first reviews (review 1 one MUST, fixed; review 2 none).
- 261-case-twins-exact-match: in a case-sensitive folder holding a.txt and A.txt, Compare
  Directories paired a.txt with the other side's A.txt (both left twins marked, a right twin's
  partner marked different, sub-folders with other names "identical"), and the viewer's next /
  previous file, the User Menu's second compare name and Ctrl+X ghosting in the other panel took
  the first name equal ignoring case - now lookups take the byte-identical item, else the only one
  equal ignoring case (`salnamerun.h` `SalNamePickIndex`), and Compare Directories pairs a run of
  one sort key that holds twins as a set (exact names, then case-only pairs between names without
  twins; `SalTwinRunPairs`), walking the comparison's copies pairs first and sorting them back
  before the marks are transferred. Traps: a comparison chosen pair by pair (exact where a twin is
  involved) is not consistent with the sort order - the locale key ignores a soft hyphen and folds
  NFC / NFD - and stepped past a partner (review 1, measured); an ignore mask must be checked again
  after a run is rearranged (review 2); the Code Viewer plug-in (the default for .txt) has its own
  next / previous command ids. Limits: remembered folder sizes (`CDirectorySizesHolder`) are
  unreachable - unchanged; runs without twins keep 232's comparison (soft hyphen / NFD pairs can
  still be missed, pre-existing, Inbox `compare-directories-misses-a-case-only-pair-beside-a-soft`);
  Inbox `find-window-the-viewer-next-previous-file-takes-the-first`,
  `turkish-azeri-locale-index-html-and-index-html-never-compare`,
  `ctrl-x-ghosts-a-name-in-the-other-panel-that-shows-a-case`; Ctrl+X and the User Menu are a
  person's (`check-ctrl-x-ghosting-and-user-menu-compare-names-with-case`). From backlog item
  `case-sensitive-twins-first-match`. Probe `twin261_probe.ps1` 5 FAIL / 14 -> 16 / 0 (row CMPSHY
  from review 1); 232's probe 16 / 0; `TestNameRules261` (negative controls fail 7 and 5); two
  refute-first reviews (no MUST; review 1 S1 fixed by the set pairing).
- 262-codeview-code-tables: the Code Viewer (the default F3 viewer for source and text files) read a
  file without BOM that is not UTF-8 or UTF-16 only in the system code page, and its Encoding menu
  (F8) was a fixed list of five - a DOS CP852 or ISO-8859-2 text on a CP1250 machine showed wrong
  letters with no way to fix it there (070 FR-024, review F16) - now View > Encoding lists, after the
  five entries, every conversion table of the built-in viewer's Convert menu (`EnumConversionTables`,
  its order and grouping), a choice re-reads the open file through the 256-byte table and the
  system code page (what the built-in viewer draws), the status bar names the table, F8 / Shift+F8
  cycle the whole list, and a table chosen from the menu is remembered (`DefaultConvert` in the
  plug-in's key) for later single-byte files; *System code page* forgets it; nothing remembered =
  the old reading. Pure parts in `src/common/salcodetable.h`. Traps: table names are code-page
  bytes (069 B-5) and not all ASCII (convert\centeuro "Kameničtí - CP1250"; `grep` hides those
  lines), while the registry facade stores UTF-8 - the name travels code page <-> UTF-16 <-> UTF-8
  with no best fit, a failure stores ""; cycling with F8 must not change the remembered table (review
  1: one Shift+F8 on a UTF-8 file stored "ANSI - OEM" for every later file). Limits: no Auto-Select
  and no explicit Set as default (new UI strings - Inbox
  `code-viewer-no-auto-select-of-the-code-page-and-no-explicit`, which also records the UTF-8
  convert.cfg and UTF-8 system code page limits); the letters in the page are a person's
  (`on-screen-check-of-the-code-viewer-conversion-tables-feature`). From backlog item
  `codeview-code-tables-for-single-byte-files`. Probe `cvtab262_probe.ps1` (menu 5 items, 3 FAIL)
  -> 16 / 0; `TestCodeTable262` (negative control fails 1); one refute-first review (no MUST; S1
  fixed).
- 263-import-foreign-reg-keys: the start-up import of a configuration file (config.reg next to the
  exe, in %APPDATA%\Tandem Commander, or -C) wrote and deleted every key the file named - another
  program's key, HKEY_CLASSES_ROOT, a `[-HKCU\Software\<other>]` line deleting another program's
  settings - silently when the file also held our root, after a question (default No) when it did
  not - now every key and delete line must be `HKCU\Software\Tandem Commander\0.1` or below
  (`SalRegKeyIsInsideRoot`, `src/common/salregroot.h`), checked by `Parse(..., onlyUnderHKCU)` in
  both passes of `ImportConfiguration`; anything else, or a file without a key under the root,
  refuses the whole file with the existing `IDS_IMPORTCFG_NOTREG` before anything is written (the
  question `IDS_IMPORTCFG_NOTOURVER` is gone, its string stays unused). Trap: the program's own
  dump (`CKey::Dump`) writes bare lines for the parent keys `[HKCU\Software]` and
  `[HKCU\Software\Tandem Commander]` - the first version refused every real export and 245 backup
  (review 1); parent key lines are now accepted and create nothing, a value under them or a delete
  line of them refuses (`SalRegKeyIsParentOfRoot`). A probe file built with a Bash here-document got
  a NUL byte for `\0` (rule 123). Limits: the message does not name the offending key and the help
  does not state the rule (Inbox `a-refused-configuration-file-does-not-say-which-key-is`);
  `HKEY_USERS\<SID>\...` of our own key is refused (fail closed). From backlog item
  `importing-a-configuration-file-writes-every-key-of-a-foreign`. Probe `import263_probe.ps1` 3 FAIL
  of 5 rows -> 26 / 0 (export shape, clear-key round trip, a real 245 backup); `TestRegImportRoot263`
  (negative control fails 2); two refute-first reviews (review 1 MUST fixed; review 2 no MUST,
  SHOULDs done).
- 264-remembered-drive-reconnect: picking a remembered, disconnected network drive (drive bar /
  Change Drive menu) or opening a path on it reconnected it with the remembered path from the ANSI
  `WNetOpenEnum(RESOURCE_REMEMBERED)` enumeration - code page ('?' outside it) and cut at
  `MAX_PATH - 1` bytes - through the ANSI `WNetAddConnection3`; the drive stayed disconnected with
  "The path or file name "Z:\" is invalid." - now `GetRememberedNetDriveRemoteW` (wide enumeration,
  heap) gives the exact path and `RestoreNetworkDriveW` (consts.h) reconnects it: the Windows 7+
  mapped-letter flow of `RestoreNetworkConnection`, wide and unchanged (saved user name / provider
  from `HKCU\Network\<L>` matched by `SalNetDriveSameRemote`, salnetdrive.h; background attempt
  `NonBlockingWNetAddConnection3W` under the Esc wait window - it shares the thread, the wait and the
  now file-static lock with the ANSI twin, its heap strings are freed only after the thread ended;
  `CONNECT_INTERACTIVE` retry; the same messages). `CheckAndRestoreNetworkConnection`'s "listed but
  not answering" branch gives `SalCheckPath` the UTF-8 path (it got code-page bytes, wrong even for
  Czech letters). Measured: Windows refuses a remote name of 260+ UTF-16 units (67), so "long" means
  more than 259 bytes in UTF-8 / a DBCS code page; `WNetRestoreSingleConnectionW` was rejected (its
  UI variant must block the UI thread - the Esc wait window would go). Traps: a PowerShell function
  returning one line unrolls it to a string (`$rest[0]` = its first character - every row judged
  FAIL); Remove-Item of a > 255-character MountPoints2 key name throws inside `finally` and skipped
  the registry restore (restored by hand; the probe now restores first and guards every cleanup).
  Limits: `RestoreNetworkConnection` (UNC roots, Network plug-in via zip.cpp) stays ANSI - Inbox
  `logging-in-to-an-inaccessible-unc-path-with-a-non-ascii`; the credential dialog and Esc are a
  person's (`confirm-reconnecting-a-remembered-drive-on-a-password`). From backlog item
  `remembered-network-drive-with-a-non-code-page-or-long-path`. Probe `run264.ps1` baseline Q1 / Q2 /
  L1 / P1 fail -> fixed 7 rows PASS (incl. 259 characters, saved provider 1204, unreachable server
  53); 246 `itest246_pickcp` PK-Q1 / PK-Q2 reconnected exactly False -> True;
  `TestNetDriveSameRemote264`; one refute-first review (no MUST; SHOULDs done).
- 265-backlog-fixture-specs-folder: the backlog tool's tests failed on every fresh checkout
  (`test_backlog.py` 28 failures, 2 errors of 68) because the valid fixture's feature folder
  `tools/backlog/fixtures/valid/specs/243-example/` (target of the `feature-missing` rule for its
  in-progress item, 242 T010) was empty and git stores no empty folders - now a short `README.md`
  inside it keeps it in git, and the fixtures README says so; the `feature-missing` seed still
  deletes the whole folder. The redundant workaround that created the folder in 247's
  `test_loop.py` `setUp` and its e2e probe `make_repo()` is gone - with the folder in the fixture
  the probe's `mkdir` without `exist_ok` raised `FileExistsError` (missed by a consumer search of
  `tools/` only; search `specs/*/probe` too when changing a shared fixture). Limit: `test_loop.py`
  leaves each test's temporary git repository in `%TEMP%` (Inbox
  `loop-tool-tests-leave-a-temporary-git-folder-behind-on-every`). From backlog item
  `backlog-fixture-empty-specs-folder-missing`. Fresh clone: fixture `check` TOTAL 1 -> 0,
  `test_backlog.py` 28 F / 2 E -> 68 OK, `test_loop.py` 57 OK; negative control (folder deleted)
  brings the failures back; two refute-first reviews (review 1 MUST fixed; review 2 no MUST).
- 266-close-stray-box: closing the File Comparator while a binary comparison still ran could show
  a stray Retry / Cancel file-error box (and after Cancel a "close the comparison?" question) over
  the closing window - its `WM_DESTROY` waits for the worker with a pump that dispatched a hex view's
  pending `WM_USER_HANDLEFILEERROR` (147 review LOW-2) - now both views get `BeginClose()` first in
  `WM_DESTROY` and the hex view's handler returns at once once the mark is set; `CFileMapping::
  Destroy` resets `FileSize` (also removes a second "handle is invalid" box of a recompare whose
  file cannot be opened). Part (1) of the item - a forced Disk Map unload terminating the map's
  thread inside a shell command (143 row E5) - kept as the core's force semantics: the core calls
  `FreeLibrary` after a forced `Release` whatever it returns, an unbounded wait freezes the main
  window, and cancelling the shell's window reverses 143 FR-004; documented at `KillAll`, decision
  item `forced-disk-map-unload-in-a-shell-command-cancel-the-shell`. Trap (review): Disk Map's
  `InvokeCommand` runs without `CMIC_MASK_ASYNCOK`, so a confirmed shell operation in progress is
  cut off by the force too - "file kept" holds only for a waiting confirmation. Limits: the stray
  box timing is NOT DRIVEN (needs a seam); a hex recompare can still paint against the released
  sibling mapping (`Paint` uses its own stored `SiblinkSize`; Inbox
  `file-comparator-hex-recompare-error-box-from-the-released`). From backlog item
  `plugin-close-forced-unload-and-stray-box`. 143 probe E4-E6 PASS 7 / 0 (as before), 147 probe K1
  PASS 2 / 0; one refute-first review (no MUST; SHOULD-1 fixed in texts, SHOULD-2 to the Inbox).
- 267-pictview-exif-rotate: PictView's Exif information command never opened and photos with an
  Exif orientation were never turned - the WIC engine of 006 never reported `PVFF_EXIF`, the gate of
  the command, its menu enabler and the auto-rotation (the same cause 132 met for Update Thumbnail)
  - now the engine reports it for a JPEG whose decoder holds an Exif block (`/app1/ifd`, asked of
  the decoder's own metadata, no second read; 91 of 91 real files agree with an own walker), and
  auto-rotation reads the orientation through WIC (`WicGetExifOrientation`, as the panel thumbnails
  of 064) instead of EXIF.DLL's code-page `EXIFGetOrientationInfo` (a UTF-8 name would silently not
  turn). Pure rule `src/common/salexiforient.h` (`SalExifOrientTurn`: the quarter turn first, then
  the mirrors; the old table had 4 / 5 / 7 wrong). Traps: the old exception "recorded pixel size
  portrait or different - do not turn" would show 7 of the 14 standard orientation samples of the
  real set wrong (dropped; the item asks "turned by its tag"); the viewer's rotate command reverses
  its direction while a mirror is on, and a window that reopens its file keeping the view (111) kept
  the automatic mirror as the user's (review 2 S1: `fAutoMirror*`, only the user's part is kept,
  the turn is chosen for the picture); Update Thumbnail keeps 132's own file check; Pillow turns a
  TIFF on load (no oracle for "as stored"). Limits: JPEG only - TIFF / camera raw left (Inbox
  `pictview-no-exif-command-and-no-automatic-turn-for-tiff-and`); the menu item's enabled / grayed
  state is owed to a person (`pictview-check-the-exif-information-menu-item-is-offered`); the
  first reviewer fast-forwarded `main` and was interrupted mid-probe (registry restored from its
  backup). From backlog item `pictview-exif-dialog-and-auto-rotation`. Probe `pv267_probe.ps1`
  PASS 32 / FAIL 33 -> 80 / 0 (reopen rows 12 / 3 -> 15 / 0, negative control with the old table
  o4 / o5 / o7 FAIL); 132 Update Thumbnail 16 / 0, 120 20 / 0; saltests 24,757 / 0; two
  refute-first reviews (1 interrupted without a report; 2 no MUST, SHOULD S1 fixed).
- 268-damaged-list-entries: a damaged entry of the viewers, alternative viewers, editors or User Menu
  list (a required value missing or of the wrong type, masks too long or with `|` - a hand edit, an
  imported `.reg`) ended the list at start-up (`else break;` before the advance and the close) and
  left its key open; the save on exit clears the key and rewrites it from what was loaded, so every
  later entry was erased without a word (a damaged first entry: the whole list) - now the damaged
  entry is closed and skipped and the rest loads and is saved; the low-memory `break`s still end the
  list but close the key. Pure rule `src/common/salumbalance.h` (`CSalUMSubmenuBalance`): a skipped
  damaged User Menu submenu beginning takes its matching end along (the items inside move one level
  up), a damaged end loads as a plain end (named `LoadStrU8(IDS_ENDUSERSUBMENU)`, as the configuration
  page makes one); intact lists load as read, also the user's own stray end. Traps: "a cut list was
  unbalanced the same way" was wrong - a cut list only lacks an end, a skipped beginning leaves a
  stray end that stops `FillUserMenu2`, takes the toolbar to level -1 and cannot be deleted in the
  configuration page (review 1); the damaged entry's Type is read quietly (`GetValueAux`, quiet) so
  no extra box; the configuration page itself names a new end with code-page `LoadStr` (Inbox
  `the-user-menu-page-names-a-new-submenu-end-in-the-code-page`). Limits: the damaged entry itself
  is not written back; N wrong-type values show N "Error Loading Configuration" boxes (as each read
  always did); a numbering gap or an unopenable entry key still ends the list; a damaged beginning
  whose Type is unreadable leaves its end stray; the settings import still ends these lists at a
  damaged source entry (Inbox `settings-import-ends-the-viewers-editors-and-user-menu-lists`). One
  flaky probe row (WM_NULL unanswered once, about 15 s after start, not reproduced). From backlog item
  `a-damaged-viewer-editor-or-user-menu-entry-erases-the`. Probe `dmg268_probe.ps1` PASS 30 / FAIL 18
  -> 64 / 0 (4 cases added after review 1; negative control on an unfixed build fails every damaged
  row); saltests 24,778 / 0; two refute-first reviews (no MUST; SHOULDs fixed).
- 269-ftp-wtf8-listing: a name with an unpaired surrogate (NTFS allows it; WTF-8 `ED A0 80`) on a
  byte-transparent UTF-8 FTP server came back from the listing read in the code page - the strict
  `MB_ERR_INVALID_CHARS` test of `FTPListingFieldToU8` refused it: another name shown and downloaded
  (`a<U+D800>.txt` -> `aí €.txt` in cp1250), and the upload's "target exists?" check
  (`CUploadPathListing::FindItem`, the same decode) missed it - STOR **overwrote** the server's file
  without the default question. Now a pure rule `SalFtpListingFieldIsU8` (`salftplisting.h`,
  header-only; exactly `Wtf8ToW`'s set, length-bounded, NUL valid) keeps ASCII / WTF-8 bytes; the
  code-page branch of 224 unchanged. Limits: a legacy code-page name whose bytes form a surrogate
  sequence (cp1250 `í` + A0..BF + 80..BF) is now WTF-8 - an upload of its real name creates a second
  file, no overwrite; the CESU form does not round-trip on upload; PWD `lstrcpyn` cut stays (Inbox
  `ftp-pwd-and-created-path-cut`). Docker was not running: 215's `ftpmini.py` got ENC `wtf-8`
  (`surrogatepass`). From backlog item `ftp-wtf8-name-listing-round-trip`. Probe `ftp269_probe.ps1`
  DL / UP-ASK FAIL -> 14 / 0 (DL-ASK, DIR-DL added after review 1; main's `ftputils.cpp` put back
  fails DL, UP-ASK, DIR-DL); 224 probe 16 / 0; saltests 24,816 / 0 (exhaustive vs `Wtf8ToW`,
  168,420 strings); one refute-first review (no MUST; 2 SHOULD fixed).
- 270-mask-filter-label-fits: Select / Unselect and Convert masks, the panel filter, the volume
  label and the hot path list's in-place name edit (F2) read typed text into 260 bytes, cut at a
  whole character - a CJK Select mask of 88 units selected other files, Convert **converted a file
  the typed mask does not match** (measured), the filter was stored cut also with "Don't use
  filter", Drive Information called `SetVolumeLabel` with a cut label, F2 stored 86 of 100 letters.
  Now each dialog's `Validate` refuses first (`DlgItemTextFitsU8`, 251's helper; `Transfer` runs
  only after a good `Validate`); the label edit stores the whole name (`SalGetWindowTextU8Alloc`)
  and 251's page check refuses it at OK. Trap (review 1): the hot path row shows its label cut to
  `MAX_PATH`, so a second F2 started from the cut text - `LVN_BEGINLABELEDIT` seeds the edit with
  the whole display text; comctl32 treats Enter without a change as a cancel (the probe appends a
  letter). A cut volume label (>= 86 units) exceeds every Windows label limit, so it was never
  applied - refused anyway before the write. Limits: Recycle Bin / Find / viewer / compare masks
  still cut (Inbox `masks-cut-recycle-bin-find-viewer-compare`); the label goes to `SetVolumeLabelA`
  as UTF-8, the checker misses that API (Inbox `volume-label-written-through-ansi-api`); Convert's
  syntax check still reads the code page. From backlog item
  `more-typed-fields-cut-to-their-buffer-masks-filter-volume`. Probe `mask270_probe.ps1` 7 FAIL ->
  24 / 0 (12 rows; negative controls: Select check off, no seeding); 251's probe 42 / 0; two
  refute-first reviews (no MUST; NOTE 3 fixed, 2 SHOULD to the Inbox).
- 271-zip-case-twins: a ZIP made on Windows (WSL, a case-sensitive folder, .NET `ZipArchive`)
  that holds a.txt and A.txt, or folders D and d, was listed case-insensitively - Hide Selected
  Names hid both twins, Store / Restore Selection restored both, D and d were one folder whose Copy
  or Delete took both; and in a Unix-made ZIP (already listed apart) copying or **deleting only
  folder "d" also took D/x.txt** (measured) - the plug-in's operations took case sensitivity from
  the selected items, and a folder without an entry of its own carries none. Now the ZIP listing is
  built case-sensitively and keeps `SALDIRFLAG_CASESENSITIVE` for a Unix entry or 252's twins
  (`SalDirTreeHasCaseTwins`), else clears it; the decision travels in the listing's own
  `CPluginDataInterface` and Unpack / UnpackOneFile / Delete start `CZipCommon::Unix` from it.
  Traps: the listing hook alone turns the Unix delete loss on for every Windows twin ZIP (negative
  control 4 FAIL, ZIP-DEL "archive keeps: nothing"); copied files alone do not show a merge (the
  extraction writes the archive's names) - the TREE row counts the Copy dialog's folders. Limits:
  adding INTO a twin ZIP still matches case-insensitively and replaces the other twin after its
  overwrite question (measured by the review; Inbox
  `adding-a-file-into-a-zip-that-holds-names-differing-only-in`); Paste by the clipboard is a
  person's (log line on `paste-of-a-case-twin-from-an-archive-and-sftp-twins-by-hand`). From
  backlog item `a-zip-made-on-windows-that-holds-names-differing-only-in`. Probe `zip271_probe.ps1`
  6 FAIL / 16 -> 16 / 0; 110's probe 42 / 0, 164's 6 / 0; one refute-first review (no MUST; NOTE 1
  fixed, SHOULD 1 to the Inbox item).
- 272-attrs-file-link: Change Attributes on a file symbolic link (focused, or met with Include
  subdirectories in a selected folder) compressed, uncompressed and re-dated the file the link
  points to - also outside the selection - and Encrypt / Decrypt would have changed it too (253
  fixed directory links only) - now `DoChangeAttrs` takes any entry listed with the reparse bit
  that `DeleteAsDirLink` (fail closed) calls a link for a link (`SalAttrsEntryIsLink`, the directory
  bit no longer required) and opens a file link with `FILE_FLAG_OPEN_REPARSE_POINT` for compression
  and times (measured to reach the link itself); its encryption change is refused as 253's. A
  readable tag that is not a name surrogate (cloud placeholder, dedup, WOF, third-party) keeps the
  old way - probe row NONLINK (tag 0x123: the old "Error Changing Compression" 1920). The rule is
  asked only when compression, encryption or times change (review). Traps: a text-mode Python
  rewrite of `worker.cpp` wrote LF endings (restored to CRLF); the probe first matched the wrong box
  title ("Error Changing Compression", not "Error Compressing"). Limits: encryption not driven
  (person step `check-change-attributes-refuses-encrypting-a-file-link`); Convert on a file link
  fails with 1464 and changes nothing (measured outside the program, recorded in the fix-log). From
  backlog item `change-attributes-on-a-file-symbolic-link-compresses-re`. Probe
  `attrs_flink272_probe.ps1` 4 FAIL -> 12 / 0 (1 NOT DRIVEN); 253's probe 10 / 0, 213's 8 / 0; one
  refute-first review (no MUST / SHOULD; NOTE 1 and 2 done).
- 273-tar-case-root: a folder inside an archive opened by a path typed in another case
  (`t.tar\DOCS` for `Docs` - command line, Change Directory, hot path) was listed, but the panel kept
  the typed spelling as its path inside the archive and gave it to the plug-ins as the root of the
  selected names; TAR matches names byte for byte, so Copy (F5) extracted nothing, silently (7z
  copied) - now `ChangePathToArchive` stores the path as the listing spells its folders after the
  shortening loop (`SalArcPathRespell`, `src/common/salarcpathspell.h`, saltests; the first folder
  the listing's own `SalDirStrCmpEx` finds, as `GetFiles`), so every archive plug-in, the directory
  line and the history get the real names. Traps: `SAL_MAX_PATH_UTF8` is ~96 KB (heap buffer); a
  saltests local named `small` is a Windows macro; clang-format of whole files reformats unrelated
  lines. Limits: an archive with case twins in another folder is case-sensitive as a whole (252) and
  a path in another case opens its root (Inbox `a-path-typed-in-another-case-into-an-archive-with-case-twins`);
  a typed Copy target `x.7z\DOCS` from disk still packs with the typed spelling (by reading, Inbox
  `copying-into-an-archive-folder-typed-in-another-case-packs`). From backlog item
  `copying-from-a-tar-folder-opened-in-another-case-extracts`. Probe `arccase273_probe.ps1` 8 / 4 ->
  12 / 0 (negative control: the block disabled -> 8 / 4); 252's probe 16 / 0; `TestArcPathRespell273`
  (negative control 7 FAIL); one refute-first review (no MUST / SHOULD).
- 274-createdir-long-folder: F7 (Create Directory) refused a typed relative name with "The path
  specified is too long." whenever the joined path reached 260 bytes - "nd" in a 288-byte folder,
  100 CJK letters there, and even a valid 255-letter CJK name in a short folder; a name over 255
  UTF-16 units got the same wrong reason - now `CreateDir` joins with `nameBufSize =
  SAL_MAX_PATH_UTF8` (its buffer and the rest of the routine took long paths since 027; Edit New
  File was fixed the same way in 259) and judges the new folder's own name with
  `SalNameTooLongForFileSystemU8` before anything is created (also no missing parent of
  `a\<256 letters>`): "Cannot finish operation because of too long name." (Windows alone answers
  123 "invalid name" - negative control). Pack, Unpack and Make File List keep the default limit:
  their buffers are 259 bytes (not this defect). Traps: `$PSScriptRoot` is empty in a `param()`
  default (PS 5.1); a Bash here-document collapsed `\\` and put a NUL into the probe (123's trap).
  Limits: a created name of 260+ bytes is not focused; an intermediate component over 255 units and
  a path between 32,767 units and `SAL_MAX_PATH_UTF8` keep the system's answer; Inbox
  `the-question-whether-to-create-a-missing-folder-cuts-a-long`. From backlog item
  `create-directory-refuses-a-relative-name-in-a-folder-whose`. Probe `createdir274_probe.ps1`
  8 / 4 -> 14 / 0 (negative control: the name check disabled -> U256 FAIL); one refute-first review
  (no MUST; SHOULD row MULTI added).
- 275-arcmember-long-path: F3 / F4 (and Enter) of an archive member whose path inside the archive
  had 520+ bytes (feature 095's limit, kept by 260 - e.g. 200 CJK letters at the top, or 100 inside
  a folder of 84) said "resulting filename is too long" although the temporary copy fit - now the
  test is gone in `ViewFile` / `ExecuteFromArchive`; the listing bounds the path (~1,021 bytes), the
  cache's 259-unit rule is the only length refusal. Audit: ZIP, 7-Zip, tar, uniso take it (heap /
  refusing); uncab's `lstrcpyn` into 769 bytes (unreachable) refuses now; the external route
  refuses. Review 1 MUST: the Archive Update list (`AddFilesToListBox`, `buf[3 * MAX_PATH]`, result
  ignored) showed only the folder at 780+ bytes - heap line. Traps: focusing such a member shows the
  information line's "Expanded string is too large." and a posted F4 is lost while it is open (the
  probe answers it first); an F4 copy path of 649 bytes now drives 260's 620-byte edit-back fix.
  Limits: ISO / CAB by reading; Inbox `unchm-plug-in-a-member-path-over-259-bytes-overflows-a-stack`,
  `tar-plug-in-ignores-pax-extended-headers`, `archive-update-copy-selected-to-refuses-long-targets`.
  From backlog item `f3-f4-refuse-archive-members-whose-path-inside-the-archive`. Probe
  `arcmember275_probe.ps1` 9 / 5 -> 17 / 0 (without the M1 fix 16 / 1); 260's probe (ARCCAP now the
  viewer) 16 / 0; 222's 10 / 0; two refute-first reviews (one MUST, fixed; then none).
- 276-infoline-long-name: moving the cursor onto an item with a long name (an archive member of
  200 CJK letters + ".txt", 604 bytes; also a disk file on a volume without 8.3 names) showed
  "Expanded string is too large." (once per focus; twice at the start when both panels overflow) and the
  information line kept describing the previous item - the default content names the item twice
  (`$(FileDOSName)` is the name itself without a short name) and `ItemFocused` expanded into 1000
  bytes. Now the expansion is repeated into a heap buffer that doubles up to 65,535 bytes
  (`salinfolinebuf.h` `SalInfoLineNextLen`; the hot-text placements are WORDs), quietly - only the
  last attempt reports, so a malformed content or a width-padded text over the bound still shows
  its one box. Names are never cut (names alone stay under 14 KB). The plug-in route
  (`GetInfoLineContent`, 1000 bytes by contract) is unchanged. Traps: the ZIP listing refuses a
  member over 255 UTF-16 units, so the first ARCMAX row tested nothing; the information line
  exposes no text - the probe hashes its pixels (PrintWindow) with a control row; a PowerShell
  edit of the header dropped its BOM. Limits: the disk case was not driven (C: generates 8.3 names,
  changing that needs an administrator); what the line shows is checked by pixels only (person step
  `information-line-of-a-long-named-item-check-it-on-screen-276`); Inbox
  `the-information-line-keeps-using-a-freed-text-when-memory`. From backlog item
  `focusing-an-archive-member-with-a-very-long-name-shows`. Probe `infoline276_probe.ps1` 16 / 7 ->
  23 / 0; 260's probe 16 / 0, 275's 17 / 0 (its F4 rows no longer meet the box); `TestInfoLineBuf276`
  (negative control: a 1000-byte bound fails 6); one refute-first review (no MUST, no SHOULD).
- 277-ftp-pwd-path-cut: an FTP folder whose PWD reply named a path over 300 bytes - in the German AIX
  form (`257 '/path' ist ...`), or from a legacy (code-page) server whose path is longer in UTF-8 -
  was taken cut to 300 bytes: an ancestor folder. Measured with 215's `ftpmini.py` (new PWDMAP
  option: a folder "reached through a link" whose PWD names a long path, and a one-shot session
  drop): F5 of the folder, the reconnect went to the cut path and downloaded the ancestor's x.txt
  under the deep folder's name. Now the path of a "257" reply is read by `salftppwd.h`
  (`SalFtpPathFromPwdReply`, saltests: three forms, `""` escapes, only within the reply's size, a NUL
  inside refused) and refused when it - or its UTF-8 form, or a failed conversion - does not fit;
  exactly 300 bytes is accepted (the RFC form was refused one byte early). Also: Create Directory's
  report to the upload listing cache walks a long name whole and only invalidates;
  `FTPCompleteAbsolutePath` and `FTPAS400CutFileNamePart` fail instead of cutting (callers refuse);
  the opened-file lock compares names by `SalNameOrderEqualCI`; the upload's link size is skipped for
  a source path over 259 bytes. Traps: without the session drop the worker never went back by the
  cut path and the probe showed the right file; the first "refused" judge accepted the old code's
  cp1250 row (a CWD to the cut path ended in another error); a test buffer named `small` (a Windows
  macro). Limits: AS/400, OS/2 / VMS, the lock and the link size by reading (person step
  `ftp-277-real-server-checks`); folder names still compared by the code-page fold (Inbox
  `ftp-server-path-compare-code-page-fold`). From backlog item `ftp-pwd-and-created-path-cut`. Probe
  `ftp277_probe.ps1` 7 / 3 on the old code -> 10 / 0; 215 12 / 0, 224 16 / 0, 233 as recorded;
  `TestFtpPwdReply277` (negative control: the old cut 7 failed); one refute-first review (no MUST,
  no SHOULD; two NOTEs fixed: a NUL inside the path, the raw bytes of a failed conversion).
- 278-regedt-find-regexp-cp: Registry Editor Find with a regular expression, on a multi-byte ANSI
  code page (UTF-8 65001, 932 / 936 / 949 / 950), converted a key name, value name or text value
  into a space of one byte per UTF-16 unit and searched that many bytes: a non-ASCII text did not
  fit (the conversion failed, stale bytes were searched) or its end was never searched
  (`čččč bar` is 8 units, 12 UTF-8 bytes - `bar` not found). Now `SalRegFindTextToCodePage`
  (`src/common/salregfind.h`) counts the code-page bytes first, converts whole or returns -1
  (never a partial result); `CFindThread::Test` reserves the count, searches the converted count,
  and a failed conversion is no match. Traps: on code page 1250 the old and new code search the
  same bytes, so 257's probe cannot tell them apart - the call site rests on reading plus the
  person step `registry-editor-find-confirm-a-regexp-finds-the-end-of-a-non`. Limits: the
  viewer's export of a text value has the same unit-sized buffer (Inbox
  `registry-editor-view-of-a-text-value-cut-text-and-a-stray`); a DBCS trail byte can still match
  an ASCII regexp (older, not recorded). From backlog item
  `regedit-find-regexp-multibyte-code-page-buffer`. `TestRegFindTextToCodePage278` (negative
  control: unit sizing fails 12); 257's probe 9 / 0 -> 9 / 0 (regression control on 1250); one
  refute-first review (no MUST; SHOULDs: the viewer -> Inbox, the call site's proof stated).
- 279-sftp-drop-folder-again: a local folder uploaded again into an upload-only ("drop") SFTP
  folder failed whole - "Cannot create directory ...: SFTP error 4: Failure", none of its files
  sent (the server refuses the creation of the existing folder and will not show it) - now such a
  folder is "unconfirmed" (`SftpUnconfirmedDir`: mkdir FAILURE / FILE_ALREADY_EXISTS + stat
  refused for a right, both on a live session; `src/plugins/sftp/sftputils.h`): its items are
  tried (files by 258's exclusive create) and counted through `CUploadItemNote` (`Arrived` = the
  server confirmed the file, before a Move's local removal; a subfolder created / shown / with
  something confirmed); zero confirmed = one `IDS_ERR_MKDIR` box naming the folder and the Move
  keeps it; while nothing is confirmed, a creation refused with "no such file / path" ends the
  folder with one "not there" box (`SftpEndsUnconfirmedDir`, the folder's count passed through -
  review SHOULD-1). Traps: 258's first attempt (a5100148) took such a folder as there and a Move
  deleted an EMPTY one that never arrived; the old `Stat` did not record the server's status
  (`StatEx` does); the new buffers belong in the heap `CUploadLevel` (recursion). Limits: a
  creation refused for a right stays the file's own box (SFTPGo's answer for an existing file);
  with nothing confirmed the folder box follows the files' boxes (Inbox
  `sftp-a-folder-uploaded-again-whose-files-are-all-there-ends`); no real upload-only service
  (person step `sftp-a-folder-uploaded-again-into-a-real-upload-only-service`). 258's probe row
  DROPDIR2 is superseded (it now fails by design). From backlog item
  `sftp-a-folder-uploaded-again-into-an-upload-only-folder`. Probe `sftp279_probe` 12 / 8 -> 20 / 0
  (drop server + OpenSSH symlink rows; negative control: zero confirmed taken as there deletes the
  local folder in 3 rows); harness 239 -> 265 / 0; 133's probe 76 / 0; one refute-first review (no
  MUST; SHOULD-1 fixed, FR-007 driven by the reviewer).
- 280-user-menu-long-paths: the User Menu cut every value at 259 bytes - `$(FullPathLeft/Right/
  Inactive)` of a panel showing a 260-byte folder whose first 259 bytes end with a backslash gave
  the folder's PARENT (a command ran on another folder), a longer one said "not defined"; a
  command run without a shell over a selection ran for the first items and then refused a long
  name; `$(ListOfSelectedFullNames)` refused a list that fits; a too long name to compare opened
  the compare dialog empty. Now every value is whole or refused with "too long name" before
  anything runs (`salumvalue.h`, saltests): the enumeration (`UM_GetNextFileName`, now
  `UMNEXT_ITEM / END / TOOLONG` in `UM_ITEM_TEXT_SIZE` heap buffers) never cuts, `UserMenu`
  refuses an item of `MAX_PATH`+ bytes, the route without a shell prepares every command and
  starts them only when all were prepared (any refusal - also Cancel at a missing environment
  variable - now starts none, as the batch file), full paths and compare names carry "too long"
  flags, the panel's full-name list is built whole (`CSalPathBuf`, as Find). Traps: the
  enumeration's end cleared the selection - with the starts after it a failed start lost the
  selection (review 1: the caller clears it, `EndReached` + `UserMenu`'s result); a second
  compare name only guessed in the other panel must stay "no match" (review 1); a test passing
  size 300 for a 260-byte buffer opened a run-time check dialog on the visible desktop. Limits:
  a group command whose first item does not fit is refused although the list holds it (Inbox
  `user-menu-list-commands-refused-when-the-first-selected-item`); the Find route is a person's
  (`user-menu-from-find-results-in-folders-of-260-or-more-bytes`). From backlog item
  `user-menu-long-paths`. Probe `um280_probe` 15 / 5 -> 30 / 0 rows (15 cases; before re-measured
  with the final probe 23 / 5; negative controls: the old copy / starts, review 1's bugs, a
  selection never cleared - each fails its rows); `TestUserMenuValue280`; 226 / 229 / 234 probes
  unchanged; two refute-first reviews (no MUST; three SHOULDs fixed).
- 281-moved-aside-leftovers: a copy, a new folder (F5 / F7), Edit New File, an unpack or a plug-in's
  create to another entry's short (8.3) name moved that entry aside to `salNNN` and back; when the
  move back kept failing (another program holding it) the user's file stayed renamed with only a
  trace. Now every create route says "Error Renaming File - Path: "...\salNNN" - Error: reason"
  before its own error: an out record `CMovedAsideLeft` on `SalCreateFileEx` /
  `SalCreateDirectoryEx` / `MakeUnpackFoldersOwn` (with none - the plug-in wrappers - the create
  shows it itself, owner = a window of the calling thread); the worker through the new progress
  request 13, also after the user's own cancel, never when the program is exiting (a cancel from
  outside, `DoNotBeepOnClose`) nor in an unattended close (080). PictView and the Renamer retry
  their move back (`src/common/salmoveback.h`, 221's rule shared, saltests; the Debug seam
  `TC_PROBE_MOVE_BACK_FAIL` makes the race drivable, `contracts/probe-seam.md`). 221's worker-move
  report got the same whole-path form. Traps: the error dialog's painted name field cut a long
  path (review 1 - now `IDS_PATHERRORFORMAT` in a message box); a session end cancels workers
  before `CriticalShutdown` (review 2); a `BM_CLICK` reaches a disabled dialog's button and
  `$script:` in a `GetNewClosure()` block is another scope (probe traps). Limits: the message names
  only `salNNN`, not the entry's own name (needs a string - Inbox
  `left-aside-message-names-the-entry`); PictView and FTP / SFTP by reading (the Renamer drove the
  wrapper). From backlog item `moved-aside-restore-leftovers`. Probe `left281_probe` 8 / 6 -> 26 / 0
  (13 rows incl. a deep path, cancels, 221's routes), `ren281_probe` 4 / 0; 201 / 203 unchanged;
  two refute-first reviews (MUST 1 and two SHOULDs fixed).
- 283-mask-code-page-fold: a file mask of the form `*.xxx` with an accented extension compared the
  name's extension byte by byte through the code page (`CMaskGroup`'s extension shortcut and its
  table for ten or more such masks): `*.čtx` missed `A.ČTX` and its decomposed spelling, `|*.čtx`
  excluded nothing, and `*.ĥ` matched `x.Ĺ` on CP1250 - Convert rewrote a file the mask does not
  match (Select, filter, Find, Copy / Move and Recycle Bin masks share the group). Now an extension
  with any byte >= 0x80 is no shortcut mask: it goes through `AgreeMask` (whole letters, NFC +
  `CharLowerW`) like every other accented mask; ASCII masks keep the shortcut byte for byte
  (`src/common/salmaskopt.h` `SalMaskOptimizeKind`, saltests: the table, a 1.2 M-case differential
  against the old classification, the old fold's defects under an emulated CP1250 table, no UTF-8
  continuation byte folds to ASCII in any ANSI code page). The two other byte loops the item named
  (`AgreeMaskA`, `AgreeQSMaskAux`) are reached only by ASCII pairs - left. Limits: an ASCII `*.k`
  still does not match the Kelvin sign that `*k` matches (the matcher's own `CharLowerW` rule;
  under the file system's rule they are different names); an accented `*.xxx` costs the general
  matcher's conversions; archive associations (`PackIsArchive`) keep their 092-deferred byte fold.
  From backlog item `mask-matcher-code-page-fold`. Probe `mask283_probe` 14 / 6 -> 20 / 0 (10
  Convert cases; negative control with the rule disabled 14 / 6, saltests 11 failed); one
  refute-first review (no MUST; one SHOULD fixed; Inbox `mask-group-prepare-unbounded-mask-copy`).
- 284-share-root-parent: in the root of `\\server\share` without a Network plug-in (none ships)
  the way up did nothing - no `..` was listed (`ReadDirectory` added it to a share's root only for
  the plug-in), Backspace / Ctrl+PgUp / *Parent directory* had nothing to execute, *Go to root*
  re-opened the same root. Now the `..` is listed, and executing it, *Go to root* and *Open in
  other panel* on it hand `\\server\` to the panel's `ChangeDir` - the route of 125 (the plug-in
  test, `PickServerShare`, the wait window, the messages, the never-cut refusals). Pure rule
  `SalUncShareRootServerPath` (`saluncserver.h`). Every plug-in branch stays first and unchanged.
  Traps: at the root of an archive lying in a share's root `GetPath()` is the archive's folder -
  *Go to root* and *Open in other panel* are limited to disk panels (FR-006); the newly listed `..`
  is a drop target whose path (`GetCurrentDir`, `shellsup.cpp`) is `\\server\` - now refused (stop
  cursor) without the plug-in. Limits: holding Backspace ends at the share list; a list with no
  folder share says "A share name is missing" (125's text, no new string); middle click on that
  `..` does nothing (as at every root). From backlog item `share-root-parent-offers-share-list`.
  Probe `shareroot_probe` (seam of 125, `\\localhost\C$` -> `D$`): before 8 FAIL / 14 PASS ->
  22 / 0 (11 rows incl. Esc, error 53, no folder share, three regression controls); saltests +40;
  one refute-first review (no MUST, no SHOULD); person step `share-root-up-284-person-rows`.
- 285-share-list-sign-in: a server that lists its shares only to a signed-in user answered
  `\\server\` (Change Directory, and the way up of 284) with "(5) Access is denied" - now
  `PickServerShare` reads the list in at most two rounds: a refusal of the logon-failure class
  (`IsLogonFailureErr`, the class a full share path signs in for) gets Windows' dialog through
  `SignInToUncServerW` (drivelst.cpp: `WNetAddConnection3W(CONNECT_INTERACTIVE | CONNECT_PROMPT)`
  to `\\server\IPC$`, RESOURCETYPE_ANY, wide, not remembered; the messages of
  `RestoreNetworkConnection` for an unmapped path), then the list once more; cancel = Esc in the
  list; never a second dialog. Pure rules `SalUncShareListStep`, `SalUncSignInTarget`
  (saluncserver.h). Traps: `RestoreNetworkConnection` is ANSI (not reused); without
  `CONNECT_PROMPT` Windows may connect `IPC$` with the current identity silently while the list
  stays refused (review); Bash here-documents collapse `\\` in fix-log text (CLAUDE.md, 123) - use
  the editor. `PRIVACY.md` unchanged (claims checked true) - decision
  `should-privacy-md-name-the-sign-in-of-the-share-list-285`. Debug seam `TC_PROBE_UNC_SIGNIN` /
  `_KEEP` / `_LOG` (absent from Release). From backlog item `share-list-offers-sign-in`. Probe
  `signin_probe` (seams, `\\localhost`): before 6 rows "(5)" box, 0 sign-ins -> 20 PASS (10 rows
  incl. cancel, 1326, 1219, refused again, 53, list at once, a CJK server name); negative control
  FAILs; saltests +31; one refute-first review (no MUST; SHOULD 1 fixed, SHOULD 2 -> decision);
  person step `share-list-sign-in-285-by-hand-the-real-windows-dialog-on-a`.
- 286-folder-shortcut-browse: Browse For Folder (`GetTargetDirectory`, `shellib.cpp`: change drive >
  Network, Copy / Move / Find / user-menu / Drives browse, plug-ins) handed back a picked folder
  whose UTF-8 path needs more than 259 bytes in its CODE-PAGE form (`????...`, another folder,
  accepted silently), and a picked folder shortcut (network location) whose target needs 260+
  bytes as the shortcut folder itself - now both are refused ("The path specified is too long.",
  nothing picked, `path` written only on success); OK stays enabled for such a folder. Rule
  header-only in `salshelllink.h`: `SalIsFolderShortcutIni` (whole class id; `{}` matched
  before), `SalFolderShortcutTargetU8` (heap / `\\?\` names, target read whole, distinct
  "too long"). Traps: the Browse tree does not list a folder shortcut inside an ordinary folder
  (only network locations reach the code) and hides hidden folders like Explorer - `%TEMP%` is
  unreachable, probe fixture in `build\probe286` (`-FixtureBase`); `GetMyDocumentsOrDesktopPath`
  lost the same code-page fallback. Plug-in interface unchanged (`MAX_PATH`). From backlog item
  `folder-shortcut-browse-result-max-path`. Probe `fsc286_probe` pick-long FAIL -> PASS
  (pick-ctl PASS, fsc-* INFO); saltests +45 (real folder shortcuts; negative control 2 FAIL);
  one refute-first review (no MUST; SHOULD 1 fixed, SHOULD 2 -> Inbox); person step
  `confirm-a-network-location-with-a-long-target-is-refused-in`.
- 287-regedt-move-class-name: Registry Editor Copy / Move (F5 / F6) of a key into a key that
  already holds a key of the same name with another class name merged the contents silently
  (Move then deleted the source) - the "Class name of the key cannot be copied" question compared
  the source key with itself (`CopyOrMoveKey`, `fs5.cpp`: `SafeQueryInfoKey(sourceHKey, ...)` for
  the target, upstream since the first commit) - now the target's class is read and the question
  comes before that key's contents are copied (Cancel stops, Move keeps the key and those above it,
  All for the rest). The item's `fs3.cpp` buffer size was already fixed by 131. Limit: a question
  for a subkey leaves what was copied above it. Traps: `CStaticText` answers `WM_GETTEXT` with
  UTF-8 bytes (a wide caller gets them through the code page - reverse it to read a name; text
  recognition drops long path lines); `RegCreateKeyEx` gives the class to the parents it creates;
  PowerShell names ignore case (`$k` hid `$K`); take no fresh window list after an answer (the
  next question is already open). From backlog item `regedit-key-name-buffer-size-and-move-rows`.
  Probe `move287_probe` (Czech key names, Czech and English, 11 rows incl. Move, move into itself,
  nested Cancel / All / Yes): without the fix 19 / 11 -> 30 / 0; 129's probe 19 / 0; one
  refute-first review (no MUST; SHOULD changelog scope and the probe's name check fixed; Move onto
  itself through `HKEY_USERS\<SID>` deletes the key -> Inbox `registry-editor-move-of-a-key-onto-itself-through-hkey-users`).
- 288-ftp-per-server-encoding: 224's one process-wide set of code-page names sent new names (MKD,
  RNTO, STOR, typed paths) in UTF-8 to an FTP server whose listings speak the code page (garbled
  names) and a name seen in the code page on one server in the code page to another (UTF-8 server:
  550) - now each server (host without ASCII case, port, user; anonymous = none) has its own
  evidence and names (`CFTPServerEnc`, `ftputils.cpp`; rule header-only `salftpsrvenc.h`): a
  legacy server (code-page names only) gets new names in the code page, unknown and mixed servers
  UTF-8 (224's policy); evidence only from listing NAME fields and code-page 257 paths, no FEAT
  (decision item). Plumbing: `PrepareFTPCommand(srv, ...)` (all 55 sites, compiler-checked),
  `FTPGetDirectoryFromReply(.., srv)`, a thread-local `CFTPListingServerScope` around the parse
  loops (panel scope set before `LockServerTypeList` - critsect.txt forbids SocketCritSect inside
  ServerTypeListCS). Traps: `WideCharToMultiByte(CP_ACP, 0)` best-fits without the default flag
  (`señor` -> `senor`: an upload replaced the server's `senor.txt` silently - review 1 MUST) - now
  `SalFtpWToCodePageExact` (`WC_NO_BEST_FIT_CHARS` + round trip); a legacy server lists back the
  UTF-8 bytes of a name sent while it was unknown (made it "mixed"; and once legacy such a folder
  was unreachable in the code page - review 2) - names sent in UTF-8 are remembered per server;
  parser rules that re-assign a decoded column are no evidence; Bash here-docs collapse doubled
  backslashes in scripts too (use the editor). Limits: an unknown server gets UTF-8; one non-UTF-8 name decides; state not
  stored. From backlog item `ftp-per-server-encoding-flag`. Probe `ftp288_probe` (two ftpmini
  servers, cp1250 + UTF-8) 8 / 4 -> 20 / 0 (BF-UP, BF-MKD, ECHO, ECHO-RMD added by the reviews,
  failing on the earlier versions); negative control (224's rule) 9 / 3; 224 16 / 0, 269 14 / 0,
  277 10 / 0; saltests 25,226 / 0; two refute-first reviews (review 1: MUST best-fit + SHOULD echo fixed;
  review 2: no MUST, SHOULD fixed); person step `ftp-288-real-server-checks`.
- 289-drive-list-wide-texts: a CD / DVD label and a removable drive's name in the Change Drive
  menu and the drive bar tooltip, and the folder type name of the panel's *Type* column, were asked
  of Windows in the code page (`GetVolumeInformation` A in the CD thread, `SHGetFileInfo` A) - '?'
  for every character outside it, before the program saw the text; the drive list's own words
  (`LoadStr`: Local / Removable Drive, Compact Disc, floppies, Documents, Network, OneDrive (+
  Personal), Google Drive, Dropbox, As Other Panel, the free space) and the `..` type
  (`UpDirTypeName`) were code page in UTF-8-first sinks - now all wide / `LoadStrU8` /
  `PrintDiskSize(.., TRUE)` and UTF-8, never cut: header-only `saldrivetext.h`
  (`SAL_DRIVE_TEXT_U8_MAX` = 3 * MAX_PATH + 1, `SAL_FOLDER_TYPE_U8_MAX` = 241,
  `SalDriveNameTrimLetterSuffixW`), `FolderTypeName[241]`, `ReadCDVolNameBuffer[781]` copied
  whole (was `lstrcpyn` at MAX_PATH), menu buffers `2 * SAL_DRIVE_TEXT_U8_MAX + 100` with the '&'
  doubling bounded; no code-page retry after a failed wide call (069's precedent); the OneDrive for
  Business name is read back with `LoadStrU8(IDS_ONEDRIVE)`, the encoding it was composed with.
  Seam (Debug) of 246 extended: `TYPES`, `ALL` (whole list), `TIP` for every item. Traps: on a
  machine whose display language is in its code page nothing is visibly wrong - the probe reads
  the bytes and checks them with a strict UTF-8 decoder (the negative control: Czech "Místní
  jednotka", "Síť", "Složka souborů" in cp1250); `consts.h` changes rebuild everything (old
  C4018 / C4244 warnings show up). Left: a real CD / USB stick / display language outside the code
  page (person step `check-drive-labels-and-folder-type-names-outside-the-code`); subst targets
  (`MyQueryDosDevice` code-page fallback, `GetSubstInformation` cut) -> Inbox
  `a-subst-drive-whose-target-is-long-or-outside-the-code-page`. From backlog item
  `drive-list-code-page-texts`. Probe `run289` (English, Czech) 3 / 5 -> 8 / 0; sink-decoded texts
  before = after (210 lines); saltests 25,226 -> 25,237 / 0; one refute-first review (no MUST;
  N2 probe coverage of As Other Panel and N3 fixed; N4 -> Inbox).
- 290-zip-add-case-twins: copying or moving a file into a ZIP that holds names differing only in
  case replaced a member the user did not name - into `t.zip\d` of D/x.txt + d/y.txt (271 shows D
  and d apart) the question named `t.zip\D\x.txt` and Yes deleted it; adding a.txt beside A.txt +
  a.txt asked twice and kept only the new a.txt; in a Unix-made ZIP the first match below the
  panel's folder (A.txt) was replaced - the item's premise "Unix already matches exactly" was wrong:
  `SalZipMemberIs` compared only the panel's folder by case - now `CZipPack::MatchFiles` collects the
  members' names from the central directory it holds, asks 271's rule (`SalPathsHaveCaseTwins`,
  `salcasetwins.h`, part by part per folder as `SalDirTreeHasCaseTwins`) and, for a twin archive,
  matches folder and name exactly (`SalZipMemberIs` / `SalZipMemberIsOrIsIn` `nameIgnoreCase`,
  default TRUE); ZIPs without twins unchanged; low memory refuses before any question. Traps:
  `deflate.h` `#define Len` breaks `SalCaseTwinName::Len` (include before it, aggregate-init);
  comparing whole prefixes missed ordinal twins below a folder that is not valid WTF-8 (review);
  110's `r_3*` rows were twin archives and were re-baselined (one question, other members kept),
  duplicate-member rows `v_dupys` / `v_dupyc` keep its SF1 path driven. Limits: in a twin archive
  `B.txt` is added beside `b.txt` without a question (known change); a legacy-fold pair
  (h-circumflex / L-acute) makes the archive exact too; ~1-3 s per add into a 200,000-member ZIP.
  From backlog item `adding-a-file-into-a-zip-that-holds-names-differing-only-in`. Probe
  `zip290_probe.ps1` 6 FAIL / 12 -> 18 / 0 (negative control 6 FAIL); 110's 33 / 9 -> 44 / 0, 271's
  16 / 0, 108's 30 / 0; saltests 25,281 / 0; one refute-first review (no MUST; SHOULD 1-2
  and NOTE 6 fixed).
- 291-masks-cut-rest: the Recycle Bin masks (Configuration > System), the Find dialog's Named
  mask, the viewer's text / hex masks, the Compare Directories ignore masks and the Views list's
  in-place name read typed text into their buffers (260 bytes, the view name 30) cut at a whole
  character - Recycle Bin masks `R;*.kp` were stored as `R;*.k` (files the dropped mask named would
  be deleted permanently), also with another Recycle Bin choice; Find with `M*Q` searched `M*` and
  found `M.txt`; viewer and compare masks were stored cut (compare also with its box unchecked); 11
  CJK letters / 30 ASCII letters became a 9 / 29 letter view name - now each `Validate` refuses
  first (`DlgItemTextFitsU8`, "The path specified is too long.", no new string) and the view name
  edit refuses at its end, storing nothing. Traps: `HistoryComboBox` writes what it read back into
  the field, so Find's Add Current / Manage / Ignore (a `TransferData` without `Validate`) left a cut
  mask that passed the next Find - they refuse first now; choosing a stored option without Named
  kept the field through a cut read - its whole text is put back (`LoadControls`, taken before
  `Data` changes); `SalGetWindowTextWAlloc` is file-static in winlib. Limits: a refused view name
  is not kept (F2 again); a refused compare field may be disabled or hidden; Find's Containing, the
  external Unpack dialog's path / mask, User Menu compare names and the Change Icon file still cut
  (Inbox, `review:291`). From backlog item `masks-cut-recycle-bin-find-viewer-compare`. Probe
  `mask291_probe.ps1` 12 FAIL / 22 -> 34 / 0 (negative control: Add Current and option keep off,
  2 FAIL); 270's 24 / 0, 251's 42 / 0; saltests 25,281 / 0; one refute-first review (no MUST, no
  SHOULD; 3 NOTEs to the Inbox).
- 292-regedt-alias-move-self: the Registry Editor's Copy / Move decided "onto itself" by the root
  and the path text, so a key or value moved into the key that holds it under another root name
  (`HKCU\...` into `\HKEY_USERS\<SID>\...`, `HKCU\Software\Classes\...` into `\HKEY_CLASSES_ROOT\...`)
  was "moved" onto itself and deleted - the only copy; Copy asked to overwrite; a Move into its own
  subkey nested copies - now both checks of `CopyOrMoveFromFS` also compare identities: the full
  internal name the registry reports for the opened key (`NtQueryKey` KeyNameInformation via
  `GetProcAddress`; links followed), pure rule `src/common/salregkeyid.h` (case ignored, whole
  elements, a joined name refused when too long, never cut); no new string, the same-root messages.
  Traps: a predefined root handle cannot be queried (`RegOpenKeyExW(root, L"")` returns it) - roots
  get a fixed rule (HKLM / HKU constants, HKCU = `RegOpenCurrentUser`, HKCC = the opened
  `Hardware Profiles\Current`); HKCR is a merged view: an opened HKCR key reports one half but lists
  the subkeys and values of both and a Move deletes through it, so an HKCR path is each half that
  holds it (opened separately) - giving every HKCR path both halves refused real copies (review 1),
  the opened key alone let an elevated Move delete the machine half (review 2, MUST); a folder of
  two identities against one of them decides keys one by one and refuses values; a test comment
  ending in `\` swallowed the next line (C4010). Limits: values between HKCR and a half are refused
  even when they would reach the other half; the elevated cases and where HKCR creates a new key are
  owed to a person; Move into the key above the source's parent with a same-name subkey still loses
  data (predates, Inbox). From backlog item
  `registry-editor-move-of-a-key-onto-itself-through-hkey-users`. Probe `alias292_probe.ps1`
  18 / 9 FAIL -> 33 / 0 (English and Czech; HKCRBOTH negative control on the second version: FAIL);
  saltests 25,330 / 0 (negative control 1 failed); three refute-first reviews (one MUST, fixed).
- 293-infoline-realloc-pair: when a panel's directory line or information line (`CStatusWindow`) had
  to show a text longer than any before and memory ran out between the two `realloc` calls of
  `SetText` (`Text`, then `AlpDX`), it stored neither result, so a block that had moved left the
  window holding released memory (crash or heap corruption at the next paint, `SetText` or
  destructor) - now the growth goes through `src/common/salgrowpair.h` `SalGrowBufferPair`: each
  successful result is stored at once, the capacity rises only when both grew, a fresh block of a
  buffer that had none is released again (an uninitialized text block would have no terminator);
  the old text stays shown. Traps: the Debug core defines `_CRTDBG_MAP_ALLOC`, so the CRT overload
  calls `realloc` / `free` inside lambdas, not by address; a test that keeps using blocks after a
  failed CHECK turns a regression into a hang or crash (review SHOULD) - the cases stop early;
  restoring a header with `cp` keeps its timestamp, touch it before an incremental build. Limits: the
  low-memory case is proven by the `saltests` seam (a fake heap failing chosen calls, moving every
  block, marking released ones) and a reading proof, not on the running program; `CStaticText::SetText`
  (src/gui.cpp) and `CStatusWindow::SetSize` have similar low-memory defects (Inbox
  `a-dialog-status-text-and-the-panel-size-field-crash-when`). From backlog item
  `the-information-line-keeps-using-a-freed-text-when-memory`. No probe; saltests 25,440 / 0
  (negative control, the old rule: 13 failed); one refute-first review (no MUST, one SHOULD fixed).
- 294-regedt-move-above-parent: the Registry Editor's Copy / Move (F5 / F6) of a key into the key
  above its parent, when the key held again the chain of names from that target down to itself (in
  the simplest case a subkey of its own name: `A\K\K\K` moved as `A\K\K` into `A\`), wrote the
  innermost keys onto the moved key and Move then deleted it - their values lost without a box, also
  through `HKEY_USERS\<SID>` (upstream; review of 292) - now, after 292's identity test, the path of
  the source below a target that holds it (`SalRegKeyIdBelow`, `src/common/salregkeyid.h`) is looked
  up below the source (`SafeRegKeyHoldsPath`, heap-joined, never cut): found = the key is refused
  with the existing "Can't move/copy a key to itself." box (OK skips, Cancel stops) before anything is
  written; another open error = the existing open-error box (fails closed). A merge into the key
  above the parent without the repeated chain stays allowed (refusing every target that holds the
  source would have broken it). Traps: a Bash here-doc collapses doubled backslashes inside Python
  too (a mutation for the negative control silently did not apply - use the editor); the first run
  of 292's probe gave one "opened no dialog" flake (re-run clean). Limits: a registry link in the
  target tree pointing into the source is still followed (Inbox
  `registry-editor-move-through-a-link-in-the-target-tree`); HKCR across halves needs admin (existing
  items). From backlog item `registry-editor-move-of-a-key-into-the-key-above-its-parent`. Probe
  `above294_probe.ps1` 14 / 10 FAIL -> 24 / 0 (English and Czech); 292's probe 33 / 0; saltests
  25,458 / 0 (negative control 1 failed); one refute-first review (no MUST, no SHOULD; its scratch
  rows drove case, multi-selection and access denied).
- 295-statictext-grow-buffers: when a dialog's static text (`CStaticText` - the file name and status
  of every progress dialog, many other dialog texts, plug-ins' static texts) had to show a text longer
  than any before and a later of its up to five `realloc` calls (`Text`, `TextW`, with an ellipsis
  style `AlpDX`, `Text2`, `Text2W`) failed, `SetText` freed the earlier results - one of them the
  block `Text` still referred to - and kept `TextW` replaced: crash, double free or heap corruption at
  the next paint, `SetText` or destructor; `CStatusWindow::SetSize` wrote `Size[0]` before checking
  `malloc` - now the growth goes through a variadic form of 293's rule, `SalGrowBuffers` /
  `SalGrowBuffersWith` in `src/common/salgrowpair.h` (each buffer its element type and an `Extra`
  over the shared capacity, +3 for "..."; every growth attempted in order, each success stored at
  once, the capacity raised only when all grew, fresh blocks of a failed growth released);
  `SalGrowBufferPair` is its two-buffer case (same calls, order, sizes); `SetSize` writes only after
  the check (no size shown, retried at the next update). Traps: a Bash here-doc collapsed the
  backslashes of a fix-log replacement again (use the editor); a test that writes past blocks after
  a size regression turns it into a Debug CRT heap dialog that hangs `saltests` (review SHOULD) -
  `_msize` is checked first. Limits: proven by the `saltests` seam (feature 293's fake heap, every
  subset of five and of two calls failing) and a reading proof that `gui.cpp` passes the same buffer
  list - the seam does not run `CStaticText` itself; not on the running program. From backlog item
  `a-dialog-status-text-and-the-panel-size-field-crash-when`. No probe; saltests 26,304 / 0 (negative
  controls 77 / 95 / 18 / 70 failed, the review's old-pair-rule control 122); one refute-first review
  (no MUST, two SHOULD fixed).
- 296-regedt-link-target-tree: the Registry Editor's Copy / Move (F5 / F6, drag and drop, Quick
  Rename) of a key into a target whose tree holds a registry link (`REG_OPTION_CREATE_LINK`, makeable
  without elevation under HKCU) pointing into the source wrote through the link into the source - a
  Move then deleted what was written there (upstream; review of 294) - measured: the subkey's value
  lost without a box (also through `\HKEY_USERS\<SID>`, a link to a link, a link two levels above the
  source with the path back, a link at the second level, the HKCR view); Copy wrote into the source; a
  dangling link made the copy create keys inside the source (a top-level one an endless self-copy) -
  now the recursion (`CopyOrMoveKey`, `fs5.cpp`; wrapper + `CopyOrMoveKeyRec` carrying the operation's
  source) checks each target key before creating it: opened as a link (`REG_OPTION_OPEN_LINK`, value
  `SymbolicLinkValue` of type `REG_LINK`); a link whose target is in the source, or holds it with 294's
  chain back (`SafeRegKeyIdsReachSource`, 294's loop now shared), is refused with the existing "Can't
  move/copy a key to itself." naming the full source key (OK skips, Cancel stops); a dangling link and
  every other error get the open-error box (`ERROR_CANT_RESOLVE_FILENAME`; fails closed); other links
  are followed as before. Traps: `RegCreateKeyEx` through a dangling link creates its target; only
  the last element is opened as a link; `RegDeleteKey` / a recursive delete on a link's name deletes
  the key it points at (probe cleanup uses `REG_OPTION_OPEN_LINK` + `NtDeleteKey`; the snapshot never
  follows links); `HKCU\Software\Classes` is itself a link (to `<SID>_Classes`) and HKCR passes
  `REG_OPTION_OPEN_LINK` through; a parameter named `top` clashed with the recursion's stack index.
  Limits: decided per level, so what was copied above a refused key stays (a Move keeps its source);
  the box has no Skip All and does not name the link; a dangling link elsewhere, formerly created
  through, is refused too; the "other error" path is not driven; Delete / Move of a key holding a
  link deletes the linked key (Inbox `registry-editor-delete-or-move-deletes-a-linked-key`). From
  backlog item `registry-editor-move-through-a-link-in-the-target-tree`. Probe `link296_probe.ps1`
  14 / 15 FAIL -> 29 / 0, after the review 47 / 0 (English and Czech; negative controls: the chain
  branch off 2 FAIL, the check off 10 FAIL); 292's probe 33 / 0, 294's 24 / 0; saltests 26,304 / 0;
  one refute-first review (no MUST; SHOULD HKCR measured + row, its five scratch rows moved into the
  probe).
- 297-regedt-delete-link: the Registry Editor's Delete (F8) of a key holding a registry link
  (`REG_OPTION_CREATE_LINK`, makeable unelevated under HKCU), or of the link itself, deleted the key
  the link points at - a key never selected - and left the link ("Unable to delete a registry key.
  (5)" for its parent); Move (F6, drag and drop) and Quick Rename first copied the linked key as a
  plain key, then deleted it (upstream; found by 296) - now `DeleteKey` (`fs3.cpp`) removes a link as
  the link itself (`REG_OPTION_OPEN_LINK` + `DELETE`, re-checked on that handle, `NtDeleteKey` by
  `GetProcAddress`), a dangling one too, nothing enumerated through it; a Move's recursion
  (`CopyOrMoveKeyRec`, `fs5.cpp`) refuses a link source key before anything of it is read or written
  with the existing `IDS_REMOVESOURCE` box + `ERROR_NOT_SUPPORTED` (Retry / Skip / Skip All / Cancel;
  Skip keeps it and its parents); Copy unchanged. A link is told by identity, not by value: opened
  as a link (`KEY_ENUMERATE_SUB_KEYS`) vs. by name, another key or none = a link (292's
  `AddOpenedRegKeyId` / `SalRegKeyIdsAnySame`; `RegKeyIsLink`, also 296's target check). Traps: the
  first version read `SymbolicLinkValue` - a PLAIN key can hold that value with type `REG_LINK`
  (then undeletable / refused), a link without its value passed as plain, and `KEY_QUERY_VALUE` on
  every walked key broke Delete of a key whose child denies reading values (review SHOULD 1 / 2); the
  kernel's link flag (`KeyFlagsInformation` & 2) needs `KEY_QUERY_VALUE` too; `RegDeleteKeyW` of a
  key still holding a link subkey fails with (5); the error box's name field is read back through
  the code page in a probe (287's trap); a Bash here-doc collapsed `'\Top\'` again (use the editor).
  Limits: decided per level, so siblings moved before a refused link stay moved; the box does not
  say "link"; a selected dangling link itself is still refused by Delete's pre-check (delete its
  parent); Copy / Find through a link to an ancestor loop until the name limit (Inbox
  `registry-editor-copy-or-find-through-a-link-to-an-ancestor`). From backlog item
  `registry-editor-delete-or-move-deletes-a-linked-key`. Probe `link297_probe.ps1` 16 / 14 FAIL ->
  30 / 0, after the review 40 / 0 (English and Czech; negative controls: both link tests off 14 FAIL,
  the identity test always "no link" 15 FAIL; the review's rows on the first version: 4 FAIL); 296's probe 47 / 0, 294's 24 / 0, 292's 33 / 0;
  saltests 26,304 / 0; one refute-first review (no MUST; SHOULD 1 / 2 fixed with rows FAKEDEL,
  FAKEMOVE, ACLDEL, NOVALDEL, DELHKCRPLAIN).
- 298-mask-group-long-mask: a mask group holding one mask longer than 259 bytes overran the stack
  while it was prepared (`CMaskGroup::PrepareMasks` cut each mask into `char maskBuf[MAX_PATH]` and
  normalized it into `char buf[MAX_PATH]` without a bound) - reachable at every start through a plug-in's
  `ThumbnailMasks` registry value (read with 1001 bytes, prepared in `CPlugins::Load`: RTC "Stack memory
  corruption" at 300 bytes, a wild allocation at 1000), also a tab filter, criteria `NAMEMASKS`, plug-in
  groups and the viewer masks passed in directly (no bound at all) - now the two buffers are one heap block
  of 2 x (`strlen(group text)` + 1) bytes (freed by a local guard on every return; out of memory = FALSE,
  `errorPos` 0) and every mask is prepared whole. The cut / trim / `PrepareMask` steps moved byte for byte
  into the header `src/common/salmaskgroup.h` (`SalMaskGroupCutMask`, `SalMaskGroupTrimMask`,
  `SalPrepareMaskU8`; bytes compared unsigned = the core's `/J`); neither writes more than its input + 1, so
  the group text's length is enough; `::PrepareMask` (plug-in export) unchanged in contract. Traps: a probe's
  local `$started` hid the library's `$Started` (PowerShell names are case-insensitive); the random saltests
  rows do not see a length cut (their masks are short) - the fixed long rows do. Limits: a group stored in
  `CMaskGroup` is still cut at 1000 bytes by `SetMasksString` (plug-in contract); the Filter dialog's backup
  cut at `MAX_PATH` (Inbox `filter-dialog-cuts-a-long-panel-filter-to-259-bytes-after-a`). From backlog item
  `mask-group-prepare-unbounded-mask-copy`. Probe `mask298_probe.ps1` 4 / 4 FAIL -> 8 / 0; saltests 26,443 / 0
  (negative control: a cut at 259 bytes, 72 FAIL); one refute-first review (no MUST, no SHOULD; its own
  negative controls: an undersized heap block failed every probe row, a one-byte overrun 37 saltests FAIL).
- 299-unpack-dialog-text-fits: the Unpack dialog (Alt+F9, every unpacker - the ZIP plug-in too, not
  only external ones) read its target path and "Unpack files" mask into the caller's 260-byte
  buffers cut at a whole character (`EditLine`) - a 262-byte path (CJK, also ASCII: the path combo
  box has no limit) unpacked into the cut folder, a 260-byte mask `R;*.kp` unpacked a.k; with
  "Delete archive after unpacking" the archive was deleted although a.kp, the file the typed mask
  named, was never unpacked (measured) - now `CUnpackDialog::Validate` measures the path, then the
  mask whole (`DlgItemTextFitsU8`, MAX_PATH) and refuses ("The path specified is too long.", no new
  string); the dialog stays, nothing created or deleted. Limits: the dialog's default target (the
  other panel's path) and a plug-in's unpack mask are still cut by `lstrcpyn` before the dialog
  opens, and offered cut (Inbox `unpack-dialog-offers-a-long-target-panel-path-cut-and`, review). From
  backlog item `unpack-with-an-external-unpacker-cuts-a-long-target-path-and`. Probe
  `unpack299_probe.ps1` 4 FAIL / 12 -> 12 / 0 (negative control: the before build); 204's `f9-zip`
  2 / 0; saltests 26,443 / 0; one refute-first review (no MUST; its SHOULD - the cut default - to
  the Inbox).
- 300-volume-label-wide: Drive Information wrote a typed volume label through `SetVolumeLabel`,
  the code-page `A` call in the core (no `UNICODE`), with the UTF-8 label and volume path - `Zálohy`
  arrived as `ZĂˇlohy` on code page 1250 - and the encoding checker's `ANSI_NAME_API` list lacked the
  call. Now `CDriveInfo::Validate` converts both with `SalU8ToWAlloc` and calls `SetVolumeLabelW`; a
  failed conversion writes nothing and reports through the existing "Unable to change drive label."
  (`ERROR_NO_UNICODE_TRANSLATION` / `ERROR_NOT_ENOUGH_MEMORY`); `SetVolumeLabel` is in the list (the
  rule `ansi-api-on-utf8-path` stays report-only: it shows a returning call, `--strict` does not
  fail on it). Trap: the incremental Debug link kept `SetVolumeLabelA` in the import table after the
  last reference was gone - read the import check from a clean link (`build.cmd rebuild`). Limit:
  the label field is a code-page edit (069 note) - letters outside the code page become `?` (Inbox
  `drive-information-turns-a-volume-label-outside-the-code-page`); the real write is a person step
  (no elevation, no removable drive in the run). From backlog item
  `volume-label-written-through-ansi-api`. Import table `SetVolumeLabelA` -> only `SetVolumeLabelW`;
  checker report 40 -> 39 with negative control `checker_negative_control.py` PASS; probe
  `vol300_probe.ps1` 6 / 0 before and after (the error path, not the defect); saltests 26,443 / 0;
  one refute-first review (no MUST; S1 wording fixed, N4 to the Inbox).
- 301-subst-target-whole: a subst drive whose target folder's UTF-8 form passes 259 bytes (e.g. 80+
  CJK letters - `subst.exe` takes it) was resolved through the code-page `QueryDosDevice`
  fallback of `MyQueryDosDevice` - `?` for every letter outside the code page, spliced by
  `ResolveSubsts` into paths: F8 on a junction of such a drive asked to delete a "directory" (the
  link not recognised), Drive Information's type line was empty, Copy UNC Path / the Change Drive
  menu / the bug report used the `?` text; `GetSubstInformation` also cut with `lstrcpyn`. Now the
  device text is read whole (MAX_PATH stack buffer, then a heap buffer growing on
  `ERROR_INSUFFICIENT_BUFFER` - `DefineDosDeviceW` takes 359+ units) without any code-page call,
  and parsed by header-only `salsubst.h` (`SalSubstTargetToPathU8`: `\??\X:` / `\??\UNC\` forms,
  the size measured first, refused - never cut - when the caller's buffer is too small;
  `SAL_SUBST_TEXT_U8_MAX` = 3 * MAX_PATH + 1 holds every `subst.exe` target). `GetSubstInformation`
  gained `BOOL* tooLong`; `ResolveSubsts` (plug-in ABI unchanged) returns FALSE and leaves the
  path as it is for a refused target - Windows resolves `Z:\...` itself; Drive Information and the
  remote-drive menu text hold every `subst.exe` target, Copy UNC Path reports 101's "too long".
  **Trap (review 1, MUST)**: the refusal made the volume checks fail open - the `?` path had the
  right drive root, the unresolved `Z:\x` has no volume (`GetVolumeNameForVolumeMountPoint` fails
  up to the subst root), so a move inside the drive became copy + delete and Undelete's
  same-partition warning would be skipped; fixed with `GetSubstPathVolume` (the whole wide target +
  the rest, `GetVolumePathNameW` + `GetVolumeNameForVolumeMountPointW`, `\\?\` when long) as the
  fallback of `PathsAreOnTheSameVolume`, `HasTheSameRootPathAndVolume`,
  `GetResolvedPathMountPointAndGUID` - **only for a path `ResolveSubsts` cannot resolve and never
  after a walk that ended on a share** (review 2: `GetVolumePathNameW` does not follow a symbolic
  link to UNC - a short subst holding such a link showed the local volume). This also fixed the
  volume of targets over MAX_PATH units (0.1.10: LONG VOL / MOVE FAIL). Traps: `small` is a macro
  (`rpcndr.h`); Git Bash `sed -i` drops CRLF; Bash heredocs collapse `\\` (the probe got BEL / FF
  bytes). Left: Copy UNC Path needs the clipboard (person step
  `check-copy-full-path-as-unc-on-a-subst-drive-with-a-long-non`); Undelete's warning fails open for
  any other unreadable volume (Inbox `undelete-skips-its-same-partition-warning-when-the-target`).
  From backlog item `a-subst-drive-whose-target-is-long-or-outside-the-code-page`. Probe
  `subst_probe.ps1` 7 / 2 (first 9 rows) -> 18 / 0; installed 0.1.10 14 / 4, negative control
  (`GetSubstPathVolume` off) 14 / 4; `review2_unc_probe.ps1` 4 / 0; import `QueryDosDeviceA` gone;
  saltests 26,559 / 0 (rule negative control 4 failed); two refute-first reviews (1: M1 fixed, S1
  rows added, S2 documented; 2: no MUST, S1 fixed).
- 303-ftp-upload-case-only: an FTP upload of `B.txt` into a folder holding `b.txt` on a server
  with Unix-style paths went without the overwrite question - on a Windows-backed server
  (FileZilla Server and others store on a case-insensitive file system) its `b.txt` was replaced
  (measured with 215's `ftpmini.py` on NTFS; also `čaj.txt` over `Čaj.txt`; the decision came from
  the panel-seeded listing, `STOR` before any `LIST`) - now a listed file or link that is the same
  name case ignored (092's rule, header-only `salftpupname.h`, `SalFtpFindCaseOnlyName`) counts as
  existing when the exact lookup misses, on every path type: the question or the configured answer;
  the found copy's size is unknown (never a resume offset of another file); the file auto-rename
  skips such names. `GetListing(.., caseOnlyCounts)`: TRUE at the three file-upload callers, FALSE
  at the two folder ones (path identity, folder create / join unchanged). Trap (review, SHOULD): a
  case-only *folder* twin made "cannot create file" block the upload on a case-sensitive server
  (`BUILD` beside `build/`) - folders do not count; the probe makes a server folder case-sensitive
  with `fsutil file setCaseSensitiveInfo`. PowerShell 5.1: `$PSScriptRoot` is empty in a parameter
  default. Limits: on a case-sensitive server a case-only file twin asks once too many and a
  configured skip / auto-rename / resume applies to it; auto-rename and resume by reading only
  (person step `ftp-303-on-real-servers-an-upload-of-b-txt-beside-b-txt-asks`). From backlog item
  `ftp-an-upload-to-a-case-insensitive-server-with-unix-paths`. Probe `ftp303_probe.ps1` 5 / 3 ->
  12 / 0 (reviewer's negative control: the start check off -> 5 / 3); 288 20 / 0, 224 16 / 0;
  saltests 26,577 / 0 (negative controls: no match 7 failed, ASCII fold 2 failed); one
  refute-first review (no MUST; SHOULD 1 fixed, NOTEs recorded).
- 304-plugin-picker-shortcut-cut: the plug-ins' folder picker (`SplBrowseForFolderU8`, PictView /
  UnCAB / Undelete) followed a picked network location (folder shortcut) whose target has 260+
  units to a CUT path - measured: on a volume without 8.3 names `IShellLinkW::GetPath` answers
  NOERROR with exactly 259 units (`\\?\D:\...` cut mid-name) whatever the buffer (a 32,768-unit
  buffer alone does not help); with 8.3 names it answers the short form (whole) - now an answer
  of 259+ units is followed only when the link's item list (`GetIDList` +
  `SHGetNameFromIDList(SIGDN_FILESYSPATH)`) proves it whole (equal, or the answer begins the
  longer name - then that name, plain form), otherwise refused with the existing "too long"
  message (`splfiledlg.h` `WholeFolderShortcutTargetW` pure, `LinkTargetWholeW` the link part,
  `ResolveNetHoodFolderW(path, &refused)`). Traps: `IShellLinkW::SetPath` refuses 260+ units and
  `SHParseDisplayName` of a long path gives the 8.3 form - a test link needs an item list built
  folder by folder; the cut shows only on a volume without 8.3 names (the build folder here, not
  `%TEMP%`); the shell rebuilds an item list for a link saved without one, so the refusal is
  driven by a fake `IShellLinkW`. Left: the core's `SalShellLinkGetPathU8` takes the same cut
  answer (Inbox `a-shortcut-whose-target-path-has-260-or-more-characters-is`); the real dialog
  (person step `check-the-plug-in-folder-picker-with-a-long-target-network`). From backlog item
  `plug-in-folder-picker-may-cut-a-folder-shortcut-target-of`. Measurement `probe/measure3.cpp`
  on D: 4 of 4 cut -> 0 of 4; saltests 26,701 / 0 (negative controls: answer taken as it is 18
  failed, refusal flag off 3 failed); one refute-first review (no MUST; SHOULD 1-2 fixed, NOTEs
  recorded).
- 305-core-shortcut-target-cut: a shortcut (`.lnk`) whose target has 260 or more characters on a
  volume without 8.3 names was followed to a cut path - Enter and Go to Shortcut Target showed an
  error or, with the cut on a backslash, silently opened the target's parent folder; a drop onto
  the shortcut and Browse on such a network location took the cut path too - now the core's one
  reader (`salshelllink.h` `SalShellLinkGetPathU8`) returns the whole target, proven by the link's
  item list (`SalShellLinkWholeTargetW`, the core twin of 304's rule; plain form), or refuses with
  `ERROR_FILENAME_EXCED_RANGE`, which `SalFolderShortcutTargetU8` (loaded-link part
  `SalFolderShortcutLinkTargetU8`) passes on as feature 286's "too long". Traps: after
  `IShellLink::Resolve` (both panel callers resolve) the cut is 259 PLAIN units (`E:\...`), before
  it `\\?\` + 255 - a "cut on a backslash" fixture needs a 259-character parent; `SLGP_RAWPATH` is
  refused from 259 units without the item list (environment strings), also a whole 259; a whole
  UNC answer of exactly 259 units (mapped drive) is refused - fail closed; the probe fixture lives
  in the build folder (no 8.3 names), not `%TEMP%`. Left: the Network plug-in's own `target.lnk`
  read (Inbox `network-plug-in-follows-a-network-shortcut-to-a-cut-target`); drop and Browse in the
  real UI (person step `check-a-drop-onto-a-long-target-shortcut-and-browse-on-a`). From backlog
  item `a-shortcut-whose-target-path-has-260-or-more-characters-is`. Probe `lnk305_probe.ps1`
  PASS 6 / FAIL 4 -> PASS 10 / FAIL 0; `measure_core.cpp` on D: 4 of 4 cut -> 0 of 4; saltests
  27,046 / 0 (negative controls: rule returning the answer 84 failed, raw-path refusal off 13,
  pass-through off 3); one refute-first review (no MUST; SHOULD 1 fixed, SHOULD 2 accepted, NOTEs
  recorded).
- 306-tar-pax-headers: TAR archives written by Python's `tarfile`, GNU tar `--format=posix` or
  Windows `tar.exe` listed and extracted the ustar fallback of long or non-ASCII names - a 302-byte
  path ended in a folder cut at 100 bytes, CJK names (100 `?`) failed with "(123) invalid name",
  twins collided, a PAX `size` (8 GiB+) was ignored and the data read as a header, PAX / global
  times ignored - because `ReadTarHeader` skipped `x` / `g` headers - now their records are parsed
  (`src/common/salpaxheader.h`, header-only, saltests): `path`, `size`, `mtime` (100 ns), the
  member's own values over the global ones (reset at the first header of every pass), an empty
  value cancels; a malformed or 1 MiB+ header refuses the archive (`IDS_TARERR_HEADER`), a bad mtime
  is ignored. A PAX name the listing cannot hold is refused alone (`SalPaxNameFitsListingU8`: a
  component over 255 UTF-16 units, a folder part or folder name over `MAX_PATH - 5` bytes counting
  the .deb's `control\` / `data\` prefix) with the system's "(206)" text and the path, once per
  listing / whole-archive unpack. Traps: measured first - a GNU long name with a 300-letter component
  crashes the core on opening ("Stack memory corruption" under `CommonRefresh`; the same with the
  PAX refusal disabled), so the refusal is required; `AddFile` / `AddDir` failing ends the WHOLE
  listing (review 1 MUST - deep PAX paths made archives unopenable that 0.1.10 opened); the .deb
  prefix (review 2); `ShowMessageBox` is a UTF-8 sink (`LoadStrU8`); trap 123 twice in Bash
  here-documents; a probe variable `$rows` replaced the library's `$Rows`. Limits: only the first
  refused member is named; an archive cut right after an extended header no longer opens; links and
  GNU sparse files unchanged; Inbox `opening-a-tar-whose-member-name-has-a-300-letter-component`
  (the GNU crash and the GNU deep-path listing failure). From backlog item
  `tar-plug-in-ignores-pax-extended-headers`. Probe `pax306_probe.ps1` 13 / 9 -> 28 / 0 (negative
  controls: PAX branch off 12 / 8, refusal off - crash, listing checks off 5 / 3); 252, 273, 275
  probes unchanged; saltests 27,152 / 0; two refute-first reviews (review 1 one MUST + one SHOULD,
  fixed; review 2 one SHOULD and two NOTEs fixed).
- 308-pax-deep-unpack: unpacking a whole PAX tar (Alt+F9) silently left out every member whose folder
  path was longer than 255 bytes (a deep source tree, `node_modules`) and still succeeded, so "Delete
  archive after unpacking" deleted the archive with them; a member with a name over 255 characters let
  it be deleted too - now the listing's bound applies only while the panel listing is built
  (`SalPaxNameUsableU8`, `salpaxheader.h`; `CArchive::Listing`), every extraction (Unpack, Copy of a
  folder, one file) takes every member a file system takes, and a member it was asked for that no file
  system takes is named ("(206)") and fails the operation after the rest is extracted - the core then
  keeps the archive. Traps: 306's probe row PAX-DEB had encoded the omission (Copy of `data` now brings
  the deep member - expectation updated); only the first refused member is named; a symlink with a
  too-long name fails the unpack too (safe side); paths over ~32,767 characters reach the core's
  Retry / Skip box (Skip = success, the user's choice). GNU long names: the same rule is owed by
  branch 307 (logged on its item); hard / symbolic links are still dropped silently - Inbox
  `tar-unpack-drops-hard-links-and-deletes-archive`. From backlog item
  `whole-archive-unpack-of-a-pax-tar-skips-deep-members-and-may`. Probe `unp308_probe.ps1` 5 / 5 ->
  12 / 0 (negative controls: listing bound in extraction + result ignored 7 / 5, report removed 4 / 2);
  306 probe 28 / 0, 252 / 273 / 275 unchanged; saltests 27,170 / 0; one refute-first review (two
  SHOULDs fixed, five NOTEs).

- 309-tar-link-members: unpacking a tar (Alt+F9, or Copy of a folder from the opened archive) left out
  every hard-link member (GNU tar / Python store a file's second name as a link to the first) and every
  symbolic link without a word and still succeeded, so "Delete archive after unpacking" deleted the
  archive with them - now a hard link whose target this operation wrote is extracted as a copy of it
  (`WriteOutLinkCopy`: through `SafeFileCreate`, the source opened read / share-read only, an existing
  destination that is the source by identity - `salsamefile.h` - is not written), and every other link
  asked for (symbolic, target not written / outside the selection / skipped / with a `..` component) is
  named once per operation ("(2)" / "(50)" system text + `name -> link name`) and fails the operation
  after the rest is extracted - the core keeps the archive. Link names: PAX `linkpath`
  (`salpaxheader.h`) > GNU 'K' long link name (was read and discarded) > ustar `linkname`, decoded and
  normalized like member names (the loop moved unchanged into `saltarlink.h`, `SalTarNormalizeNameU8`;
  `SalTarLinkDecide`). Traps: the legacy normalization resolves `..` wrongly (`sub/../a.txt` becomes
  `s` + `a.txt`) - review 1 showed a link silently copying the wrong file, so link names with `..` are
  never matched (member names keep the rule - Inbox `tar-member-name-with-dotdot-extracted-into-wrong-folder`);
  a Bash here-document collapsed the test escapes (123). Limits: symbolic links are never created, so a
  whole Unpack of a Linux tarball / `.deb` with symlinks now ends as failed (files extracted the same);
  link members are still not listed - copying the files shown in a folder leaves hard links out (Inbox
  `tar-copy-of-listed-files-leaves-hard-links-out`); cpio links unchanged (Inbox
  `cpio-unpack-drops-links-and-may-delete-archive`); no progress / Cancel during one copy. From backlog
  item `tar-unpack-drops-hard-links-and-deletes-archive`. Probe `link309_probe.ps1` 8 / 6 -> 16 / 0
  (negative controls: refusal ignored + copy disabled 7 / 7, identity check removed - the share-read
  guard still kept a.txt); 308 probe 12 / 0, 306 probe 28 / 0; saltests 27,211 / 0; one refute-first
  review (one SHOULD fixed, two to Inbox / CHANGELOG, six NOTEs).
- 310-cpio-link-members: unpacking a cpio or an rpm (Alt+F9, Copy from the opened archive, F3) wrote the
  names of a hard-linked file that the newc / crc format stores with size 0 (GNU cpio, rpm, libarchive put
  the data with the last name) as empty files, and skipped symbolic links without a word - both ended as
  successful, so "Delete archive after unpacking" deleted the archive - now `ReadNewASCIIHeader` reads
  `c_ino`, `c_nlink` and the device (silently: a non-hex field leaves the member ungrouped, never refuses
  the archive), an extraction groups the names of one file by (device, inode) and acts by
  `SalCpioLinkDecide` (`src/common/salcpiolink.h`, header-only, saltests): a name stored with size 0
  waits for the data, is copied from the written file (309's `WriteOutLinkCopy`, identity check), gets
  the data when the data member itself is not asked for, or - the data passed unwritten (not asked, Skip)
  - is reported ("(2)", `name -> data name`) and fails the operation; a file no name carried data for is
  written empty at the trailer. A cpio symlink (any cpio format) gets `SYMTYPE` and its target read from
  its data (1..4096 bytes, counted for the padding) so 309's code reports it ("(50)"). `UnpackOneFile`
  reads on to the data member. Traps: `UnpackOneFile`'s target name lives in the header the next
  `ReadArchiveHeader` frees (copied first); `TxtToLong` would have refused archives with odd fields the
  reader never needed; a Bash here-document would have collapsed the rpm fixture's escapes (123 - the
  merge script was written with the editor). Limits: the data stored with an EARLIER name and only a
  later name asked (copy of that name, F3) is reported, not shown; the listing still shows size 0 for
  such names and no symlinks; symlinks never created (a whole Unpack of an rpm with symlinks ends as
  failed); odc / binary unchanged (they repeat the data). From backlog item
  `cpio-unpack-drops-links-and-may-delete-archive`. Probe `cpio310_probe.ps1` 13 / 7 -> 52 / 0 (26 rows
  with review 1's rpm, padding, case-twin, Skip / Yes and data-first rows; negative control grouping +
  symlink type off 17 / 9; review's control empty-name pass + padding off failed its rows); 309 probe
  16 / 0, 308 12 / 0, 306 28 / 0; saltests 27,237 / 0; one refute-first review (no MUST, two SHOULDs
  fixed - spec wording and probe rows -, five NOTEs).
- 311-find-containing-cut: the Find dialog's Containing text (200 UTF-16 units, read into 201 bytes) was
  cut at a whole character when its UTF-8 form was longer - 67 CJK letters searched as 66 and found files
  without the typed text (`cut.txt` holding only the 66 letters), in plain, regular-expression and hex
  mode; Find wrote the cut text back into the field and its history, Options > Add Current / Manage /
  Ignore did the same, a stored option without Containing left the field cut; the viewer's own Find
  (`FIND_TEXT_LEN`) searched a cut text too, and viewing a found file copied a cut Containing into the
  viewer's Find (`UpdateInternalViewerData`, core `CTransferInfo::EditLine` cuts) - now
  `CFindDialog::Validate` and the three Options commands refuse after 291's Named check
  (`DlgItemTextFitsU8`, "The path specified is too long.", no new string), `LoadControls` keeps the
  field's whole text as 291 keeps Named (also counted for expanding the dialog), the copy into the viewer
  is skipped when the text does not fit (the viewer keeps its text), and `CFindSetDialog` got a
  `Validate` with the same refusal. Traps: F3 on `.txt` opens the Code Viewer plug-in - the viewer rows
  use Alt+F3 and assert the window class; a Bash here-document collapsed the probe's backslashes (123 -
  rewritten with the editor). Limits: the viewer's Find pre-fills a selection through an ANSI
  `WM_SETTEXT`, so a long non-ASCII selection is now refused (it was searched as mojibake before) and
  hex mode's `DoHexValidation` turns quoted letters outside the code page into `?` (Inbox,
  `review:311`); the message says "path" for search text (291's precedent). From backlog item
  `find-cuts-a-long-containing-text-and-writes-the-cut-text`. Probe `grep311_probe.ps1` 9 FAIL / 13 ->
  26 / 0 (13 rows; negative control Validate checks off 5 FAIL; review's control every guard off failed
  its rows); 291's probe 34 / 0, 251's 42 / 0; saltests 27,237 / 0; one refute-first review (no MUST,
  two SHOULDs to the Inbox, a `view-copy-keep` row added).
- 313-quick-search-diacritics: quick search in the new mode (244) ignored case but not accents -
  `zlut` did not find the folder `žluťoučký`, `cesky` stuck at `c` and never reached `Český.txt`,
  `žlut` did not find `zlutý` - now the keys of `salquickfilter.h` drop the nonspacing marks of the
  Latin/Greek/Cyrillic diacritic blocks (U+0300-036F, 1AB0-1AFF, 1DC0-1DFF, 20D0-20FF, FE20-FE2F;
  enclosing marks such as the keycap and the negation stroke U+0338 stay) after NFD + lower case, in names and typed text alike,
  and fold `ł ø đ ß ẞ æ œ ı` (and capitals) to `l o d ss ss ae oe i`. A mark-only character has an
  empty key (cache marker `SALQF_KEY_EMPTY`, `CharKey` -1 = no room), a mask segment of marks only is
  not stored; `Starts` = 2 marks a later unit of a folded letter, where a match may end
  (`KeyEndOffset` reports the whole letter); Left/Backspace of the new mode remove a letter with its
  ignored marks, and a text of ignored marks only ends the search (`SalQFCutLastLetter`,
  `SalQFOnlyIgnoredMarks`); Right after a text ending inside a folded letter goes on with the
  matched part of the name. Traps: the refusal of a keystroke that leaves no match means
  every partial text must match - "a match covers a folded letter whole" made `strasse` stick at
  `stra` (review 1; the first probe row could not tell the builds apart, a distractor `Strand.txt`
  can); dropping marks moves the match end behind them, so Left removing one code point removed only
  the invisible mark and stuck (review 1); with the end moved behind a folded letter, Right appended
  the next character to `stras` -> `strase` and was refused (review 2); U+0338 is a Mn of the block
  but negates symbols (`≠` -> `=`), so it stays; a plain `build.cmd` does not relink saltests after a
  header-only change - touch `saltests.cpp` for a negative control; PowerShell variable names ignore
  case (`$exp` vs `[hashtable]$Exp`). Limits: marks of other scripts (Japanese voiced mark, Hebrew
  points, Indic signs) still count; `ð þ ħ` not folded; Cyrillic `й`/`и` and similar fold (the
  maintainer's symmetric decision); the option-off 0.1.10 rule is unchanged (accents count); M3
  compares the 229 folded pairs with 0.1.10 only as a superset. From backlog item
  `quick-search-ignores-diacritics`. Probe `qs313_probe.ps1` before: D01/D03 show the defect -> after
  32 rows / 0 FAIL (D12-D15 added by review 1, D16 by review 2; D12 measured on the baseline
  {Strand, Straße} -> {Straße}; negative control Right fallback off D16 FAIL); option off identical;
  244 probe 45 / 0 in both modes, identical to its records;
  Release A/B against the baseline build: no measurable change; saltests 27,401 / 0 (55 folding
  cases; negative controls 24 and 7 failed checks); two refute-first reviews (round 1: a MUST and
  two SHOULDs fixed; round 2: no MUST, a SHOULD fixed, the dot tolerance after a typed mark
  recorded). Person step `quick-search-ignoring-accents-check-with-a-real-keyboard`.
- 315-unpack-default-whole: the Unpack dialog (Alt+F9) filled its target with the other panel's
  path cut to 259 bytes (`lstrcpyn`, possibly inside a UTF-8 letter - a CJK cut showed as garbage);
  the cut fitted, so 299's `Validate` accepted it and one Enter (with "Use the other panel for
  unpacking") unpacked into a new folder named after the cut component; with "Use the archive name
  as a subfolder" a path + name that did not fit was offered bare (files straight into the other
  panel's folder); an empty target became the archive panel's path cut the same way (measured: a
  new cut folder). Now `salunpackdefault.h`: a default is offered whole or left out (the entry stays
  empty, as for a non-disk panel), a subfolder that does not fit leaves the path out and offers the
  archive's name alone (a subfolder next to the archive), a plug-in's unpack mask whole or `*.*`, and
  the empty target is refused ("The path specified is too long.", the dialog again) when the archive
  folder - or, with the subfolder setting, the archive's name alone - does not fit. Limits: with "Use
  the other panel" on and a long other panel the one entry is the empty one - Enter unpacks next to
  the archive (the item's choice; overwrite questions still asked); the plug-in mask is not driven
  (no plug-in of the tree passes one); a leading space of the archive name is lost in the subfolder
  (Inbox `unpack-into-a-subfolder-named-after-an-archive-whose-name`, review). Trap: PowerShell's
  `@($a + 'x', $b + 'y')` - the comma binds before `+`. From backlog item
  `unpack-dialog-offers-a-long-target-panel-path-cut-and`. Probe `unpack315_probe.ps1` 6 FAIL / 9 ->
  11 / 0 (negative control: the build of main); 299's probe 12 / 0; saltests 27,440 / 0 (negative
  controls 8 and 1 failed); one refute-first review (no MUST; SHOULD 1 - a subfolder name too long
  alone unpacked without it - fixed, SHOULD 2 accepted as the item's choice, a NOTE to the Inbox).
- 316-unpack-subdir-space: with "Use the archive name as a subfolder" the Unpack dialog (Alt+F9)
  offered ` ssss` for an archive ` ssss.zip`, but OK unpacked into `ssss` - another folder, an
  existing `ssss` merged into (also when ` ssss` existed; a typed ` typed` the same): `SalGetFullName`
  drops the leading spaces of a relative name unless `allowRelPathWithSpaces`. Now `CFilesWindow::Unpack`
  passes TRUE (as `SalParsePath` for Copy/Move): an existing ` ssss` is unpacked into, a new one is
  refused by the existing create rule (`CheckAndCreateDirectory`, `manualCrDir`: "Error Creating
  Directory", invalid name, the dialog again) - the refusal the absolute entry `<other panel>\ ssss`
  already got. Limits: the dialog's own offer is refused (edit the entry); the Pack dialog has the
  same trimming (Inbox `pack-with-a-relative-archive-name-that-starts-with-a-space`, not measured).
  Trap: `' ..'` (archive `' ...zip'`) trimmed to `..` meant the parent folder (review, read) - now refused. From
  backlog item `unpack-into-a-subfolder-named-after-an-archive-whose-name`. Probe
  `unpack316_probe.ps1` 6 FAIL / 12 -> 18 / 0 (negative control: the build of main); 315's probe
  22 / 0; saltests 27,440 / 0; one refute-first review (no MUST, no SHOULD; its scratch rows with
  dots and tabs all refused, nothing written).
- 317-pack-name-space: the Pack dialog (Alt+F5) offered ` report.zip` for an item ` report`, but OK
  packed into `report.zip` - another archive; an existing `report.zip` got the "add or overwrite?"
  question and was changed by Add / Overwrite (a typed ` typed.zip` the same): `SalGetFullName`
  drops the leading spaces of a relative name. Now `CFilesWindow::Pack` passes
  `allowRelPathWithSpaces = TRUE` (as 316 for Unpack): ` report.zip` is created or, existing, asked
  about and added to / overwritten; `report.zip` is untouched. Trap: kept as typed, ` ..` / ` .` are
  not resolved to a folder - the ZIP plug-in opens archives through `\\?\` and created files
  literally named ` ..` / ` .` (planning expected Win32 trimming; measured otherwise) - so a last
  part of spaces and dots only is refused through the existing error path (`IDS_PATHISINVALID`,
  `SalPackNameIsOnlyDotsAndSpaces`, `src/common/salpackname.h`, also for absolute names). Limits:
  `   ` packs into `   .zip`; ` ..\x.zip` and a leading tab now fail in the packer (nothing written);
  names ending in a dot / space or device names are still written literally (Inbox
  `pack-archive-name-trailing-dot-or-space`). From backlog item
  `pack-with-a-relative-archive-name-that-starts-with-a-space`. Probe `pack317_probe.ps1` 11 FAIL /
  17 -> 28 / 0 (negative control: `main`'s Pack code); 316's probe 18 / 0, 241's 8 / 0; saltests
  27,456 / 0; one refute-first review (no MUST; SHOULD - the Inbox item - fixed; 13 scratch names
  with dots, tabs and slashes: nothing written).
- 318-pack-name-trailing-dot: the Pack dialog (Alt+F5) created an archive whose name ended in a dot
  or a space (`report.`, `report.zip `, also absolute) literally - the ZIP plug-in writes through
  `\\?\`, so Windows did not trim it - and Explorer / plain paths could not open or delete it; device
  names (`CON.zip`, `con` -> `con.zip`, `NUL .zip`, `COM1.zip`, `lpt9.tar.zip`) were created too.
  Now a last part that ends in `.` / ` ` or is a reserved device name (CON, PRN, AUX, NUL, COM0-9,
  LPT0-9, COM/LPT + superscript 1-3, before the first dot, trailing spaces ignored, any case) is
  refused through 317's path (`IDS_PATHISINVALID`, the dialog again) - `SalPackNameIsNotKeptAsTyped`
  in `src/common/salpackname.h` replaces 317's `SalPackNameIsOnlyDotsAndSpaces` (a subset); the last
  part starts after `\` or `/`. Traps: on Windows 11 a device name with an extension is an ordinary
  file (measured: plain paths open `CON.zip`) - refused because the item names it; the first fix also
  blocked adding to an existing `aux.zip` / literal `report.` (review) - now refused only when
  `FileExists` (through `\\?\`, no trimming: `report` never stands for `report.`) finds no file of
  that name. Limits: a folder part is not checked (the ZIP plug-in refuses `CON\a.zip` itself); a
  colon writes the archive into an alternate data stream (Inbox
  `pack-writes-the-archive-into-a-hidden-data-stream-when-its`). From backlog item
  `pack-archive-name-trailing-dot-or-space`. Probe `pack318_probe.ps1` 12 FAIL / 30 -> 52 / 0
  (control of the review rows on the first fix: 4 FAIL); 317's probe 28 / 0; saltests 27,508 / 0
  (negative control: the device part disabled -> 18 failed); one refute-first review (no MUST; SHOULD
  existing archives and NOTE `/` fixed).
- 319-pack-name-colon: an archive name typed in the Pack dialog (Alt+F5) with a colon in it
  (`report:zip`, `rep:x.zip`, also absolute) created an empty file `report` / `rep` and wrote the
  archive into its NTFS alternate data stream (`report:zip.zip`) - invisible to Explorer and the
  panel; with an existing `report` the stream was attached to it, and Add into an existing stream
  archive failed ("Archive was not changed.") yet changed the stream and left a `Sal*.tmp`. Now a
  last part holding `:` is refused - `SalPackNameHasStreamColon` in `src/common/salpackname.h` (a
  drive prefix `X:` skipped, the last part after `\` or `/`), checked with 318's rule after
  `SalGetFullName` through `IDS_PATHISINVALID`, the dialog again - **unconditionally** (not gated by
  `FileExists` like 318's: a stream is never a file the panel shows). Traps: 318's probe snapshot
  (`Directory.GetFiles`) cannot see a stream - 319's lists streams (`FindFirstStreamW`) and hashes
  them through `CreateFileW`; a Bash heredoc collapsed `'\\'` in the new rule (build failed, fixed
  with the editor); `Copy-Item` restoring the negative-control header kept its old time stamp, so
  MSBuild did not recompile (that probe run became the probe's negative control). Limits: a colon in
  a folder part (`sub:x\a.zip`) is left to the packer, which refuses it; the ZIP plug-in's false
  "Archive was not changed." is Inbox `zip-says-the-archive-was-not-changed-after-a-failed-replace`.
  From backlog item `pack-writes-the-archive-into-a-hidden-data-stream-when-its`. Probe
  `pack319_probe.ps1` 6 FAIL / 18 -> 42 / 0 (with the review's 9 rows; negative-control binary 6 FAIL);
  318's probe 52 / 0; saltests 27,540 / 0 (negative control: the rule off -> 18 failed); one
  refute-first review (no MUST, no SHOULD; its call-site negative control failed 4 of 5 rows; its rows
  adopted).
- 320-zip-failed-replace: the ZIP plug-in (default "create temporary backup of zip") put a changed
  archive in place by deleting it and renaming its `Sal*.tmp` over it. With the archive open in another
  program without delete sharing, adding files to it or deleting members from it said "Cannot replace
  original archive with temporary working file. Archive was not changed." (true) but left the
  `Sal*.tmp` in the folder; with the temporary file held instead (an antivirus on the new file) or an
  archive in a data stream (319), the delete succeeded, the rename failed, and the archive was GONE
  under the same "not changed" message. Now both sites (`PackNormal`, `DeleteFromArchive`) call
  `CZipPack::ReplaceArchiveWithTemp` -> `SalReplaceWithTempW` (105): one ReplaceFileW step; kept ->
  the temporary file deleted and the message true; archive vanished -> the temporary file kept and
  named (`IDS_ERRCREATE`, no new string). Traps: ReplaceFileW copies the target's named streams
  (Zone.Identifier) into the new file, which moves its last-write time - "set zip file time to the
  newest file time" is applied again after the replace (measured; saltests prints it, does not pin
  it); PowerShell passes `$null` as "" to a P/Invoke string (use `[NullString]::Value`). Limits: an
  archive behind a file symbolic link now fails safe (1464) instead of the link becoming a plain file
  (Inbox `zip-cannot-update-an-archive-reached-through-a-symbolic-link`); the "only copy" case does not
  say so (Inbox `zip-does-not-say-the-temporary-file-is-the-only-copy`); a held temporary file cannot
  be deleted and may remain. From backlog item `zip-says-the-archive-was-not-changed-after-a-failed-replace`.
  Probe `zipreplace_probe.ps1` 2 FAIL / 10 -> 12 / 0 (add-locked, del-locked); saltests 27,558 / 0
  (`TestSafeReplace320`); review 1 killed without a report (its probe left the registry changed -
  person step `restore-registry-after-killed-probe-320`); review 2 refute-first: no MUST, 2 SHOULD
  (-> Inbox), NOTE 4 fixed.
- 314-mdview-page-width: the Markdown Viewer kept every document in a 46rem column (about 736 px,
  80-90 characters a line) - a wider window only added margins, wide tables and code scrolled
  inside the column, zoom scaled both - now View > Page Width (after Color Scheme) offers Normal
  46rem (the default, the page of before byte for byte apart from two added CSS rules), Wide
  64rem, Wider 90rem, Full Window (no limit, the padding stays), radio-checked, applied at once
  (also in View Source) and stored as `PageWidth` 0-3 beside `ZoomPercent` (unknown -> Normal).
  The width is per window; a choice also sets the stored level, even when it is the window's
  own (review 1: two windows). Traps: a rebuild opens the page at the top (scripts off, no scroll
  API in the shared host - a scheme change does the same; Inbox item); PrintWindow
  (PW_RENDERFULLCONTENT) does capture the WebView2 page on the hidden desktop - the probe measures
  the text column (681 / 968 / 1385 / 2228 px in a 2284 px client); a wrong-typed value shows the
  core's "Unexpected value type." box; the 081 `mdview_probe.ps1` fails its first view on the
  hidden desktop on HEAD as well (Inbox). From backlog item `mdview-page-width-levels`. Probe
  `pw314_probe` 5/5 FAIL before -> 16/0; harness 38 -> 53/0 (negative controls fail); one
  refute-first review (no MUST; S1 fixed). Blocked only for the `.slt` refresh; finished in a
  maintainer session after merging `main`: 5 strings x 8 languages, 288 DeepL characters, 11 pins
  (meaning and gender of the width levels; Zoom Out was "Zoom In" in de and ro).
- 312-tabs-browser-keys: panel tabs had only Chrome's keys with Shift added, a closed tab was lost
  and the tab settings were one Appearance checkbox - now Configuration > Tabs (after Appearance)
  holds *Show tabs in panels*, an opt-in *Browser-like tab shortcuts* (Ctrl+T / Ctrl+W /
  Ctrl+PgDn / PgUp for tabs, Ctrl+Shift+T Reopen, Ctrl+Shift+W Restore Selection, Ctrl+Shift+G Go
  to Shortcut; panel and command line; classic keys unchanged by default) and a list that follows
  the option; Reopen Closed Tab (10 per panel, memory only, the `CPanelTab` object itself with its
  history, emptied by tabs off and Clear History); Tabs in Options > Show and the toolbar menu.
  One pure key table in `saltabs.*` drives dispatch, labels (`LoadStrTabKeys`) and the page. Traps:
  the command line never ran the Ctrl+letter handler (classic Ctrl+T/W do nothing there - kept);
  `IsSalHotKey` also clears plug-in keys at load (`IsSalHotKeyKeptAtLoad` keeps Ctrl+Shift+G);
  closed tabs' histories hold plug-in FS pointers (`ClearPluginFSFromHistory` walks them); the
  page order is the remembered page index (`SalCfgPageIndexFrom311` when the new value is absent).
  From backlog item `panel-tabs-chrome-shortcuts-and-reopen-closed-tab`. Probe `tabs312_probe`
  33 PASS (new feature, classic rows as control); saltests +106; review 1 no MUST, 2 SHOULD fixed.
  Blocked only for the `.slt` refresh; finished in a maintainer session after merging `main`
  (review of the merge with 313's quick-search keys: no MUST): 10 entries x 8 languages, 1,832
  DeepL characters, 24 pins ("Tabs" was the Tab key in de / fr / hu / sk; cs "karty", hu
  "lap"; menu accelerators checked by script - the core's menus are built from strings); probe
  after the merge 33/0.
- 321-tar-long-component: opening a TAR whose GNU long name has a component of 300 CJK letters
  closed the program ("Stack memory corruption" under `CommonRefresh`), and a GNU name deeper than
  the panel listing made the whole archive unopenable - now GNU long names get exactly the PAX
  rule of 306 / 308 (`NameFromGnu`; `SalPaxNameUsableU8(..., Listing)`: the listing bound only
  while listing, the over-255-unit component in every pass, an extraction asked for a refused
  member reports it and fails); the core refuses an entry with no folder part (`path == NULL`:
  archive roots, every FS plug-in) of 780+ bytes (`sallistingname.h`, `AddFile` / `AddDir`), and
  the simple-icons extension copies in `fileswn3.cpp` are bounded. A top-level folder name is no
  longer byte-bounded while listing (0.1.10 behaviour; PAX too). Traps: the first run (307) put
  the listing bound into every pass - review 2 measured deep members lost in Unpack and the
  archive deleted; carried over onto 308-310 (the GNU branch writes through `char** longName`),
  the `saltests.cpp` merge lost a closing brace. Limits: such a folder over 255 bytes cannot be
  entered (as 0.1.10); a cpio / rpm root name of 780+ bytes refuses the whole archive (Inbox); the
  "(206)" text also names members only too deep for the listing (306 / 308). From backlog item
  `opening-a-tar-whose-member-name-has-a-300-letter-component`. Probe `tar321_probe` 12/8 ->
  20/0, `unp321_probe` (308's in GNU format) 9/3 -> 12/0; 306 30/0 (GNU-TOOLONG now in its
  default run; PAX-255DIR and 308's COPY-DEEP expect the listed folder's member), 308 12/0, 309
  16/0, 310 52/0; negative controls (listing rule in every pass; GNU flag off; + core bound off)
  fail as expected; saltests 27698; one refute-first review (no MUST / SHOULD).
- 322-uniso-hfs-btree-joliet: the ISO plug-in's HFS+ catalog walk took the node size, the first
  leaf node, the links, record counts and record offsets from the image and read wherever they
  pointed (a link back never ended); the listing read keys and records past their node; a Joliet
  file name of mostly CJK letters lost its end (`.txt`, or broke inside a letter into mojibake) -
  now the walk (`src/common/salhfscatalog.h`) uses a node only inside the loaded catalog and once,
  record tables and offsets only inside their node, and refuses a damaged catalog with a new
  message (quietly in a hybrid, as before); a record whose key / name / data does not fit is
  skipped; Joliet names are copied whole. Traps: the first saltests data spilled past its own
  512-byte node (the helper now checks); an `ER` partition map image must be cut at its
  `Apple_HFS` partition to reach the HFS+ reader alone. Limits: the item's fuzzing pass was not
  done (no mutated images; Inbox, who person); found on the way (Inbox): xorriso's Rock Ridge
  (no `RR` entry) is not recognised, a valid xorriso hybrid shows the Xbox reader's "Cannot read
  sector #00000020.". From backlog item `uniso-hfs-btree-trust-and-joliet-cut`. Probe
  `iso322_probe` 11/3 (14 rows) -> 18/0 (RR-LONG, HFS-MANY added; Joliet CJK 12 / 40, HFS+ alone, a 103-leaf catalog, Rock Ridge,
  plain, hybrid); 223's probe ISO-F5 PASS (RR-LONG NOT DRIVEN without Docker); saltests 27776;
  one refute-first review (no MUST; SHOULD taken: the many-leaf row; mutants of each bound fail).
- 323-ftp-upload-cache-args: while an FTP upload was open, a file Quick-Renamed in the FTP panel
  to `b.txt` was replaced by an uploaded `b.txt` without the overwrite question, and a folder made
  by F7 with an absolute path outside the panel folder made the upload send `MKD` again (550) - the
  panel reported Create Directory / Quick Rename to the upload listing cache with host and user
  swapped, so `FindServer` dropped them. Now the four calls (`ctrlcon5.cpp`) pass `(user, host,
  port)`; a Quick Rename or Send FTP Command invalidates every cached listing of the server (what a
  rename reaches is not resolved); `ReportCreateDirs` records only the last named component of a
  created path as new and empty - an earlier one its cached parent listing does not show (a dot
  folder a plain `LIST` hides, `docs` beside `Docs`) invalidates that listing (`salftpmkdirreport.h`,
  `ReportCreateDirComponent`; empty components skipped). Traps: the stopped first run (302,
  carried over) was rejected twice - the argument fix made the cache's old reactions reachable and
  each opened a data-loss path (review 1: an F7 folder cached as empty stayed trusted after a
  rename into it; review 2: `MKD .cfg/new` cached the existing `.cfg` as empty); reading said the
  panel's refresh masks the rename case - the probe showed the upload's `STOR` before the panel's
  `LIST`. Limits: the cache is keyed by the host as typed (`localhost` / `127.0.0.1`, Inbox);
  Send FTP Command and "result unknown" reports by reading (person step). From backlog item
  `ftp-panel-mkdir-rename-skip-upload-listing-cache`. Probe `ftp302_probe` (first 12 rows) on `main`
  10/2 (MKD-ABS, REN-UP), on 302's state 10/2 (MKD-HID, MKD-CASE) -> 12/0, final 16/0 (+ MKD-HIDABS, MKD-UPHID
  from the review; a mutant of the absolute branch fails MKD-HIDABS); 288 20/0; saltests 27793;
  one refute-first review (no MUST; SHOULD taken: the absolute-path row).
- 324-undelete-unknown-volume: Undelete restored into a folder of the very volume being recovered
  without its same-partition warning when the core could not read the target's volume name - a
  mount folder named outside ASCII (the core asks the code-page `GetVolumeNameForVolumeMountPoint`
  with the UTF-8 path: error 2, measured on a junction `Zálohy` to the volume root) or a junction to
  a volume-GUID folder; `PathsAreOnTheSameVolume` answers "different" (estimation) when one volume
  name is unreadable, and View's temporary-folder check failed open the same way. Now
  `UndPathsMayShareVolume` (fs2.cpp) keeps the core's "same" and its certain "different", and
  re-decides an unsure "different" by the volume serials of both paths' nearest existing folders
  (`src/common/salsamevolume.h` on 103's identity: wide, `\\?\` form, any length, steps up only on
  not-found); an unreadable serial = the same volume. The core and the plug-in contract are
  unchanged, no string. Traps: "estimation = same" alone (the item's hint) would warn on every
  share - the core is always unsure there; review 1: fixture junctions pointing back to the temp
  volume could not tell a read that opens the link itself (mutant passed) - a junction to a second
  volume's root added. Limits: a serial-0 volume, an unreachable share or an unopenable source root
  now warn when the core is unsure; the elevated GUI restore is a person step
  (`check-the-undelete-same-partition-warning-for-a-target-in-an`); the core's code-page call is
  Inbox `the-core-reads-volume-names-with-the-code-page-api-on-utf-8`. From backlog item
  `undelete-skips-its-same-partition-warning-when-the-target`. saltests `TestSameVolume324` (55
  checks run; 27848 / 0): negative controls - the core's answer alone 6 failed, a link-itself read
  2 failed; one refute-first review (no MUST; SHOULD taken: the cross-volume row).
- 325-tar-listed-hard-links: copying the files shown in a folder of a TAR archive (Select All + Copy
  inside it) left out every hard-linked second name without a word - link members were never listed,
  so no panel operation asked for them (309 handled only links that were asked for) - now a hard link
  (type '1', not refused, not a folder) is listed as a file with the size of the data member it stands
  for, and an extraction asked for one whose target it neither wrote nor was asked for DEFERS it: after
  the pass the archive is opened again (`ReopenStream`: same file / offset / size - gzip, bzip2, .deb
  sub-archives) and one further pass writes the data under the first link the user lets be written
  (the overwrite question asked for each link of a group before the data is read), the others copied
  by 309's identity-safe `WriteOutLinkCopy`; F3 / UnpackOneFile resolves the link and re-reads for that
  member. Links resolve as tar extracts them (`CSalTarLinkResolver`, `saltarlink.h`, O(1) per member):
  the LATEST earlier definition of the name (an archive updated by `tar -u` / `tar -r` stores it twice),
  a link redefines its own name, other members clear it, the further pass picks that occurrence
  (ordinal); a deferred target wins over data written earlier under the name (`SalTarLinkDecideAsked`);
  a later asked member of a deferred link's name - also one differing only in case
  (`SalNameOrderCompareCI`) - supersedes it. A link with no earlier data member is reported (309's
  "(2) name -> link") and fails the operation, so Delete archive keeps it. Traps: review 1 MUST - the
  first rule took the FIRST member of a name: on a real `tar -u` archive Unpack with a mask + Delete
  archive wrote stale data and deleted the archive (also quadratic chains, Skip dropping the other
  names); review 2 (three agents stopped mid-probe, each leaving the registry changed - restored from
  their backups, hashes identical; a fourth reviewed without GUI probes) - a name redefined as a link
  after its data was written, a case twin not superseding, the "Unknown block signature" box repeated
  per pass, one pass per skipped link; trap 123 three times (a here-document made NUL bytes of `'\0'`
  and tabs of probe paths; `sed -i` dropped CRLF). Limits: symbolic links stay unlisted; FIFO /
  device members still skipped silently (Inbox `tar-unpack-skips-fifo-and-device-members-without-a-word`);
  a link to a member refused only by the listing's depth bound is listed with size 0; with a name listed
  twice F3 shows the first member's data; a name the operation writes twice asks the overwrite question
  (as on main). From backlog item `tar-copy-of-listed-files-leaves-hard-links-out`. Probe
  `link325_probe.ps1` 11 / 7 -> 32 / 0 (negative controls: second pass + one-file re-read off 12 / 6;
  pre-review-1 code fails UNP-UPD-DEL / COPY-UPD / COPY-SKIP; pre-review-2 code fails UNP-RELINK-DEL /
  UNP-CASE-DEL and COPY-BADSIG); 306 30 / 0, 308 12 / 0, 309 16 / 0, 310 52 / 0, 321 20 / 0 + 12 / 0
  unchanged; saltests 27,884 / 0; refute-first reviews: review 1 (one MUST + three SHOULD, fixed), review 2
  (partial results: two MUST-level defects fixed; final report no MUST, two SHOULD fixed, five NOTEs).
- 326-uniso-rrip-without-rr: an ISO image made on Linux with xorriso (Rock Ridge 1.12, no `RR`
  entry) listed and extracted its files under the upper-case ISO 9660 names - `top.txt` as `TOP.TXT`,
  a 200-letter name as 31 letters; the plug-in read Rock Ridge only when a record started with `RR` -
  now a volume whose root `.` record carries the SUSP `SP` entry is read as Rock Ridge
  (`src/common/salsusp.h`, LEN_SKP honoured), `RR` records as before; a Rock Ridge name keeps a `;`
  (it was cut there as the ISO version suffix) and is made safe for Windows after its UTF-8
  conversion (`..\x` -> `.._x`, `12:30.txt` -> `12_30.txt`, `con.txt` -> `_con.txt`, trailing dot ->
  `_`; feature 087's rule per component, `CISO9660::MakeListedName`); a volume whose Rock Ridge names
  the panel listing would refuse (a folder part over its bound) is listed as before 326, decided by a
  fit check pass with the core's rule (`sallistingname.h`); names that differ only in case are listed
  case-sensitively as TAR / 7-Zip since 252 (`uniso.cpp` `ListArchive`). Traps: review 1's MUST - the
  uncleaned names wrote `..\escape.txt` two levels above the target and `12:30.txt` into a stream;
  a deep Rock Ridge tree ended the listing with "Error" and lost a folder (a re-list after `Clear` was
  rejected: it would wipe a hybrid's other file systems); cleaning the raw bytes changed Shift-JIS
  letters (review 2); three review launches looked stopped while they waited on their own probes;
  clang-format reformats unrelated lines of `saltests.cpp` - format `--lines` only; Git Bash turns a
  `/mnt/c` argument to wsl into a `C:` folder in the repository. Limits: Rock Ridge + Joliet images
  still list Joliet; a too-deep Rock Ridge tree gets ISO 9660 names as a whole; CD-XA's `SP` not
  looked for; Joliet / ISO 9660 names still uncleaned and a refused entry still clears the listing of
  `RR` images (Inbox); the Shift-JIS order owed to a person. From backlog item
  `iso-plug-in-rock-ridge-names-of-xorriso-images-are-not-read`. Probe `iso326_probe` 13 / 5 -> 28 / 0
  (rows added after review 1 measured 24 / 4 before their fix; LEGACY = `rr.iso` patched to an `RR`
  first entry without `SP`); `twins326_probe` (252's probe with an ISO kind) 5 / 3 -> 8 / 0; 322's probe
  18 / 0; saltests 27,937 / 0 (mutants of each rule fail); refute-first reviews: review 1 (one MUST,
  fixed; N2 led to DEEP), review 2 (partial results: the case twins, fixed; final report no MUST, one
  SHOULD fixed, three NOTEs).
- 327-uniso-safe-names: the ISO plug-in took the names a disc image stores as they were - also from
  Joliet, plain ISO 9660, UDF, HFS+ and Xbox directories and the volume label folders of hybrids
  (`ISO (...)`, `UDF (...)`, `HFS (...)`): `12:30.txt` became a file `12` with the data in an NTFS
  stream, `con...` a device name, `x.` a file with its dot, a `/` or `..\` name was lost with "Error
  Creating File", and a label `v\..\..\w` made the whole volume be written next to the target folder -
  now every such name is made safe by feature 087's rule for one name (`SalArcCleanItemName`,
  `src/common/salarcname.h` N3 - the rule of 326's `SalSuspCleanRockRidgeName`, which now shares it)
  before it is listed and before it joins the descent path (`iso9660.cpp` `MakeListedName` / Joliet
  folders, `udf.cpp` `ScanDir`, `hfs.cpp` after `FixIllegalFSChars`, `xdvdfs.cpp` `ScanDir`,
  `udfiso.cpp` labels), and again where each reader joins the file name to the target
  (`AppendSafeName`, five `UnpackFile`s); a device name whose `_` prefix does not fit gets `_` as its
  first letter (never cut). Traps: review 1's partial work - an image without version numbers
  (`mkisofs -N`, xorriso `omit_version`) stores `README.`, whose separator dot the rule turned into
  `README_`: `SalIsoRemoveVersion` (salsusp.h) now drops the version and one separator dot first (also
  `A.B.;1` -> `A.B`; a Joliet `x.` and `x` now both list as `x`); IMAPI2 refuses such names - every probe
  image is crafted (byte patches of placeholders of the same length, a hand-built Xbox image, HFS+
  keeps Linux names, `12:30` stored as `12/30`); the probe must answer Skip in "Error Creating File" or
  most names are never tried; the second cleaning at extraction masks a missing listing-site cleaning
  for all but `\` names (review 2's negative control); two review launches ended with their sessions,
  one leaving a registry backup to restore. Limits: folder names are cleaned at listing only;
  `a:b` / `a_b` collide (overwrite question); the HFS label still overwrites a session prefix
  (pre-existing); the HFS+ skip leak and the hybrid's "Cannot read sector #00000020" stay (Inbox). From
  backlog item `iso-plug-in-joliet-and-iso-9660-names-are-not-made-safe`. Probe `iso327_probe` 19 / 39
  -> 77 / 0 (sets JOLIET, UDF, ULABEL, XBOX, PLAIN, NOVER, HFS, VOL, HLABEL; label sites removed ->
  68 / 9); 326's probe 28 / 0, 322's 18 / 0; saltests 27,937 -> 27,986 / 0 (mutants of each part fail);
  refute-first reviews: review 1 (partial results: the version-less separator, fixed), review 2 (no
  MUST, one SHOULD - label coverage - fixed, five NOTEs).
- 328-uniso-refused-entry: an ISO image with an entry deeper than the panel listing takes (a folder
  part over MAX_PATH - 5 bytes - genisoimage `-R` / `-J` trees, `RR` images without `SP`) opened with a
  bare "Error": the plug-in cleared what it had listed, descended into no later folder (`zlast\z.txt`
  lost too), and Unpack with "Delete archive after unpacking" deleted the image after extracting two
  of four files; xorriso images listed the whole volume under ISO 9660 names (326) - now such an
  entry is left out alone (`AddFileDir` asks the listing's rule first: listed / left out / failed),
  named once per listing with the system's "(206)" text and its whole in-image path (up to 10,
  `CSalListingLeftOut`, `src/common/salisonamefit.h`; a heap text as TAR 321), and a whole unpack of
  such a listing fails (the image is kept; an out-of-memory entry marks it too). The fit check runs
  for every non-Joliet volume; when it fails, each Rock Ridge folder whose name is longer than its
  ISO 9660 one is decided by count walks (`PickDirName` / `CountUnder`: Rock Ridge when its subtree
  fits whole or lists no fewer entries with ISO 9660 names below - never fewer entries than 326's
  whole-volume listing, proven on 400 random trees in saltests), a file keeps its Rock Ridge name
  whenever the listing takes it. Each walk meets a directory once (`Visited`; count walks undo theirs).
  Traps: review 1 (partial work of a stopped reviewer) - main's "Error" had ended the walk of a crafted
  folder cycle by accident, the new code hung 150 s+ (LOOP rows; a Joliet loop of 60-letter names did
  not fail without the fix - the depth bound ends it); review 2 (stopped, its stress images) - a copy of
  the visited set per count walk was quadratic, count walks for names not longer than the ISO ones
  walked deep chains per level; review 3's MUST - a reach rule (in-image path below MAX_PATH, added
  after the core's Copy box "Name ... with full path is too long" skipped deep.txt) renamed listed
  Rock Ridge files to 8.3 names: reverted, that box counts from the panel's folder and is skippable;
  a probe row's `$b` button handle shadowed the script's `$B` (PowerShell names ignore case); empty
  Bash here-documents to `python -` start a REPL that floods the output (twice). Limits: genisoimage's
  deep tree keeps `d` under its Rock Ridge name on a tie, so a Copy from the root asks about deep.txt
  (Unpack extracts it); a Joliet folder over the copy bound asks the same; UDF / Xbox / HFS+ / audio and
  read errors keep their old handling (Inbox `iso-plug-in-udf-xbox-and-hfs-entries-the-listing-refuses`,
  `iso-plug-in-unpack-deletes-image-with-unreadable-folder`); the report shows at every listing. From
  backlog item `iso-plug-in-an-entry-the-listing-refuses-ends-the-listing`. Probe `iso328_probe` 0 / 6
  RUN rows -> 20 / 0 (G/X/L-COPY, J-COPY, J-UNP-DEL, G-UNP-DEL, LONG-G/X, LOOP-RR/J; negative controls:
  decision off + unpack not failing 7 / 5, no visited set LOOP 0 / 2, review 2's build LONG 8.3 names);
  326 28 / 0, 326 twins 8 / 0, 327 77 / 0, 322 18 / 0; saltests 27,986 -> 28,018 / 0 (a mutant of the
  folder rule fails 6); refute-first reviews: 1 and 2 stopped (partial work used), 3 (one MUST, fixed),
  4 (no MUST, two SHOULD: out-of-memory marking taken, spec US3 corrected; read errors to Inbox).
- 329-uniso-other-readers-refused: the ISO plug-in's other readers still answered an entry the panel
  listing refuses (a folder part over MAX_PATH - 5 bytes) the old way after 328 - UDF and Xbox: "Error",
  the rest of the folder dropped and no later folder of the walk descended (`zlast\z.txt` lost); HFS+:
  "This disk image contains a too long path", every later catalog record dropped; audio tracks (NRG
  CD-Text name of 256+ bytes): the listing cleared; all three image kinds deleted by Unpack with "Delete
  archive after unpacking" - now each reader asks the listing's rule first (`sallistingname.h`, as the
  core's `AddFile` / `AddDir`), records a refused entry in 328's `CISOImage::ListingLeftOut` (one
  "(206)" report per listing, a whole unpack fails, the image is kept) and goes on: UDF / XDVDFS
  `AddFileDir` return 328's listed / left out / failed and only a listed folder is descended; HFS+
  keeps the catalog IDs of left-out folders (`CSalLeftOutIds::Under`, `src/common/salisonamefit.h`) so
  their contents are skipped - a plain "continue" would have listed them at the HFS+ root (the parent
  lookup falls back to `rootPath`); out of memory and a core refusal after the rule mark the listing
  incomplete; the refused name is no longer allocated (the old path leaked it: ~135 Debug-heap "Detected
  memory leaks!" boxes per U / X row before). Traps: a Python here-document turned `a\b` in a C++
  comment into a backspace byte (fixed from a script file); the audio box wraps a 253-letter name and
  the probe's window-text helper joins the lines with a space (the first after run failed A-OPEN on its
  own match). Limits: an HFS+ folder whose ID is lower than its parent's lists its contents at the root
  (old; Inbox `iso-plug-in-an-hfs-folder-whose-id-is-lower-than-its-parent`); entries skipped as damaged
  (UDF `MapICB`, HFS+ odd records, 322's skips) do not mark the listing (Inbox
  `iso-plug-in-udf-and-hfs-entries-skipped-as-damaged-let`); an NRG label of 257+ bytes overruns
  `CAudio::ListDirectory`'s `char[MAX_PATH]` (Inbox `iso-plug-in-an-nrg-audio-track-label-of-257-bytes-overruns-a`);
  `IDS_ERR_TOO_LONG_PATH` stays unused in the module. From backlog item
  `iso-plug-in-udf-xbox-and-hfs-entries-the-listing-refuses`. Probe `iso329_probe` 0 / 7 RUN rows -> 7 / 7
  (U/X/H-COPY, U/X/H-UNP-DEL, A-OPEN; seeds genisoimage `-udf`, xorriso `-hfsplus`, crafted XDVDFS and NRG
  by `img329.py`); 328 20 / 0, 327 77 / 0, 322 18 / 0; saltests -> 28,266 / 0 (a mutant of `Under` fails
  2); refute-first review 1: no MUST, two SHOULD fixed (the HFS+ subtree decision as a tested rule, the
  probe tree two levels below a left-out folder), reviewer's negative control 0 / 7 and HFS+ mutation FAIL.
- 330-iso-unreadable-folder: a disc image one of whose folders the ISO plug-in could not read ("Error
  reading directory structure ... Incomplete content of ISO image") was deleted by Unpack with "Delete
  archive after unpacking" after a partial unpack - the walk descends no later folder after the error
  and the listing was not marked; also silent cases (an ISO 9660 folder of length 0, a UDF folder
  whose file entry cannot be read) and a UDF part that does not open at all - now 328's
  `CISOImage::ListingLeftOut` is marked: ISO 9660, UDF and Xbox `ListDirectory` mark a walk result
  other than `ERR_OK` (every failure reaches the top: a nested `ERR_TERMINATE` stays `ERR_CONTINUE`;
  a directory met again returns `ERR_OK`, not marked), UDF also its early returns (File Set
  Descriptor, root ICB) and a folder whose `MapICB` fails; `CUDFISO` is told the parts the track type
  declares and marks one that does not open - a UDF part only with an anchor at sector 256 (review
  3: `DetectTrackFS` finds "NSR02" in file data, a valid ISO holding a UDF image would never unpack
  whole). Messages unchanged, no UI string. Traps: the first reviewer stopped mid-probe and left
  `%TEMP%\tc330_backup.reg` - restored first; its partial images found three UDF cases the
  "Error reading directory structure" sites missed (second approach: the walk result); a row's `$box`
  was the parameter `$Box` (PowerShell names ignore case, as in 328). Limits: later folders are still
  not descended after a read error (Inbox `iso-plug-in-after-a-folder-that-cannot-be-read-no-later`);
  an HFS+ part that does not open and a multi-session track that does not open still let Unpack delete
  the image (Inbox `iso-plug-in-an-hfs-part-of-a-hybrid-that-does-not-open-is`,
  `iso-plug-in-unpack-with-delete-archive-deletes-a-multi`); a UDF part with a destroyed anchor is not
  marked; a silent case keeps the image without a message. A UDF file whose entry cannot be read is now
  marked too (part of Inbox `iso-plug-in-udf-and-hfs-entries-skipped-as-damaged-let`, its HFS+ part
  open). From backlog item `iso-plug-in-unpack-deletes-image-with-unreadable-folder`. Probe
  `iso330_probe` (seeds genisoimage `-R` / `-udf` by `mkimg330.sh`, damaged copies and Xbox images by
  `img330.py`) on main 20 / 10 (all 10 damaged rows: image deleted) -> 30 / 0 (15 RUN rows, controls
  RD/UD/UDH/XD/NEST-OK still deleted); 322 18 / 0, 327 77 / 0, 328 20 / 0, 329 14 / 0; saltests 28,266 / 0;
  refute-first reviews: 1 stopped (partial work: three UDF MUST-level cases, fixed), 2 (one MUST: a UDF
  part that does not open - fixed; SHOULD multi-session and NOTE HFS+ to Inbox), 3 (no MUST; SHOULD: a
  valid nested image marked - the anchor condition, negative control NEST-OK FAIL at 7caf4ae7).
