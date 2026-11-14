---

description: "Task list for feature 428 — portable build of Tandem Commander"
---

# Tasks: Portable build of Tandem Commander

**Input**: Design documents from `specs/428-portable-build/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: included — the spec's success criteria and the project's working method require them
(pure rules in `src/common/` with `saltests` checks, a lossless round-trip gate, GUI / system
probes on the hidden desktop in `specs/428-portable-build/probe/`). Every probe backs up and
restores `HKCU\Software\Tandem Commander` and asserts that the installed edition's key is
unchanged at the end.

**Organization**: by user story of [spec.md](spec.md) (US1–US6). Keep
`specs/428-portable-build/fix-log.md` running throughout (every measurement, finding, decision).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1 … US6 of the spec; Setup / Foundational / Polish have none

---

## Phase 1: Setup (shared infrastructure)

**Purpose**: the feature's working folders and the build switch that every later task compiles with.

- [X] T001 Create `specs/428-portable-build/probe/` with a `README.md` (how each probe runs, the registry backup / restore rule, the hidden desktop) and add a dated "implementation start" entry to `specs/428-portable-build/fix-log.md`
- [X] T002 Create `src/Directory.Build.props` defining `TcOutSuffix` = `_portable` when `'$(TcEdition)'=='portable'`, else empty (contracts/build-cli.md *MSBuild*)
- [X] T003 Append `$(TcOutSuffix)` to every output root `tandemcommander\$(Configuration)_$(ShortPlatform)\` in the 19 files that spell it (`src/vcxproj/sal_base.props`, `src/vcxproj/x64.props`, `src/vcxproj/x86.props`, `src/plugins/shared/vcxproj/plugin_base.props`, `src/plugins/shared/vcxproj/lang_base.props`, the 7za, fcremote, exif, chmlib, zip2sfx, salopen, shellext, sqlite and saltests project / sheet files — list them in fix-log.md) and update the Release IntDir rewrite token in `src/Directory.Build.targets` (KEEP IN SYNC block, lines ~21-37)
- [X] T004 Add `TC_PORTABLE` to `ClCompile` and `ResourceCompile` `PreprocessorDefinitions` in `src/vcxproj/sal_base.props` under `Condition="'$(TcEdition)'=='portable'"`
- [X] T005 [P] Write `tools/check_outdir_suffix.py` (fails when any `*.props` / `*.vcxproj` under `src/` spells the output root without `$(TcOutSuffix)`; answers `--help`) and call it from `build.cmd` next to the other policy checks
- [X] T006 Parse `portable` and `dist` in `build.cmd`: validation table of contracts/build-cli.md (`release portable` without `full`, `portable setup`, `dist` with other arguments → error before any work, exit 1), `/p:TcEdition=portable` on the MSBuild line, `OUT_DIR` with the suffix at both places it is computed (~146, ~451) and in the display lines, help text
- [X] T007 Make `src/vcxproj/build_langs.cmd` compute its output path with the portable suffix (it recomputes the path from `OPENSAL_BUILD_DIR` + configuration, research R-06)
- [X] T008 Verify the normal build is unchanged: record a file-hash list of `build\tandemcommander\Debug_x64\` and `Release_x64\` (excluding time-stamped PDB / intermediates) before T002, rebuild after T007 without `portable`, compare (0 differences in shipped files) and record in fix-log.md; then `build.cmd portable` produces `Debug_x64_portable\` and leaves `Debug_x64\` untouched

**Checkpoint**: `build.cmd portable` builds a (still registry-using) portable tree beside the normal one.

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: the gate test and the pure rules every story needs. **No story work before this phase is done.**

- [X] T009 Write the round-trip gate `specs/428-portable-build/probe/roundtrip_gate.py` + a small native helper if needed (`specs/428-portable-build/probe/roundtrip/`): copy the real `HKCU\Software\Tandem Commander\Settings` (read-only) into a private hive, dump it with reglib's `DumpToBuffer` (core build: through a test entry in `saltests` or a debug-only seam), parse the dump into a second hive, compare recursively every key, value name, type and byte; plus synthetic values (all types, empty, 1 MB binary, 255-character and non-BMP names, embedded `$(SalDir)`); 0 differences required
- [X] T010 If T009 finds any loss: fix it in `src/reglib/src/reginmem.cpp` / `regparse.cpp` / `registry.cpp` with a saltests check, re-run T009 to 0 differences, record in fix-log.md (stop-rule: a loss that cannot be fixed here stops the run with the finding)
- [X] T011 [P] Create header-only `src/common/salportable.h`: `SalPortableScope(volumeSerial, fileIdBytes)` (FNV-1a-64 → 16 hex), `SalPortableSessionDirName(scope)`, `SalPortableScopeSuffix(scope)` (`_P<scope>`), `SalPortableRelativize(text, programDir)` / `SalPortableExpand(text, programDir)` (research R-03: ordinal-CI prefix at a path boundary, long-name form, no trailing backslash), `SalPortableStartDecision(sessionState, fileState, bakState)` (data-model.md decision table)
- [X] T012 [P] Add saltests group `TestPortable428` in the saltests sources (`src/tests/` or the project's existing test layout): scope stability / distinctness, names, relativize / expand round trip and adversarial cases (case, trailing backslash, `E:\TC` vs `E:\TC2`, UNC, `\\?\`, quotes, `;`-lists, non-BMP, a value that is only the folder), every row of the start-decision table
- [X] T013 Introduce `SalCfgBaseKey()` in `src/consts.h` / `src/regwork.cpp`: an inline returning `HKEY_CURRENT_USER` in the normal edition; in the portable edition the session hive root set by the store (T016)
- [X] T014 Write `tools/check_portable_regsites.py` (answers `--help`): lists every literal `HKEY_CURRENT_USER` / `HKEY_LOCAL_MACHINE` / `HKEY_CLASSES_ROOT` in `src/*.cpp` and fails unless each is routed through `SalCfgBaseKey()`, marked `// portable: system read`, or inside `#ifndef TC_PORTABLE`; call it from `build.cmd`

**Checkpoint**: gate green, pure rules tested, base-key hook in place.

---

## Phase 3: User Story 1 — Run from an unpacked folder without installing (P1) 🎯 MVP

**Goal**: the portable executable runs with all its state in `settings\` and writes nothing to the registry or the profile.

**Independent test**: quickstart.md §3 — snapshot diff shows 0 program writes; `settings\tandemcommander.reg` holds the changes; a second start shows them; the installed edition's key is unchanged.

### Tests for User Story 1

- [X] T015 [P] [US1] Write `specs/428-portable-build/probe/notrace_probe.ps1`: snapshot HKCU / readable HKLM / HKCR (minus a documented list of keys Windows itself changes, kept in the script) and `%APPDATA%` / `%LOCALAPPDATA%` (minus `Temp`), unpack a portable tree into a fixture under `%TEMP%`, drive every Configuration page, the enabled plug-ins' settings, the code and Markdown viewers, close, snapshot again; report differences, the session folder's absence after exit, the settings file, a second start (run it red first: before T016 it must show the HKCU writes — negative control)

### Implementation for User Story 1

- [X] T016 [US1] Implement the store in new `src/portstore.h` / `src/portstore.cpp` (contracts/settings-store.md *Interface*): scope from the folder identity (`GetFileInformationByHandleEx`), `Local\TandemCommanderPortable_<scope>_Start` / `_Store` mutexes, stale clean-up of other `%TEMP%\TandemCommander-portable-*` folders, the start decision (delete test on `session.dat`), seed a new session hive with `RegLoadAppKeyW` from `settings\tandemcommander.reg` via reglib `Parse` with the base key and `SalPortableExpand`, or join a live one; add both files to `src/vcxproj/salamand.vcxproj`
- [X] T017 [US1] Persist in `src/portstore.cpp`: worker thread on `RegNotifyChangeKeyValue` (subtree, names + last-set), 2 s debounce, dump under `_Store` with reglib (no `RemoveHiddenKeysAndValues`) and `SalPortableRelativize`, write `settings\tandemcommander.reg.tmp`, flush, `SalReplaceWithTempW`, previous → `.bak`; `PortableStore_PersistNow()`; create `settings\` on the first persist
- [X] T018 [US1] Close in `src/portstore.cpp`: persist if dirty, stop the worker, close the root, delete `session.dat` (success = last instance → remove the session folder, WebView2 best effort)
- [X] T019 [US1] Call `PortableStore_Open()` first in `WinMainBody` and `PortableStore_Close()` at the end in `src/salamdr1.cpp`; call `PortableStore_PersistNow()` right after `CMainWindow::SaveConfig` returns in `src/mainwnd2.cpp`
- [X] T020 [US1] Route the configuration sites through `SalCfgBaseKey()` in `src/mainwnd2.cpp`, `src/plugins1.cpp`, `src/salamdr2.cpp` (`CheckOnlyOneInstance`, export / import), `src/mainwnd3.cpp` (backup key), `src/cfgimport.cpp`, `src/salamdr1.cpp` (language key 4239 / 4412), `src/updcheck.cpp` (raw `RegCreateKeyExW` 71 / 74), `src/callstk.cpp` (623); mark system reads `// portable: system read`; T014's check passes
- [X] T021 [US1] Give reglib's system registry the base key for `HKEY_CURRENT_USER\…` names (factory parameter or setter) in `src/reglib/src/registry.cpp` and its users in `src/salamdr2.cpp` (`ExportConfiguration`, `ImportConfiguration`), so export / import in the portable edition read / write the session hive (FR-013)
- [X] T022 [US1] Skip under `TC_PORTABLE` in `src/salamdr1.cpp` / `src/mainwnd2.cpp`: `MigrateConfigurationRoot`, `GetUpgradeInfo` / `AutoImportConfig`, `FindLatestConfiguration`, `DeleteOldConfigurations`, the `config.reg` / `-c` start-up import, the 245 first-start offer (`salamdr1.cpp:4917`, `mainwnd3.cpp:2673`) — the menu import stays
- [X] T023 [US1] Scope the named objects (research R-05) in `src/tasklist.cpp` (process list objects, `LoadSaveRegistry`) and `src/updcheck.cpp` (update claim) with `PortableStore_ScopeSuffix()`; keep `FirstInstance` per user; never create the legacy-session mutex (`src/mainwnd2.cpp`)
- [X] T024 [US1] Shell extension: compile out the registration (`src/salamdr1.cpp:4636-4662` → `shexreg.c`) under `TC_PORTABLE`; in `src/shellsup.cpp` (1350-1372, 1414, 1723) show `IDS_PORTABLE_NOSHELLEXT` once per action where the normal edition needs the extension (contracts/ui-identity.md)
- [X] T025 [US1] Other writes outside the folder under `TC_PORTABLE` (research R-09): jump list not built (`src/jumplist.cpp`), icon-size refresh skipped (`src/mainwnd3.cpp:1615`), bug reports to `settings\BugReports\` (`src/callstk.cpp:805-850`, path computed at start-up), *Export Configuration* default folder `settings\` (`src/mainwnd3.cpp:3661`, `src/salamdr5.cpp:1992-2025`), import backups to `settings\Backups\` (`src/cfgimport.cpp:1027-1045`)
- [X] T026 [US1] Plug-in API 109 (contracts/plugin-api-109.md): append `IsPortableEdition`, `GetUserDataFolderW`, `GetInstanceScopeSuffix` at the end of `CSalamanderGeneralAbstract` in `src/plugins/shared/spl_gen.h`, implement in the core (`src/zip.cpp` next to the other `CSalamanderGeneral` methods), `LAST_VERSION_OF_SALAMANDER` 108 → 109 with a history entry in `src/common/spl_vers.h`
- [X] T027 [US1] `TcWebUserDataFolder()` in `src/common/webhost/webhost.cpp` takes the folder from `GetUserDataFolderW(SALUSERDATA_WEBVIEW2)` when the core is ≥ 109 (the core's own caller `src/webkeeper.cpp` uses the core function directly); `src/plugins/mdview/webglue.cpp` skips the old-folder clean-up when `IsPortableEdition()`
- [X] T028 [P] [US1] PictView (`src/plugins/pictview/render2.cpp`): in the portable edition keep the `PrevWallpaper*` record in its plug-in configuration instead of `HKCU\Control Panel\Desktop`; the wallpaper bitmap path unchanged (research R-09)
- [X] T029 [P] [US1] File Comparator: append `GetInstanceScopeSuffix()` to the `RemoteComparator …` object names (`src/plugins/filecomp/remotmsg.h`, `src/plugins/shared/lukas/messages.cpp`, `remote.cpp`) and pass the suffix to `fcremote.exe` on its command line
- [X] T030 [US1] Run `notrace_probe.ps1` to green (0 program writes, session folder gone, settings persisted); record the snapshot exclusions and results in fix-log.md
- [X] T031 [US1] Side-by-side probe `specs/428-portable-build/probe/sidebyside_probe.ps1` (quickstart.md §6, SC-007, FR-011a): installed + portable and two portable folders, *Only one instance* on, 10 settings changed each way, two windows of one folder share settings

**Checkpoint**: US1 complete — a portable tree runs without traces (MVP).

---

## Phase 4: User Story 2 — Carry it to another PC with all settings (P1)

**Goal**: moving the folder (other path, drive letter, user) keeps every setting; paths into the folder follow; passwords stay protected.

**Independent test**: quickstart.md §4 and §9 (password note).

### Tests for User Story 2

- [X] T032 [P] [US2] Write `specs/428-portable-build/probe/move_probe.ps1`: configure a user-menu item and a hot path to a tool inside the folder, an FTP bookmark, a saved password with a master password; close; copy the folder elsewhere and `subst` it to another letter; start; assert every checked setting, the paths in the new location, `$(SalDir)` in the file, the password with the master password

### Implementation for User Story 2

- [X] T033 [US2] Wire `SalPortableRelativize` / `SalPortableExpand` with the long-name program folder (`GetLongPathNameW`) into the dump / seed of `src/portstore.cpp` for `REG_SZ`, `REG_EXPAND_SZ` and each string of `REG_MULTI_SZ`; binary values untouched
- [X] T034 [US2] Password note (FR-015a, contracts/ui-identity.md) in `src/pwdmngr.cpp`: at the first password saved without a master password in the portable edition show `IDS_PORTABLE_PWDNOTE` with *Set Master Password…* / *Continue* and *Do not show this again* (`Portable Password Note Shown` under the root); saving never blocked
- [X] T035 [US2] Run `move_probe.ps1` to green and the password-note rows (shown once, not after "Do not show this again" across a restart, password saved either way); record in fix-log.md

**Checkpoint**: US1 + US2 — a portable copy travels.

---

## Phase 5: User Story 3 — Build the portable package with one command (P1)

**Goal**: `build.cmd full release portable [sign]` makes the ZIP; `build.cmd dist` makes the whole signed release.

**Independent test**: quickstart.md §1 — ZIP name / layout / contents, the normal tree unchanged, `dist` summary.

### Tests for User Story 3

- [X] T036 [P] [US3] Write `specs/428-portable-build/probe/zip_check.py`: opens a built ZIP and checks contracts/package-layout.md (one top folder, required files present, every excluded pattern absent, the exe's `FileDescription` is the portable one, entries sorted, time stamps equal); a second build of the same commit gives the same file list and file hashes (SC-005)

### Implementation for User Story 3

- [X] T037 [P] [US3] Write `tools/portable/make_portable_zip.py` (contracts/package-layout.md: sorted entries, commit-time stamps, exclusions, `.part` + rename, refuses a normal-edition exe; `--help`)
- [X] T038 [P] [US3] Write `tools/portable/README-portable.txt` (English, ≤ 60 lines, the eight points of contracts/package-layout.md)
- [X] T039 [US3] Call the ZIP step from `build.cmd` for `full release portable` after signing (when `sign`), output `setup\output\tandemcommander-<ver>-x64-portable.zip`, version from `src/common/spl_vers.h`
- [X] T040 [US3] Implement `build.cmd dist` (contracts/build-cli.md *dist*): refuse without `tools\codesign\codesign.cfg`; run `full release rebuild sign setup`, then `full release rebuild sign portable`; stop at the first failure with `DIST FAILED at step <n>`, delete a partial artefact of the failing step; on success print both files with size and SHA-256
- [X] T041 [US3] Run the build matrix of quickstart.md §1 (errors before any work, Debug portable, Release portable ZIP, `zip_check.py`, the normal tree hash list unchanged, `dist` on the maintainer's machine if the certificate is available — otherwise a NOT DRIVEN row owed to the maintainer) and record timings of `dist` in fix-log.md

**Checkpoint**: the package exists and is reproducible.

---

## Phase 6: User Story 4 — See that this copy is the portable one (P2)

**Goal**: title marker, About lines and link, badge icon, separate taskbar group; the normal edition unchanged.

**Independent test**: quickstart.md §7.

### Tests for User Story 4

- [X] T042 [P] [US4] Write `specs/428-portable-build/probe/identity_probe.ps1`: title text (also elevated if drivable, else NOT DRIVEN) in all 8 enabled languages, About lines and link (activating it opens `settings\` in the active panel), icon resource of the exe and of the window, taskbar grouping by executable path; the same checks on the normal edition show no change

### Implementation for User Story 4

- [X] T043 [P] [US4] Title: insert the literal ` [portable]` after the version in `CMainWindow::SetWindowTitle` (`src/mainwnd1.cpp:~1962-2009`) under `TC_PORTABLE`, before ` (Administrator)`
- [X] T044 [US4] About: in `CAboutDialog::DialogProc` (`src/logo.cpp:596-608`) create, under `TC_PORTABLE`, the static `IDS_ABOUT_PORTABLE_EDITION` and a link with the `settings\` path (`CUpdateLink` behaviour, middle-shortening at whole characters + tooltip with the full path), grow the dialog and move the controls below; the link closes the box and opens the folder in the active panel
- [X] T045 [P] [US4] Badge icon: add a `--portable` variant to `tools/brand/gen_icons.py` producing `src/res/salamand_portable.ico` in every size of `src/res/salamand.ico` (badge with a contrasting outline), document it in `tools/brand/README.md`, check the icon in
- [X] T046 [US4] Resources: `IDI_SALAMANDER` from `res\salamand_portable.ico` under `TC_PORTABLE` in `src/salamand.rc2`; `FileDescription` "Tandem Commander (portable)" in the version resource (`src/versinfo.rh2` or the core's version block) under `TC_PORTABLE`
- [X] T047 [US4] Run `identity_probe.ps1` to green; check About in Light / Dark / High Contrast (screenshots in `specs/428-portable-build/evidence/`)

**Checkpoint**: the edition is recognisable everywhere.

---

## Phase 7: User Story 5 — Learn about a newer version (P3)

**Goal**: the check runs as in the installed program, links only, requires the portable ZIP asset.

**Independent test**: quickstart.md §8.

### Tests for User Story 5

- [X] T048 [P] [US5] saltests cases in the update-check group for `SalUpdPortableName` / `SalUpdPortableUrl` and the edition parameter of `SalUpdParseLatestRelease`: present / missing / twice / not uploaded / wrong URL / draft / pre-release, for both editions (the normal rule unchanged)

### Implementation for User Story 5

- [X] T049 [US5] In `src/common/salupdcheck.h` add `SalUpdPortableName`, `SalUpdPortableUrl` and the edition parameter to `SalUpdParseLatestRelease` / `SalUpdReadAsset` users (lines ~194-223, ~1032-1155, ~1340-1421), new reason `supeNoPortable`; pass the edition from `src/updcheck.cpp`
- [X] T050 [US5] Gating under `TC_PORTABLE` (contracts/update-check-portable.md): `UpdInstall_IsEligible` FALSE without the uninstall read (`src/updinstall.cpp:280-327`), the notification shows the page link and `IDS_UPDATE_HINT_PORTABLE_EDITION` without level list or install buttons (`src/upddlg.cpp:237-260`, `393-413`), Configuration > General hides the level list and lays out without a gap (`src/dialogs4.cpp:868-906`), `--updatetest` refused with a message
- [X] T051 [US5] Probe `specs/428-portable-build/probe/update_probe.ps1` with 123's Debug seams (`TC_UPDATECHECK_URL` fixture server): with ZIP asset → link-only notification; without → nothing; General page; no file in `%LOCALAPPDATA%`; record in fix-log.md

**Checkpoint**: portable users hear about releases, nothing is downloaded.

---

## Phase 8: User Story 6 — Start where the folder cannot be written; damaged files (P3)

**Goal**: unwritable folder → runs, warns once, never saves elsewhere; damaged file → `.bak` or defaults with a note; a kill never loses complete settings.

**Independent test**: quickstart.md §5.

### Tests for User Story 6

- [X] T052 [P] [US6] Write `specs/428-portable-build/probe/failure_probe.ps1`: deny-write ACE on the portable folder (message once, no second message at exit, nothing written anywhere, settings intact); corrupt file → `.bak` + note; both corrupt → `.damaged-<UTC>` + defaults + note; unreadable file → defaults + unwritable (file never overwritten); 20 kills at random moments of a save → the file always parses and the next start has the last complete settings (SC-006)

### Implementation for User Story 6

- [X] T053 [US6] Unwritable detection and state in `src/portstore.cpp` (probe file `settings\.probe-<pid>` at start; a failed persist later): `PortableStore_IsWritable()`, `IDS_PORTABLE_CANNOTSAVE` once per session when the main window is free, no further automatic persists, no save attempt at exit
- [X] T054 [US6] Damaged / unreadable handling in the seed of `src/portstore.cpp` per the start-decision table: `.bak` with `IDS_PORTABLE_RESTOREDBAK`; rename `.damaged-<UTC>` + defaults + `IDS_PORTABLE_DAMAGED`; an unreadable file → defaults and unwritable; no usable `%TEMP%` → `IDS_PORTABLE_NOTEMP`, the program does not start
- [X] T055 [US6] Run `failure_probe.ps1` to green; record in fix-log.md

**Checkpoint**: all user stories functional.

---

## Phase 9: Polish & cross-cutting concerns

- [X] T056 Add the new strings (`IDS_ABOUT_PORTABLE_EDITION`, `IDS_PORTABLE_NOSHELLEXT`, `IDS_PORTABLE_PWDNOTE` + its button / check-box texts, `IDS_UPDATE_HINT_PORTABLE_EDITION`, `IDS_PORTABLE_CANNOTSAVE`, `IDS_PORTABLE_RESTOREDBAK`, `IDS_PORTABLE_DAMAGED`, `IDS_PORTABLE_NOTEMP`) in free slots of existing bundles in `src/lang/lang.rc2` / `src/lang/lang.rh` (verify while implementing T024–T054; this task closes the set)
- [X] T057 Run the two-stage `.slt` refresh (`translate.merge` with `--templates D:/Build/OpenSal/tandemcommander/translator/templates`), pin de / fr / nl / es formal register and "Portable edition" in `translations/ui-overrides.json`; `build.cmd full` green for all 8 languages
- [X] T058 [P] `PRIVACY.md`: a portable section (what is stored where, nothing in the registry, the session folder in `%TEMP%` and when it is removed — also the crash case, the same single update request, no download, no Explorer integration) in the same change (FR-019)
- [X] T059 [P] Docs: `architecture/06-plugin-api.md` (API 109), `architecture/11-webview2-integration.md` (portable rule — binding), `architecture/12-project-reference.md` (portable edition, `dist`, the ZIP), README / help page on the portable edition, `CHANGELOG.md` entry under the unreleased heading
- [X] T060 [P] Release tooling: `backlog/RELEASE.md` (step 2 `build.cmd dist`, step 5 attach both files, the ZIP name rule), `tools/release/release.py` artefact check (both files of the version in `setup\output\`) used by `/tandem-release`'s checklist; `tools/test_bin_help.py` still green
- [X] T061 Re-run SC-010: the normal tree's file list / hashes and the installer unchanged versus T008's baseline; the existing probes of touched areas (123 / 420-422 update probes, 174 export / import, 343 migration) on the normal edition green
- [X] T062 SC-009: measure start-up and save time of the portable vs. installed edition on this PC (local disk), record in fix-log.md (within 10 %)
- [X] T063 Run the whole quickstart.md (§1–§9), mark NOT DRIVEN rows, and add the person checks (real FAT32 / exFAT sticks on two PCs, ZIP downloaded with a browser + SmartScreen, the badge on a real taskbar in Light / Dark, real drag to Explorer) as lines of the *Manual checks owed before the next release* backlog item
- [X] T064 Two independent refute-first reviews of the finished change (an agent given the code, not the conclusion); fix MUST findings, severity ≥ 6 findings and the two findings in fix-log.md go to the backlog *Inbox* (`/tandem-backlog add`, source `review:428` / `measure:428`)
- [X] T065 Close: `specs/428-portable-build/closing-report.md`, the `^- 428-` entry in `specs/FEATURE-HISTORY.md`, a one-line standing rule in `CLAUDE.md` if one is needed (e.g. "configuration code uses `SalCfgBaseKey()`, never a literal `HKEY_CURRENT_USER` (428)"), the plug-in interface line (109) in `CLAUDE.md` *Product identity*

---

## Dependencies & execution order

### Phase dependencies

- **Setup (Phase 1)**: none — T002 → T003 → T004 → T006 / T007 → T008; T005 parallel after T003.
- **Foundational (Phase 2)**: after Setup. T009 → T010 (gate) blocks T016 / T017; T011 → T012; T013 → T014.
- **US1 (Phase 3)**: after Foundational. T016 → T017 → T018 → T019 → T020 / T021 / T022 / T023; T026 → T027 / T028 / T029; T024, T025 after T019; T030 / T031 last.
- **US2 (Phase 4)**: after US1's store (T017); T033 needs T011.
- **US3 (Phase 5)**: after Setup (T006) and US1 (a portable exe that is worth packaging); T037 / T038 can start any time after Setup.
- **US4 (Phase 6)**: after Setup (T004); independent of the store except the About link path (`PortableStore_SettingsDir()`, T016).
- **US5 (Phase 7)**: after Foundational; T049 → T050 → T051; T048 parallel with T049.
- **US6 (Phase 8)**: after US1's store (T016–T018).
- **Polish (Phase 9)**: after the stories it documents; T057 after T056; T061–T065 last.

### User story dependencies

- US1 is the base of US2 and US6 (they extend the store); US3, US4, US5 need only the build switch and can run beside US1 once Phase 2 is done.

### Within each story

Probe first and run red where a negative control exists (T015 before T016), then implementation,
then the probe to green.

---

## Parallel examples

```text
# Phase 2 (after Setup):
T011 salportable.h          ||  T009 round-trip gate      ||  T013 SalCfgBaseKey()

# US1, after T026 (API 109):
T027 webhost / mdview       ||  T028 pictview             ||  T029 filecomp

# Beside US1 once Phase 2 is done:
T037 make_portable_zip.py   ||  T038 README-portable.txt  ||  T045 badge icon  ||  T048 update saltests
```

---

## Implementation strategy

### MVP first (US1)

1. Phase 1 (build switch, normal tree proven unchanged).
2. Phase 2 (gate green, pure rules tested).
3. Phase 3 (US1) → **stop and validate** with `notrace_probe.ps1` and the side-by-side probe.

### Incremental delivery

US2 (travel) → US3 (ZIP + `dist`) → US4 (identity) → US5 (update) → US6 (failures) → Polish.
Each step keeps the normal edition unchanged (SC-010) and every probe green.

## Notes

- Commit per task or logical group on `428-portable-build`; never push (CLAUDE.md working method).
- Scripts are written with the editor tools (Bash here-documents collapse doubled backslashes, 123).
- New sources are UTF-8 with BOM, clang-format, English comments; `tools/check_encoding.py` must
  stay at `TOTAL: 0`.
