# Fix log: 343 - version-free configuration root (Settings) and SemVer releases

Running log of the implementation (2026-10-25). Newest at the bottom.

## Measured before the change (T002)

- `python tools/release/release.py status 0.2.0` at 52668440 (feature branch, sources = `main`
  72a02f2b):
  `refused: line-change: 0.1.10 -> 0.2.0 changes MAJOR.MINORA; the configuration root
  (HKCU\Software\Tandem Commander\0.1) follows it - decide the migration first`.
  (`dirty-tree` too, because `tasks.md` was not committed yet - irrelevant.)

## Implementation (T003-T021)

- Pure rules: `src/common/salcfgmigrate.h` (decision), `SalRegMapLegacyRoot` in `salregroot.h`;
  saltests `TestCfgRoot343` + dotted crash report names: **28,846 checks, 0 failed**.
- Root `Settings` in `mainwnd2.cpp`, `SALCFG_LEGACY_ROOT`; `MigrateConfigurationRoot()` (RegCopyTreeW
  into `Settings.migrating.63A7CD13`, recursive compare, `RegRenameKey`; the old backup copied to
  `Settings.backup.63A7CD13`); called right after `LoadSaveToRegistryMutex.Init()` in `WinMainBody`.
  On failure the session runs on `0.1` (`SalamanderConfigurationRoots[0]` re-pointed) and
  `WM_USER_CFGMIGRATE_FAILED` shows `IDS_CFGMIGRATE_FAILED` (13753, free slot of the bundle of
  `IDS_CORRUPTEDCONFIGFOUND`) when the main window is free (timer `IDT_CFGMIGRATE_FAILED` 954).
- Import: `Parse(..., legacyRoot)` maps key lines of the 0.1 root; `ImportConfiguration` passes it
  unless the session itself runs on the old root.
- Probe fixtures are made at run time (deviation from T005): the pre-change build (copy of the Debug
  build at 52668440 in the session scratchpad) starts on an empty registry and saves; its `0.1` key is
  exported to `%TEMP%\tc343`. No fixture with the maintainer's paths is committed.
- Probe trip-ups fixed in the probe (not in the product): `reg import` writes to stderr (PS 5.1 +
  `Stop` = terminating) -> `cmd /c ... >nul 2>&1`; `Start-Windows` argument order; IMP-FOREIGN's refusal
  comes before the main window exists (wait for it); a row run alone on an empty registry meets the
  first-start import offer of 245 and End-Row answered Yes - the wizard imported Open Salamander
  settings into the probe's key (restored identical); the row now seeds a configuration first.
- **result_after.txt: PASS 28, FAIL 0** (BASIC, AGAIN, BOTH, FRESH, KILL x2, FAIL-copy/compare/rename
  x2 each, CORRUPT, IMP-LEGACY, IMP-FOREIGN + END rows); registry restored identical.
  The whole 0.1 tree (1,994 dump lines incl. Password Manager) equals Settings value by value; no
  window at the first start after the move (no import offer - FR-012).
- **result_before.txt (negative control, pre-change build): BASIC MOVE FAIL, IMP-LEGACY FAIL** -
  the old build makes no Settings and imports under 0.1, as expected.
- Deviation from T009: the feature-263 checks keep their literal `0.1` root - they test the rule
  with a root given as an argument, and `0.1` is still a real root (the mapping source); the new
  root is covered by `TestCfgRoot343`.

## Release tooling and records (T022-T033)

- `release.py`: `line-change` removed; `version-step` (evaluate) replaces `minorb-skip`;
  `patch-kind` (status + check, a warning, not a finding); usage texts say MAJOR.MINOR.PATCH.
  `status 0.2.0` and `0.1.11`: accepted (only branch-not-main / remote-unknown / dirty-tree on the
  feature branch); `status 0.3.0`: `version-step ... (0.1.11, 0.2.0, 1.0.0)`.
- `test_release.py`: 44 passed, 1 failed - `NewVersion::test_crlf_records_stay_crlf` fails the
  same way with the unchanged HEAD files (copied to the scratchpad and run there): its fixture
  commit finds "nothing to commit" on this machine (global `core.autocrlf=true`). Pre-existing,
  environment-dependent; recorded in the backlog Inbox.
- Observation (not changed): `release.py status 0.2.0` plans the product line's feature range as
  `125-343`; 0.1.10 carried 124-241, so the range a 0.2.0 release states should start at 242. The
  release skill sets the range text by judgement; recorded in the Inbox for the release tool.
- `CHANGELOG.md`: SemVer preamble, `## [Unreleased]`, the entry of 343; the 263 entry (same
  release) now names `Settings` and the import of a 0.1.x file.
- `backlog/RELEASE.md` *Version numbering* (the one statement of the rule), the CHANGELOG row,
  *Preparing the tree* step 2. Skills: `/tandem-release` (`version-step`, `patch-kind`, no
  `line-change`, the registry root), `/tandem-backlog-implement` (`## [Unreleased]`, the key name).
- `PRIVACY.md`: where settings are kept (`Settings`, the 0.1 copy kept as a backup, deletable),
  `Settings\Update Check`. Constitution 4.0.0 -> 4.1.0 (Sync Impact Report). `CLAUDE.md`
  (SemVer line, root, standing rule 343), `architecture/12-project-reference.md`.
- Probes: 272 replacements in 122 probe scripts of older features, three forms - the literal
  `Tandem Commander\0.1` (single and doubled backslash, 94 in 68 files), a variable followed by
  `\0.1` (`"$RegKey\0.1\..."`, 158 in 62 files; every variable checked to be the parent key
  `[HKCU\]Software\Tandem Commander`), and `$RegKey + '\0.1\...'` / comments (20 in 13 files).
  No `\0.1` path component is left in `specs/*/probe` outside 343; result files untouched.
  The shared library `fix_probe_lib.ps1` backs up the parent key, so it always covered both roots.
- Search (quickstart §4): every remaining hit is history (older changelog sections, FEATURE-HISTORY,
  the constitution's Sync Impact Report) or the migration itself; the open backlog item
  `a-refused-configuration-file-does-not-say-which-key-is` quotes the old key in its evidence
  (left as recorded).

## Translations (T034)

- Entries: new `IDS_CFGMIGRATE_FAILED` (13753, core `salamand`). Export `--export-templates --module
  salamand`; dry run 1 unique gap per language (~235 chars); real merge `--budget 5800`:
  **DeepL characters sent: 2,216**, validation failures 0.
- Read back in all 8 languages: formal register everywhere, two `%s` kept. Pinned
  (`translations/ui-overrides.json`, `_feature_343`): **sk** "to skúsia znova" (plural) -> "to skúsi
  znova"; **es** "tal y como está" ("as it is") -> "en su ubicación actual". Second merge applied
  the pins; `translate.slt --verify`: round-trip byte-exact (298 files). 16 `.slt`/`.origin` rows
  added, no layout drift in this run.
- `build.cmd full` (Debug): BUILD SUCCEEDED (21 modules x 8 languages).
- `tools/check_encoding.py --strict`: TOTAL 0. `tools/test_bin_help.py`: OK.

## Closing checks (T035-T036)

- `build.cmd full release`: BUILD SUCCEEDED. saltests (Debug): 28,846 checks, 0 failed.
- Regression, feature 241's probe (fix_probe_lib) on the new Debug build: the first run had 3 FAIL
  rows - not a product defect: this machine still holds only `0.1`, so `Set-Config` (gated on
  `Settings\Configuration`) set nothing, the program moved the maintainer's Czech configuration and
  the probe looked for the English "too long". Fixed in the shared library: `Backup-Reg` now, after
  exporting the parent key, copies `0.1` to `Settings` when only `0.1` holds a configuration (what
  the program does at its first start); `Restore-Reg` deletes the parent and imports the backup, so
  the copy never outlives the probe. Re-run: **PASS 8, FAIL 0**, registry identical, no `Settings`
  key left on the machine. Every probe of features 242+ uses this library's `Backup-Reg`
  (`ci245_lib.ps1` seeds its own fresh configuration and needs no copy).
- Older stand-alone probes (079-177 with their own registry backup, about 20 files) do not get the
  copy: on a machine where no 0.2.0-or-later build has kept a configuration yet, they meet an empty
  `Settings` (their Set-Config is skipped or creates a nearly empty configuration). Start such a
  probe after one start of the new build, or copy `0.1` to `Settings` after its backup - recorded
  in `tools/tc_config_key.ps1`.
- Regression, feature 263's import probe (Parse changed): **PASS 26, FAIL 0**, registry identical.
- Side effect found and undone: the earlier lone IMP-FOREIGN run (no configuration, the import offer
  answered Yes by End-Row) had the import wizard write
  `%APPDATA%\Tandem Commander\Settings backups\before-import-20261025-120928.reg` (a backup of the
  probe's fresh default configuration, no user data); 263's REALBACKUP row picked it up. Deleted;
  the folder holds the earlier backups of feature 245's probes as before.
