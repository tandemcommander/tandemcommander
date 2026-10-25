# Tasks: Version-free configuration root and Semantic Versioning of releases

**Input**: Design documents from `specs/343-semver-settings-root/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: requested by the spec (FR-024): saltests for the pure rules, `test_release.py` for the
release tool, the hidden-desktop probe for the end-to-end migration.

**Build dir**: `build\` (no `OPENSAL_BUILD_DIR` set on this machine). Debug exe:
`build\tandemcommander\Debug_x64\tandemcommander.exe`.

## Phase 1: Setup

- [X] T001 Start `specs/343-semver-settings-root/fix-log.md` (running log: measurements, decisions, deviations)
- [X] T002 Build the pre-change Debug x64 (`build.cmd` at commit 52668440, sources unchanged) and record that `python tools/release/release.py status 0.2.0` refuses `line-change` in `specs/343-semver-settings-root/fix-log.md`
- [X] T003 Create the shared probe key definition `tools/tc_config_key.ps1` (new key `Software\Tandem Commander\Settings` and legacy `Software\Tandem Commander\0.1`, in name / `HKCU:\` provider / `HKCU\` reg.exe forms, plus `Backup-TcConfigKeys` / `Restore-TcConfigKeys` helpers that export every `Settings*` and `0.1*` sibling key with hashes)
- [X] T004 Write the probe skeleton `specs/343-semver-settings-root/probe/cfgroot343_probe.ps1` in the style of `specs/241-pack-long-nested-folder/probe/pack241_probe.ps1` (dot-sources T003, backs up and restores keys, starts the exe on the hidden desktop, waits for the main window, closes it); with the pre-change build run row BEFORE (seed `0.1`, start, show that only `0.1` is used) → `specs/343-semver-settings-root/probe/result_before.txt`
- [X] T005 Produce the fixture `specs/343-semver-settings-root/probe/fixture_cfg_0_1.reg`: the configuration the pre-change build writes on a clean start + exit, extended by the probe with values of every type (`REG_SZ`, `REG_EXPAND_SZ`, `REG_MULTI_SZ`, `REG_BINARY`, `REG_DWORD`, `REG_QWORD`, default value, empty key, non-ASCII key and value names, 6 levels deep) under `Plugins Configuration\Probe343`

## Phase 2: Foundational (blocking)

- [X] T006 Add `src/common/salcfgmigrate.h`: `CSalCfgMigrateState`, `CSalCfgMigrateAction`, `SalCfgMigrateDecide` per `contracts/config-root-migration.md` (header-only, SPDX header 2026 Pavel Stupka, UTF-8 BOM)
- [X] T007 [P] Add `SalRegMapLegacyRoot` to `src/common/salregroot.h` per `contracts/legacy-root-import.md`; update the header comment's example root to `Software\Tandem Commander\Settings`
- [X] T008 Define the roots in `src/mainwnd2.cpp`: `SalamanderConfigurationRoots[0] = "Software\\Tandem Commander\\Settings"`, `SalamanderConfigurationVersions[0] = "Settings"`, new `const char* SALCFG_LEGACY_ROOT = "Software\\Tandem Commander\\0.1"`; declare it in `src/salamand.h` (next to `SalamanderConfigurationRoots`)
- [X] T009 saltests in `src/saltests/saltests.cpp`: decision table (all 8 combinations), `SalRegMapLegacyRoot` (contract examples + NULL/empty, buffer exactly fitting / one short, case-insensitive prefix, `0.10` and `0.1x` siblings, already-new names); update the feature-263 checks that use the literal root to the new root (keep them meaningful: siblings `Settings2`, `Settingsx`)

## Phase 3: User Story 1 + 2 - settings survive the update; the migration never loses data (P1) 🎯 MVP

**Goal**: first start migrates `0.1` → `Settings` raw, verified, atomically; failures fall back to `0.1`, interruptions are repeated.
**Independent test**: probe rows MIG-BASIC, MIG-AGAIN, MIG-BOTH, MIG-FRESH, MIG-KILL, MIG-FAIL-*, MIG-CORRUPT-BACKUP, MIG-PWD.

- [X] T010 [US1] Implement `MigrateConfigurationRoot(BOOL* usedLegacy)` in `src/mainwnd2.cpp` per `contracts/config-root-migration.md`: state read (wide API), `SalCfgMigrateDecide`, leftover clean-up, backup copy, side-key `RegCopyTreeW`, recursive compare (`CompareRegTrees`, values: name/type/size/bytes, subkeys both ways), `RegRenameKey` commit, failure clean-up; never opens `0.1` for writing; runs inside `LoadSaveToRegistryMutex`; TRACE_I/TRACE_E for each step
- [X] T011 [US2] Add the Debug seam `TC_CFGMIGRATE_FAIL_AT` (`copy` / `compare` / `rename` / `kill-after-copy`) in `MigrateConfigurationRoot` in `src/mainwnd2.cpp` (`#ifdef _DEBUG` only)
- [X] T012 [US1] Call the migration in `src/salamdr1.cpp` right after `LoadSaveToRegistryMutex.Init()` and before `GetUpgradeInfo`; on legacy fallback set `SalamanderConfigurationRoots[0] = SALCFG_LEGACY_ROOT` and set a global `CfgMigrateFailed` flag (declared in `src/salamand.h`)
- [X] T013 [US2] Add `IDS_CFGMIGRATE_FAILED` to `src/lang/lang.rc2` in a free slot of an existing bundle (id in `src/lang/texts.rh2`), text with `%s` for the new and old key names, user's terms (contract *Message*)
- [X] T014 [US2] Show the message once per start when `CfgMigrateFailed` after the main window is shown (in `src/salamdr1.cpp`, after `MainWindow->CanClose = TRUE`, `SalMessageBox` with `LoadStr(IDS_CFGMIGRATE_FAILED)`, MB_ICONWARNING), never during an unattended close or a forced exit
- [X] T015 [US1] Build Debug; run saltests (0 failed)
- [X] T016 [US1] Probe rows MIG-BASIC, MIG-AGAIN, MIG-BOTH, MIG-FRESH, MIG-PWD in `specs/343-semver-settings-root/probe/cfgroot343_probe.ps1` (export both trees with `reg export`, normalise the root line, compare byte for byte; `0.1` hash before = after; no window other than the main window; a setting changed via the fixture-import of a value + save lands only in `Settings`)
- [X] T017 [US2] Probe rows MIG-KILL, MIG-FAIL-COPY, MIG-FAIL-COMPARE, MIG-FAIL-RENAME (message window found by its title/class and dismissed by the probe), MIG-CORRUPT-BACKUP in `specs/343-semver-settings-root/probe/cfgroot343_probe.ps1`
- [X] T018 [US1] Run the probe on the hidden desktop → `specs/343-semver-settings-root/probe/result_after.txt`; fix until every row passes; log in `fix-log.md`

## Phase 4: User Story 4 - old configuration files still import (P2)

**Goal**: 0.1.x exports and start-up `config.reg` files import into `Settings`.
**Independent test**: probe rows IMP-LEGACY, IMP-FOREIGN; saltests of the mapping.

- [X] T019 [US4] Add the `legacyRoot` parameter to `Parse` in `src/reglib/src/regparse.h` / `regparse.cpp` (mapping per contract, inside the `INSIDE_SALAMANDER && !_UNICODE` branch, a local buffer `2 * MAX_PATH`, a mapped name that does not fit refuses with `RPE_KEY_OUTSIDE_ROOT`)
- [X] T020 [US4] Pass the legacy root from `ImportConfiguration` in `src/salamdr2.cpp` (both parses) unless the session runs on the legacy root
- [X] T021 [US4] Probe rows IMP-LEGACY (a 0.1.x export given by `-C` at start → values under `Settings`) and IMP-FOREIGN (refused, nothing written) in `specs/343-semver-settings-root/probe/cfgroot343_probe.ps1`; run, record in `result_after.txt`

## Phase 5: User Story 3 - releases by SemVer (P2)

**Goal**: the release tool accepts MINOR/MAJOR steps, warns on non-SemVer steps and on a patch with a feature lead; work collects under `[Unreleased]`.
**Independent test**: `test_release.py`; `release.py status 0.2.0 / 0.1.11 / 0.3.0`.

- [X] T022 [US3] `tools/release/release.py`: remove `line-change`; replace `minorb-skip` by `version-step` (evaluate); add `patch-kind` (check); update the usage text and docstrings that mention `MAJOR.MINORA` line rules
- [X] T023 [US3] `tools/release/test_release.py`: `0.2.0` accepted after `0.1.10`; `version-step` for `0.1.12`, `0.3.0` after `0.1.10`, `0.2.1`; none for `0.1.11`, `0.2.0`, `1.0.0`; `patch-kind` for a patch with lead `Feature release`, none for `Bug-fix release`; run the suite (0 failed)
- [X] T024 [US3] `CHANGELOG.md`: preamble states SemVer (pointing to `backlog/RELEASE.md` *Version numbering*); heading `## [0.1.11] — unreleased` → `## [Unreleased]`
- [X] T025 [US3] `backlog/RELEASE.md`: new section *Version numbering* (contract `versioning.md` rule, the one place); *Release records* row of `CHANGELOG.md` names `[Unreleased]`; *Preparing the tree* step 2 mentions `version-step` instead of the MAJOR/MINORA refusal
- [X] T026 [P] [US3] `.claude/skills/tandem-release/SKILL.md` and `reference.md`: no `line-change`; `version-step` question replaces `minorb-skip`; `patch-kind`; how to choose the number (link to RELEASE.md)
- [X] T027 [P] [US3] `.claude/skills/tandem-backlog-implement/SKILL.md` (entries go under `## [Unreleased]`) and `stop-rules.md` (key name `Settings`)
- [X] T028 [P] [US3] Crash report name: `VERSINFO_SAL_SHORT_VERSION` with dots and the SemVer comment in `src/plugins/shared/spl_vers.h`; `SalFormatBugReportName` accepts dots in `src/common/salbugreport.cpp` (+ header comment in `salbugreport.h`); saltests for `0.2.0X64`, `0.11.0X64` vs `0.1.10X64`, leading / trailing / double dot refused

## Phase 6: User Story 5 - every record, tool, probe and document agrees (P3)

**Goal**: no live reference to the old key or the old version rule.
**Independent test**: quickstart §4 search.

- [X] T029 [US5] Switch the 68 probe scripts in `specs/*/probe/*.ps1` from `Tandem Commander\0.1` / `Tandem Commander\\0.1` to `Settings` with a Python one-off (exact replacements, report per file); leave `result_*.txt` files as history; list the files in `fix-log.md`
- [X] T030 [P] [US5] `PRIVACY.md`: settings under `…\Tandem Commander\Settings`, `Settings\Update Check`, versions 0.1.x used `…\0.1`, which 0.2.0-and-later copies at first start and keeps unchanged as a backup the user may delete; *Removing your data* still covers both (the parent key)
- [X] T031 [P] [US5] `.specify/memory/constitution.md`: replace the last bullet of *Release Documentation* (root version-free, SemVer per RELEASE.md); version 4.0.0 → 4.1.0, *Last Amended* 2026-10-25, Sync Impact Report at the top
- [X] T032 [P] [US5] `CLAUDE.md` (product identity: registry root `…\Settings`, `0.1` read once for migration; one standing-rule line citing 343) and `architecture/12-project-reference.md` (registry root, version rule)
- [X] T033 [US5] Run the quickstart §4 search; fix or justify every hit in `fix-log.md`

## Phase 7: Polish & cross-cutting

- [X] T034 Two-stage `.slt` refresh for `IDS_CFGMIGRATE_FAILED` per `/tandem-backlog-implement` §2.13 (`translate.merge --templates build\tandemcommander\translator\templates --formality prefer_more`, dry run first, read every language back, pin in `translations/ui-overrides.json` if needed)
- [X] T035 `build.cmd full` (Debug) and `build.cmd full release`; saltests 0 failed; `python tools/check_encoding.py --strict` TOTAL 0; `python tools/test_bin_help.py`
- [X] T036 Re-run the full probe on the final Debug build → `probe/result_final.txt`; regression: one older probe that backs up the key (e.g. `specs/312-*/probe`) runs and restores `Settings`
- [X] T037 `CHANGELOG.md` entry under `[Unreleased]` (symptom-free "Settings now live under …\Settings; moved automatically; old key kept as a backup"; limitation: a 0.1.x instance's later changes are not carried over; feature 343)
- [X] T038 Independent refute-first review by an agent (code + probe + records); fix findings; record in `fix-log.md`
- [X] T039 `specs/FEATURE-HISTORY.md` entry 343; backlog item (Inbox) "Remove the old 0.1 configuration key in a later release" via `bin/backlog.sh new` (source `leftover:343`); closing report `specs/343-semver-settings-root/closing-report.md`
- [X] T040 Commit on the feature branch (no push); report to the maintainer

## Dependencies & execution order

- Phase 1 → Phase 2 → Phase 3 (MVP) → Phases 4 and 5 (independent of each other) → Phase 6 → Phase 7.
- T010 depends on T006, T008; T012 on T010; T014 on T013, T012; T016–T018 on T015 and T004/T005.
- T019 → T020 → T021. T022 → T023. T028 independent of Phase 3 code.
- T029 after T003 (helper exists) and before T036.
- T034 after T013; T035 after all code tasks; T038 after T035–T037.

## Parallel opportunities

- T006 ‖ T007; T026 ‖ T027 ‖ T028; T030 ‖ T031 ‖ T032 (different files).

## Implementation strategy

MVP = Phases 1–3 (the migration with its failure handling, proven by the probe). Then the import
mapping (US4) and the release tooling (US3), then records (US5), then translation, full builds,
review and closing.
