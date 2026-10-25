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

## Review 1 (refute-first, independent agent) and fixes

Findings (1 MUST, 3 SHOULD, 4 NIT) - all taken:

- **MUST 1** - a key that could not be read counted as absent (`CfgMigKeyExists` FALSE on any
  error): with `0.1` present the decision became *migrate* and the clean-up `SHDeleteKeyW`'d
  `Settings` and `Settings.backup` (the user's current settings), the rename failed and the
  session ran on stale `0.1` - a fail-open "safe to delete?" check (098). **Fix**: tri-state
  probes (`CfgMigProbeKey`, `ERROR_FILE_NOT_FOUND` only = absent); `NewUnreadable` -> use the new
  root, copy and delete nothing.
- **SHOULD 2** - an unreadable `0.1\Configuration` gave *fresh*: the first save made `Settings` and
  the 0.1 settings were abandoned for good. **Fix**: `LegacyUnreadable` -> `scmaUseLegacy` (the
  session runs on 0.1 as 0.1.x would, its own load error tells the user).
- **SHOULD 3** - a second start during a fallback session moved the configuration under it (what
  the session saved afterwards was lost). **Fix**: the fallback session holds
  `Global\TandemCommanderLegacyCfgSession_<SID>` (`HoldLegacyConfigSession`); a start that finds it
  (or cannot open it) runs on 0.1 too.
- **SHOULD 4** - deleting `Settings` later (a reset, "Remove Configuration" then exit without
  saving) brought the migration-day settings back. **Fix**: the parent key records the move
  (`Moved To Settings`, DWORD); `AlreadyMoved` -> fresh. Written after the commit, and by a start
  that finds a moved root without the record. `PRIVACY.md` names the value.
- NIT 5 - a mapped key name over 2 x MAX_PATH refused the whole import: `Parse` now maps into a
  heap buffer sized to the name (RAII, freed on every return; `RPE_OUT_OF_MEMORY` on failure).
- NIT 6 - "Nothing was deleted" vs the leftover clean-up: leftovers (a `Settings` without
  `Configuration`, an old-run `Settings.backup`) are now removed only at the commit, after both
  copies are complete; a failed move before that deletes nothing but its own side keys.
- NIT 7 - an unreadable old backup blocked every move: the backup is copied into its own side key;
  a failed copy is dropped unless `0.1` carries `Save In Progress` (then the backup is needed for
  the recovery and the move fails).
- NIT 8 (`patch-kind` regex form) - left: the lead's form is fixed by the records contract.

Saltests: the decision is checked over all 64 combinations of the six observations plus named
cases: **28,953 checks, 0 failed**. New Debug seam `exit-after-move` (`ExitProcess(4)` right after
a successful move): the probe compares the moved tree before the program writes anything of its
own - the first post-review run compared while running and saw the new build's own writes
(`Plugins.ver Version (x64)`, a PictView value) after the start: BASIC and KILL AGAIN FAIL, a probe
artefact, not a copy defect.

New probe rows: RESET (deleted Settings not brought back), DENY-NEW (an ACL deny on
`Settings\Configuration`: Settings kept), DENY-OLD (deny on `0.1\Configuration`: no fresh Settings,
0.1 kept; the session's own "Error Loading Configuration" box - one button id 2, which the shared
`Serve` takes for a progress window - is closed by the row), SESSION (a second start while a
fallback session runs does not move). ACL rules are lifted in the probe's `finally` before the
registry restore.

- **Negative control** (the five source files of 8d65a3de built into a scratch copy,
  `probe/result_review1_control.txt`): RESET FAIL (old settings brought back), DENY-NEW FAIL
  (Probe343 deleted from Settings), SESSION SECOND FAIL (the second start made Settings) - all three
  defects reproduced on the pre-fix build.
- **probe/result_final.txt: PASS 36, FAIL 0**, registry restored identical.
  (`result_after.txt` holds the post-review run before the DENY-OLD row was corrected, 35 / 1;
  `result_after_denyold.txt` the corrected row alone, 1 / 0.)

## Review 2 (same agent, the fixes of review 1)

- **SHOULD 1** (race) - the legacy-session mutex was checked before `LoadSaveToRegistryMutex` and
  created by the caller after it was released: a start racing with a failing one could take the
  registry mutex in between and move the configuration while the first ran on 0.1. **Fix**: the
  check runs under the registry mutex, and every path that returns FALSE calls
  `HoldLegacyConfigSession()` before `Leave()` (the caller's call stays, idempotent).
- **SHOULD 2** (by design) - after a move, going back to 0.1.x, deleting `Settings` and starting the
  new version gives defaults (the record makes it a reset); 0.1 stays intact. **Taken as a
  documented limitation** (spec edge case, changelog *Limitation* names the record value that makes
  the next start copy 0.1 again) rather than a new message string.
- NIT 3 (the record written when only the old backup moved) and NIT 4 (a start that finds a running
  legacy session shows the move message) - left: harmless, the reviewer agrees.
- Checked fine by the reviewer: the reordered commit at every crash point, the record's order and
  export behaviour, the mutex name / namespace / access-denied / lifetime, scmaUseLegacy versus
  0.1.10, the RAII buffer in `Parse`.

Final evidence after review 2: Debug build; saltests **28,953 / 0**; **probe/result_final.txt PASS
36, FAIL 0** (registry identical); regression 241 **8 / 0** (no `Settings` left on the machine);
`build.cmd full release` BUILD SUCCEEDED; `check_encoding.py --strict` TOTAL 0; `test_release.py`
44 passed, 1 failed (the pre-existing `test_crlf_records_stay_crlf`, Inbox).

## Completion pass (maintainer, 2026-10-25: "do everything, close it - no new backlog items")

- **Review 2 SHOULD 1** (race) - fixed in the previous pass; the hold now also comes from inside
  `MigrateConfigurationRoot` on every FALSE path before the registry mutex is released.
- **Going back to 0.1.x** - the maintainer: not supported ("once he goes back to 0.1.x, that is his
  problem"). A short-lived variant that re-moved 0.1 when it was written after the move (a
  last-write time in the record) was removed again at his word; the record is a plain DWORD, a
  deleted `Settings` is a reset. Spec edge case, contract and changelog say "not supported".
- **NIT 3** - the record is written only when the root itself moved; the old crash-time backup
  counts only beside its root (as in 0.1.x, where `FindLatestConfiguration` drops a lone backup) -
  a lone `0.1.backup` no longer makes every start copy it again.
- **NIT 4** - a start that finds a running legacy session runs on 0.1 without the move message
  (`MigrateConfigurationRoot(BOOL* tellUser)`).
- **NIT 8** - unchanged by decision: the lead's form is fixed by the records contract.
- **release.py feature range** (was the Inbox item `release-py-plans-a-feature-range-from-125-...`):
  the changelog cites older features as references ("(feature 125)" in a Before text);
  `release_features` keeps only the cited features above the newest feature the previous release's
  section cites. `status 0.2.0`: `features: 244-343 (93)` (242 and 243 have no changelog entry -
  internal tooling). Test `test_release_features_skip_cited_older_ones`.
- **test_crlf_records_stay_crlf** (was the Inbox item): the cause was not the global
  `core.autocrlf` of the test repository (it sets `false`) but the fixture copied from a checkout
  with `core.autocrlf=true` - already CRLF, so writing CRLF changed nothing. `make_repo` writes the
  fixture as git stores it (LF). **`test_release.py`: 46 passed, 0 failed.**
- **Older stand-alone probes**: 17 scripts with their own registry backup (088's `probe_lib`, 092,
  093 x3, 094 x2, 095, 096, 097 x2, 098 `overrun_probe`, 108, 109, 112, 153) copy 0.1 to Settings
  right after their backup export (after its `$LASTEXITCODE` check); 084 `gui_probe` and 089
  `assoc_probe` the same by hand; 080 `config_equivalence` after importing its given backup; 079
  `startup_probe -FreshRegistry` and 084 `make_cfg_fixtures` (they want a fresh configuration)
  delete 0.1 together with Settings. Every probe script that names `\Settings` is covered (search).
- **Backlog**: the three items this feature had added were closed (`remove`): the two fixes with
  `--feature 343`, the removal of the 0.1 key with the maintainer's choice A (the key stays as the
  user's backup; not work to do). The open item `a-refused-configuration-file-...` now names the
  current root.
- New probe row **UPGRADE** (no seam - also runs on the Release build): one start moves the
  settings, five subtrees the program does not rewrite at start are byte-identical, the record is
  set, 0.1 unchanged.

Tests of this pass:
- saltests **28,953 / 0**; `build.cmd full` (Debug) and `build.cmd full release` BUILD SUCCEEDED.
- `cfgroot343_probe.ps1` Debug: **PASS 38, FAIL 0** (`probe/result_final.txt`); Release (rows
  without seams: UPGRADE, FRESH, CORRUPT, RESET, DENY-NEW, DENY-OLD, IMP-LEGACY, IMP-FOREIGN):
  **PASS 14, FAIL 0** (`probe/result_final_release.txt`; the move message shown in Czech).
- `test_release.py` 46 / 0; `check_encoding.py --strict` TOTAL 0; `test_bin_help.py` OK;
  `translate.slt --verify` byte-exact; `backlog.sh check` TOTAL 0.
- The machine's registry after all runs: only `0.1` and `Bug Reporter` under the parent key, no
  value on the parent (no record, no `Settings` left).

### Regression of older probes on the final Debug build

| Probe | Result |
|---|---|
| 241 `pack241_probe` (fix_probe_lib) | 8 / 0, registry identical, no `Settings` left |
| 263 `import263_probe` (the import root rule) | 26 / 0 |
| 312 `tabs312_probe` (Settings\Left Panel\Tabs) | 33 / 0 (as recorded) |
| 313 `qs313_probe -Expect after` | 32 rows, 0 FAIL (as recorded) |
| 095 `longarc_probe` (own backup + the new copy) | 60 / 0 |
| 245 `ci245_e2e` (settings import) | PASS, registry restored |
| 092 `focus_probe` | NEW 10 / 10 PASS; OLD rows run against a pre-343 reference (which already has 092's fix, so "unexpected" passes there) |
| 123 `updcheck_probe` | 237 PASS, 3 FAIL, 12 NOT DRIVEN on the new build; the recorded 123-era result is 238 / 0. Measured against a complete pre-343 reference (worktree at 72a02f2b, built with all language modules): G2 FAIL and H1 FAIL there too (H1 hang **and** slow), so they predate 343 - G2 is blocked by feature 245's first-start import offer (this machine has an Open Salamander configuration), H1 is a timing row. The third FAIL was row J, run with an invalid old program (see below): with the installed 0.1.10, J 2 / 0. |

Trip-ups of the regression itself (not product defects):
- The first old reference (a copy of an incremental Debug build) had only `english.slg`; with the
  machine's Czech configuration it stopped at "LoadLibrary czech.slg (126)" before its main window -
  092's OLD rows and 123's row J could not start it. Replaced by a complete pre-343 build.
- 123's probe writes its result file and screenshots into `specs/123-.../probe/` when no `-Result`
  is given: the overwritten `updcheck_result.txt` and 61 screenshots were restored from git.
- The machine's registry hash changed between the morning runs and the afternoon ones (06DB... ->
  CAFB...) outside any probe (every run restored identical); the installed 0.1.10 used by the
  maintainer writes `0.1`.
