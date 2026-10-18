# Tasks: Import settings from Altap Salamander and Open Salamander

**Input**: design documents in `specs/245-settings-import-salamander/` (spec, plan,
research, data-model, contracts/, quickstart, analysis)
**Tests**: REQUIRED — the maintainer asked for exhaustive testing by
independent agents ("stability, stability, stability"): `saltests` for every
pure rule, an e2e matrix over fixtures (automation seam), a UI probe, and
refute-first reviews.
**Rule for every task**: keep `fix-log.md` current; build (`build.cmd`) after
each code task group; never write the real `HKCU\Software\Altap` /
`HKCU\Software\Open Salamander` keys; probes back up and restore
`HKCU\Software\Tandem Commander`.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [ ] T001 Record the baseline in `specs/245-settings-import-salamander/fix-log.md`: build `build.cmd` (Debug) at `869d9690`, run `saltests`, note the check count; export (read-only) the maintainer's Altap 4.0 root to compare later (stored outside the repo, never committed)
- [ ] T002 Add the new source files to the projects: `src/common/salcfgimport.h`, `src/cfgimport.h`, `src/cfgimport.cpp`, `src/cfgimpdlg.cpp` in `src/vcxproj/salamand.vcxproj` (+ `.filters`), `src/plugins/ftp/ftpimport.cpp` in `src/plugins/ftp/vcxproj/ftp.vcxproj`; UTF-8-BOM, SPDX header (2026 Pavel Stupka)

## Phase 2: Foundational (blocks every story)

- [ ] T003 Implement the snapshot tree, source table, classification, conversions, identities, placement, history merge, default-directory filter, DLL matching and the forbidden-option list in `src/common/salcfgimport.h` per `contracts/salcfgimport-rules.md`
- [ ] T004 [P] Add `TestCfgImport245` to `src/saltests/saltests.cpp` covering every function of T003 with positive cases, negative controls and edges (empty, max lengths, non-ASCII, `$` overflow, slot 30 full, `C:\` trailing slash, absolute vs relative DLL)
- [ ] T005 Implement the source discovery (`CfgImpFindSources`: root table or `TC_CFGIMPORT_TEST_ROOT` in `_DEBUG`, `KEY_READ` only, `Configuration` subkey required, version classification, `Save In Progress` flag, running `salamand.exe` note) in `src/cfgimport.cpp` / `src/cfgimport.h`
- [ ] T006 Implement the read-only snapshot reader (`CfgImpReadSnapshot`: `RegOpenKeyExW(KEY_READ)`, `RegEnumKeyExW`/`RegEnumValueW`/`RegQueryValueExW`, UTF-16→UTF-8, limits of research R1, truncation flag, no message boxes, handle closed at the end) in `src/cfgimport.cpp`
- [ ] T007 Implement the read-only `CSalamanderRegistryAbstract` view over a snapshot node (`CCfgImpSnapshotRegistry`: Open/Get/GetSize/Close work, every write returns FALSE) in `src/cfgimport.cpp`
- [ ] T008 Implement the plan/report model (`CCfgImpGroup`, `CCfgImpLine`, `CCfgImpPlan`, report text builder with headings and markers `+ = ~ - ! x`, needs-consent rule) in `src/cfgimport.cpp`
- [ ] T009 Implement the guard (other Tandem Commander instances via `TaskList.GetItems`, PID ≠ own) and the backup (`SaveConfig` first when the root is absent, then `ExportConfiguration(…, TRUE)` into `%APPDATA%\Tandem Commander\Settings backups\before-import-<stamp>[-n].reg`; failure aborts) in `src/cfgimport.cpp`
- [ ] T010 Factor the post-OK refresh block of `WM_USER_CONFIGURATION` into `CMainWindow::RefreshAfterConfiguration(const CCfgRefreshState&)` (state captured before: status area, caption, zoom, tabs, font, view-templates-dirty) with unchanged behaviour, in `src/mainwnd3.cpp` / `src/mainwnd.h`
- [ ] T011 Implement the apply driver (`CfgImpApply`: guard again → backup → groups in order, each all-or-nothing with its own result → `RefreshAfterConfiguration` → `SaveConfig()`), in `src/cfgimport.cpp`
- [ ] T012 Add the dialogs `IDD_CFGIMPORT_SOURCE`, `IDD_CFGIMPORT_GROUPS`, `IDD_CFGIMPORT_PASSWORD`, `IDD_CFGIMPORT_PREVIEW`, `IDD_CFGIMPORT_RESULT` (DIALOGEX, DS_SHELLFONT, MS Shell Dlg 8) to `src/lang/lang.rc` with their control ids in `src/lang/lang.rh`, and the strings to `src/lang/texts.rc2` / `src/texts.rh2` (free slots of existing bundles)
- [ ] T013 Implement the wizard pages and their driver loop (Back/Next/Cancel/Help, list view with check boxes and modes, preview consent check box enabling *Import*, result Copy/Save) on `CCommonDialog` in `src/cfgimpdlg.cpp` per `contracts/wizard-flow.md`
- [ ] T014 Add the Options menu item *Import Settings from Sala&mander…* (`CM_IMPORTFROMSALAMANDER`, free id in `src/resource.rh2`) after *Import Configuration…* in `src/menu4.cpp`, its label in `src/lang/texts.rc2`, and the command handler in `src/mainwnd3.cpp`
- [ ] T015 Implement the `_DEBUG` automation seam `TC_CFGIMPORT_AUTORUN` (INI script → choices; preview/result text files; normal exit) in `src/cfgimport.cpp` + the idle hook in `src/mainwnd3.cpp`
- [ ] T016 [P] Write the fixture library `specs/245-settings-import-salamander/probe/ci245_lib.ps1`: product-key backup/restore/verify, fixture source roots under `HKCU\Software\Tandem Commander Test 245\` (Altap 4.0-like v103, OS 5.0-like v104/105, old v46, v38, v107), fixture TC configurations, key export + byte compare, run-the-exe-with-seam helper

**Checkpoint**: Debug build green, `saltests` green, the wizard opens, lists fixture sources, previews an empty plan.

## Phase 3: User Story 1 — hot paths, user menu, FTP connections without loss (P1) 🎯 MVP

**Goal**: Add-mode import of hot paths, user menu and FTP connections.
**Independent test**: quickstart V2 S1/S3/S11.

- [ ] T017 [US1] Hot paths: parse source slots (`0`=slot 10, `1..30`, < 47 `$` doubling, 047 name rule), plan Add/Replace with `SalCfgImpPlaceHotPath`, duplicate by path, apply to `MainWindow->HotPaths`, hot-path bar + jump list refresh — `src/cfgimport.cpp`
- [ ] T018 [US1] User menu: parse items (name, command, arguments, initial dir, shell flags, show-in-toolbar, type, icon; defaults as `LoadConfig`), plan Add (block append, identical top-level items/submenus skipped) / Replace, flag commands into the source's folder / `$(SalDir)\salamand.exe` / missing programs, apply by building a new `CUserMenuItems` and swapping, icons re-read — `src/cfgimport.cpp`
- [ ] T019 [US1] Interface 108 headers: append `SetPluginSettingsImport` to `CSalamanderPluginEntryAbstract`, add `CPluginSettingsImportAbstract`, `CSalamanderSettingsImportAbstract`, the `SALIMPORT_*` constants to `src/plugins/shared/spl_base.h` (or `spl_gen.h` where the password types live); `LAST_VERSION_OF_SALAMANDER` 108 + history in `src/plugins/shared/spl_vers.h`
- [ ] T020 [US1] Core side of 108: the entry object stores the handler on `CPluginData` (cleared on unload) in `src/plugins.h` / `src/plugins1.cpp`; the context object (`CCfgImpPluginContext`: mode, source name/version, snapshot view, report sink, password services) in `src/cfgimport.cpp`; the FTP group loads the plugin if needed (`InitDLL`), calls `ImportSettings(dryRun)` for the preview and again for apply
- [ ] T021 [US1] FTP handler in `src/plugins/ftp/ftpimport.cpp` (registered in `SalamanderPluginEntry`, `src/plugins/ftp/ftp.cpp`): load source Bookmarks / Proxy Servers / Server Types into temporary lists with the plugin's loaders through the read-only view; Add (proxy reuse/add with new UID + unique name, bookmark duplicate/rename rule, user server types added, UID re-mapping) and Replace; all-or-nothing swap into `Config`; reports for every item; scrambled passwords via `DecryptSourcePassword` + `EncryptForStorage`
- [ ] T022 [US1] One-time first-start offer (FR-002, research R13): `freshConfig` before `LoadConfig` in `src/salamdr1.cpp`, existence-only check of supported sources, `WM_USER_CFGIMPORT_OFFER` posted after start-up, handler box *Import now* / *Not now*, `SaveConfig()` after the answer — `src/mainwnd3.cpp`, `src/consts.h`
- [ ] T023 [P] [US1] Extend `TestCfgImport245` with the hot-path and user-menu parsers/planners on in-memory snapshots (Add, Replace, duplicates, full slots, `$` < 47, non-ASCII) in `src/saltests/saltests.cpp`
- [ ] T024 [US1] e2e scenarios S1, S3, S11, S12 in `specs/245-settings-import-salamander/probe/ci245_e2e.ps1`; run on the hidden desktop; record results in `probe/result_us1.txt`

**Checkpoint**: MVP — hot paths, user menu, FTP connections import in Add mode; re-run adds nothing.

## Phase 4: User Story 2 — the current program keeps working (P1)

**Goal**: nothing outside the selected groups changes; plugins, archivers, TC-owned settings, Windows state and the source stay intact.
**Independent test**: quickstart V2 S2/S4/S8/S9.

- [ ] T025 [US2] Group availability and the *never imported* catalogue on page 2 (packers/archivers with the Autoconfiguration hint, plugin registration, language, theme, tabs, window state, toolbar layouts) and the not-shipped plugin list (Automation, CHECKVER, Encrypt & Decrypt, IEVIEWER, MMVIEWER, nethood, SplitCombine, UnARJ, UnMIME, UnRAR, WMOBILE …) reported — `src/cfgimport.cpp`
- [ ] T026 [US2] Plugin re-mapping by DLL (research R7) shared by viewers, plugin keys and plugin settings — `src/cfgimport.cpp`
- [ ] T027 [P] [US2] e2e S2 (every group, most-changing modes) asserting: plugin registration/order/`plugins.ver` unchanged, archiver sections unchanged, FR-016 values unchanged, codeview/mdview associations unchanged; S4 source byte identity on every scenario; S9 other instance refused — `probe/ci245_e2e.ps1`

## Phase 5: User Story 3 — choose what and how (P2)

**Goal**: per-group selection and modes; preview and consent; cancel anywhere.
**Independent test**: quickstart V3 + V2 S5.

- [ ] T028 [US3] Modes per research R4 (defaults, Add/Replace only for list groups with both, viewers Add-only, option groups take-over unticked) and the consent rule (FR-010c) wired through pages 2 and 4 — `src/cfgimpdlg.cpp`, `src/cfgimport.cpp`
- [ ] T029 [US3] Replace preview lines list every current item removed and every value overwritten (current → new) — `src/cfgimport.cpp`
- [ ] T030 [P] [US3] UI probe `probe/ci245_ui.ps1`: open from the menu, walk pages by control ids, enabling rules, cancel on each page = no change, one Add run, page captures light + dark

## Phase 6: User Story 4 — passwords stay usable and protected (P2)

**Goal**: research R10.
**Independent test**: quickstart V2 S7.

- [ ] T031 [US4] Static helpers in `src/pwdmngr.cpp/.h`: verify a password against a given verifier; decrypt a blob with a given master password (same algorithms as `VerifyMasterPassword`/`DecryptPassword`, no state change)
- [ ] T032 [US4] Password page (counts, old master password check, import/skip, weaker-storage consent, TC-master-password note) and the policy → `GetPasswordPolicy`/`DecryptSourcePassword`/`EncryptForStorage` (asks TC's master password once via `AskForMasterPassword`) — `src/cfgimpdlg.cpp`, `src/cfgimport.cpp`
- [ ] T033 [P] [US4] e2e S7 (scrambled; AES with right/wrong/no password; TC with/without master password; consent on/off; TC `Password Manager` values byte-identical after every run) — fixture AES blobs generated by a Debug-only helper in the seam

## Phase 7: User Story 5 — plugin shortcuts, options, appearance (P3)

**Goal**: the remaining groups.
**Independent test**: quickstart V2 S2/S8 with these groups.

- [ ] T034 [US5] Plugin command shortcuts (user-assigned only; Add/Replace rules of R5; `IsSalHotKey`, `Plugins.FindHotKey`) — `src/cfgimport.cpp`
- [ ] T035 [US5] Viewers / alternative viewers / editors (Add only, masks identity, `|` rows skipped, < 44 lower-case, plugin rows re-mapped, appended after current rows, flagged missing programs) — `src/cfgimport.cpp`
- [ ] T036 [US5] Saved search criteria and ignore list (Add) — `src/cfgimport.cpp`
- [ ] T037 [US5] Histories (Add, password stripping, capacities) — `src/cfgimport.cpp`
- [ ] T038 [US5] Options allow-list table and its groups (confirmations, panel/keyboard, general, viewer, default directories) per `contracts/options-table.md` — `src/cfgimport.cpp`
- [ ] T039 [US5] Colours + highlighting, view templates (take over; theme kept) — `src/cfgimport.cpp`
- [ ] T040 [US5] Other plugins' settings (unload, replace subtree, never not-shipped/TC-only plugins, unload refusal reported) — `src/cfgimport.cpp`
- [ ] T041 [P] [US5] `saltests`: masks identity, history merge, option-table names vs forbidden list, default-dir filter, DLL matching — `src/saltests/saltests.cpp`
- [ ] T042 [P] [US5] e2e S6 (versions), S8 (plugin rows/keys), options/colours/templates/plugin settings checks — `probe/ci245_e2e.ps1`

## Phase 8: User Story 6 — backup and a way back (P3)

- [ ] T043 [US6] Result page restore steps (file path, `-C "<file>"`, double-click) and backup-failure abort message — `src/cfgimpdlg.cpp`, `src/cfgimport.cpp`
- [ ] T044 [P] [US6] e2e S10: backup exists; `-C <backup>` start restores the pre-import export exactly — `probe/ci245_e2e.ps1`

## Phase 9: Polish & cross-cutting

- [ ] T045 Retire the 057 script: remove `utils/migrate-altap-settings.cmd`, `utils/test/`, update/remove `utils/README.md`; repoint mentions (README, docs) to the wizard
- [ ] T046 Amend the constitution (Principle II exception, 3.2.0 → 4.0.0, Sync Impact Report) in `.specify/memory/constitution.md`; update `CLAUDE.md` product identity, `architecture/12-project-reference.md`, `architecture/06-*.md` (interface 108)
- [ ] T047 Update `PRIVACY.md` (*Settings and history*, *Saved passwords*: on request, read-only reading of the named roots; first-start existence check; passwords re-protected), `README.md`, `CHANGELOG.md` (unreleased section), help page in `help/src/hh/salamand/` (+ menu reference), `specs/FEATURE-HISTORY.md` entry
- [ ] T048 Translations: two-stage `.slt` refresh (`translate.merge --templates …`), pin formal register in `translations/ui-overrides.json` if needed; `build.cmd full` green
- [ ] T049 Release build `build.cmd full release`; UI probe on Release (V4)
- [ ] T050 Independent refute-first reviews (separate agents: core engine, wizard UI, interface 108 + FTP, documents/privacy) → fix confirmed findings → re-test (full e2e + saltests)
- [ ] T051 Add the observations of `analysis.md` § A11 to the backlog *Inbox* (`/tandem-backlog add`, source `measure:245`)
- [ ] T052 Closing report `specs/245-settings-import-salamander/closing-report.md` (what was built, test evidence, NOT DRIVEN rows owed to a person, deviations)

## Dependencies & Execution Order

- Phase 1 → Phase 2 → US1 (MVP) → US2 → US3 → US4 → US5 → US6 → Polish.
- T003 before T004/T023/T041; T005–T008 before every group; T010 before T011;
  T012 before T013; T019 before T020 before T021; T031 before T032.
- US4 needs US1's FTP path; US5's viewers/keys/plugin settings need T026.

## Parallel opportunities

- T004 with T005–T009 (different files); T016 with T003–T015.
- Within US5: T041/T042 alongside implementation tasks.
- Reviews in T050 run as parallel independent agents.

## Implementation strategy

MVP = Phase 1–3 (hot paths, user menu, FTP Add). Then harden (US2) before
adding modes (US3), passwords (US4) and the remaining groups (US5), backup
evidence (US6), and the documents. Each phase ends with build + `saltests` +
its e2e scenarios.
