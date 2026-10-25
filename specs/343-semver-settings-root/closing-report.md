# Closing report: 343 - version-free configuration root (Settings) and SemVer releases

**Branch**: `343-semver-settings-root` (from `main` 72a02f2b) · **Date**: 2026-10-25 · **Not pushed**

## What changed

- **Configuration root** `HKCU\Software\Tandem Commander\Settings` (was `…\0.1`). At the first start
  the old tree is copied raw into `Settings.migrating.63A7CD13`, compared value by value with the
  source, and made the root by one `RegRenameKey`; the old crash-time backup is copied to
  `Settings.backup.63A7CD13`. The old key is never written after a successful move and never
  deleted (maintainer's clarification A). A failed move leaves nothing behind, runs the session on
  `0.1` and shows `IDS_CFGMIGRATE_FAILED` once the main window is free; the next start retries.
  An interrupted move (killed mid-copy) leaves only the side key, which the next start deletes
  before moving again. Code: `MigrateConfigurationRoot` (`src/mainwnd2.cpp`), the call at the very
  start of `WinMainBody` (`src/salamdr1.cpp`), decision `src/common/salcfgmigrate.h`.
- **Import** of a configuration file written for `0.1` (menu, start-up `config.reg`, `-C`) maps its
  key lines into `Settings` (`SalRegMapLegacyRoot`, `Parse(..., legacyRoot)`); feature 263's root
  rule is otherwise unchanged.
- **SemVer**: the rule is stated once in `backlog/RELEASE.md` *Version numbering*;
  `tools/release/release.py` accepts MINOR/MAJOR steps (no `line-change`), warns `version-step` and
  `patch-kind`; the changelog collects work under `## [Unreleased]`; constitution 4.1.0; skills,
  `CLAUDE.md`, the project reference and `PRIVACY.md` updated.
- **Crash report names** carry the dotted version (`TC0.2.0X64-…TXT`).
- **Probes**: 272 replacements in 122 older probe scripts; `fix_probe_lib.ps1`'s `Backup-Reg` copies
  `0.1` to `Settings` after its backup on a machine that has not moved yet; `tools/tc_config_key.ps1`
  defines the keys once for new probes.

## Evidence

| Check | Result |
|---|---|
| saltests (Debug) | 28,953 checks, 0 failed (new: `TestCfgRoot343` - all 64 decision combinations, the legacy-root mapping; dotted bug report names) |
| `cfgroot343_probe.ps1` (hidden desktop) | **36 PASS / 0 FAIL** (`probe/result_final.txt`; rows BASIC, AGAIN, BOTH, FRESH, KILL, FAIL-copy/compare/rename, CORRUPT, RESET, DENY-NEW, DENY-OLD, SESSION, IMP-LEGACY, IMP-FOREIGN) |
| negative controls | pre-change build: BASIC and IMP-LEGACY FAIL (`probe/result_before.txt`); pre-review-fix build: RESET, DENY-NEW, SESSION FAIL (`probe/result_review1_control.txt`) |
| regression 241 (`fix_probe_lib`) | 8 / 0 on the final build (first run 5 / 3: the transition, fixed in `Backup-Reg`, see fix-log) |
| regression 263 (import root rule) | 26 / 0 |
| `test_release.py` | 44 passed, 1 failed - `test_crlf_records_stay_crlf`, fails identically at HEAD (machine `core.autocrlf=true`; Inbox) |
| `build.cmd full` Debug / `build.cmd full release` | BUILD SUCCEEDED / BUILD SUCCEEDED |
| `check_encoding.py --strict` | TOTAL 0 |
| `test_bin_help.py` | OK |
| translations | 1 new string x 8 languages, 2,216 DeepL characters, 2 pins (sk, es), `slt --verify` byte-exact |
| refute-first review | see *Review* |

## Review

Two refute-first rounds by an independent agent.

- Round 1: **MUST 1** (an unreadable `Settings\Configuration` counted as absent -> the clean-up
  deleted the user's current settings), SHOULD 2 (an unreadable `0.1` abandoned for good), SHOULD 3
  (a second start moved under a fallback session), SHOULD 4 (a deleted `Settings` refilled from
  `0.1`), NITs 5-8. Fixed: tri-state probes, `scmaUseLegacy`, the legacy-session mutex, the record
  `Moved To Settings`, leftovers removed only at the commit, the backup in its own side key, a heap
  buffer in `Parse`. All three behavioural defects reproduced on the pre-fix build (negative
  control) and pass on the fixed one.
- Round 2: SHOULD 1 (a race between the session mutex and the registry mutex) fixed - the check
  and the hold happen under the registry mutex; SHOULD 2 (going back to 0.1.x and deleting
  `Settings` gives defaults) taken as a documented limitation; NITs left.

## Left for later (Inbox)

- `remove-the-old-0-1-configuration-key-in-a-later-release` (clarification A).
- `test-release-py-test-crlf-records-stay-crlf-fails-where-core` (pre-existing test fragility).
- `release-py-plans-a-feature-range-from-125-for-the-release` (the planned range of the next release
  starts at 125, should start at 242).

## Decision for the maintainer (optional)

- Review 2's SHOULD 2 was taken as a documented limitation: after the move, a user who goes back to
  0.1.x and then deletes `Settings` gets default settings, not the later 0.1.x ones (they stay in
  `0.1`). If you prefer a one-time notice in that case, it is a new UI string (translation round).

## For the maintainer

- The next release can be **0.2.0** (`/tandem-release 0.2.0`); `release.py status 0.2.0` accepts it.
- Older stand-alone probes (features 079-177 with their own registry backup) meet an empty `Settings`
  on a machine where no 0.2.0-or-later build has kept a configuration yet - start such a probe after
  one start of the new build (`tools/tc_config_key.ps1`).
- Nothing was pushed; the branch holds the feature's commits.
