# Research: Version-free configuration root and Semantic Versioning of releases (343)

All findings were read from the tree at 72a02f2b (`main`) on 2026-10-25.

## R1 - How the migration copies the tree

**Decision**: a raw copy of the registry tree with the wide API: `RegCopyTreeW` from
`HKCU\Software\Tandem Commander\0.1` into a side key `HKCU\Software\Tandem Commander\Settings.migrating.63A7CD13`,
a recursive compare of the side key with the source (value names, types and data; subkey names),
then `RegRenameKey(side → Settings)` as the single commit point.

**Rationale**:
- `RegRenameKey` is atomic: `Settings` either does not exist or is complete. The project already
  uses this exact pattern for the plug-in part of the Salamander settings import
  (`src/cfgimport.cpp:3205-3260`, feature 245: side key `.tc-import-new`, rename swap,
  leftovers repaired at the next run).
- A raw copy keeps everything: values the core never loads itself (`.hidden` keys, plug-in keys of
  plug-ins not loaded in this session, the update-check state, the crash-time markers), every type
  (`REG_BINARY`, `REG_MULTI_SZ`, `REG_QWORD`, ...), names outside ASCII. The wide API avoids any
  code-page conversion of names (CLAUDE.md *Text and names*).
- The compare makes FR-004 concrete and catches a copy cut short by the registry (quota, a key
  refused) before anything uses it.

**Alternatives considered**:
- *Revive the upstream chain* (`SalamanderConfigurationRoots[1] = "...\\0.1"`, which makes
  `FindLatestConfiguration` show `CImportConfigDialog` and load the old key through `LoadConfig`
  / `SaveConfig`): rejected - a dialog (FR-002 says no question), a lossy load-and-save of only
  what the program loads, and the dialog can delete configurations; backlog item
  `remove-the-dormant-start-up-import-of-older-open-salamander` warns against reviving it (FR-009).
- *`MyRegRenameKey`* (`mainwnd2.cpp:899`, `SHCopyKey` + delete): not atomic (the target appears key by
  key) and it deletes the source - the old key must stay (clarification A).
- *Copy straight into `Settings` with an in-progress marker value*: works, but every reader of the
  root would have to respect the marker; the side key plus rename keeps the rule in one place.
- *A completeness marker inside the side key*: unnecessary - the side key is never read as a
  configuration; it is either renamed after the compare or deleted.

## R2 - When the migration runs and which source counts

**Decision**: `MigrateConfigurationRoot()` runs in `WinMainBody` (`src/salamdr1.cpp`) right after
`LoadSaveToRegistryMutex.Init()` and before `GetUpgradeInfo` - the first code that reads the root
(the language key at `salamdr1.cpp:4109`, `AutoImportConfig`, the start-up `config.reg` import,
`FindLatestConfiguration`) runs after it. It runs inside `LoadSaveToRegistryMutex`.

The decision is a pure function (`src/common/salcfgmigrate.h`, saltests) of what is in the registry:

| `Settings` has `Configuration` | `0.1` has `Configuration` or `0.1.backup.63A7CD13` exists | Action |
|---|---|---|
| yes | any | **use new** (leftover side keys are deleted) |
| no | yes | **migrate** |
| no | no | **fresh** (use new; nothing copied) |

"Has a configuration" is the upstream definition (`FindLatestConfiguration`: a key counts only
when its `Configuration` subkey exists - the bare key may hold only `AutoImportConfig`). A
`Settings` key without `Configuration` is a leftover with no settings in it (it can only come from
a crash between creating and filling it, which the side key prevents, or from a hand edit); it is
replaced by the migration.

**Rationale**: the mutex is the existing cross-process lock of load/save, global per user SID
(`dialogs4.cpp:186`); it also serialises two new instances started at once and a 0.1.x instance
saving at the same moment (same mutex name in both versions). Running before anything else reads
the root keeps all later code unchanged: it only sees `SalamanderConfigurationRoots[0]`.

**Alternatives considered**: running inside `FindLatestConfiguration` (too late - the language and
`AutoImportConfig` were read before); running in the installer (does not cover a copied
installation, needs the user's hive while elevated - rejected).

## R3 - The crash-time backup and a damaged source

**Decision**: when `0.1.backup.63A7CD13` exists, it is copied raw to `Settings.backup.63A7CD13`
(with its `Copy Is OK` marker) before the main rename; a leftover `Settings.backup.63A7CD13` from an
interrupted migration is deleted first (no genuine new-root backup can exist while `Settings` holds
no configuration). The source is copied as it is, also when it carries `Save In Progress`.
`0.1.corrupted.63A7CD13` is not copied (it is never read).

**Rationale**: `FindLatestConfiguration` then meets the same state under the new names that 0.1.10
meets under the old ones: a damaged root with a valid backup is swapped silently, a damaged root
without one gets the existing `IDS_CORRUPTEDCONFIGFOUND` question (FR-006, US2-3).

## R4 - What happens when the migration fails

**Decision**: any failure (copy, compare, rename, out of memory) deletes the side keys it made
and leaves `0.1` untouched; the program then sets `SalamanderConfigurationRoots[0]` to the old
root string for this session, so the whole start (language, `FindLatestConfiguration`, load, save,
update check, crash backup) works on `0.1` exactly as in 0.1.10. A flag makes the main window show
one translated message (`IDS_CFGMIGRATE_FAILED`) once the language module is loaded (it is not
loaded yet when the migration runs - the language itself is a setting). The next start tries
again (the decision table says *migrate* again).

**Rationale**: fail closed without blocking the user: nothing is deleted, the user's own settings
are in use, and the problem is visible. `SalamanderConfigurationRoots` is an array of pointers
(`const char*`), so its element can be re-pointed; `salamdr1.cpp:4373` compares
`SALAMANDER_ROOT_REG != SalamanderConfigurationRoots[0]` by pointer, which stays consistent
because `FindLatestConfiguration` returns that very pointer.

**Alternatives considered**: refusing to start (blocks the user for a registry problem they may
not be able to fix); starting with defaults (would later save defaults over nothing, but the user
would lose their working set for the session - rejected).

**Debug seam**: environment variable `TC_CFGMIGRATE_FAIL_AT` = `copy` / `compare` / `rename` /
`kill-after-copy` (Debug builds only, as `TC_UPDATECHECK_PRETEND_VERSION` of feature 123) makes the
step fail, or ends the process right after the copy (`ExitProcess`, an interrupted migration).

## R5 - Protected passwords after the copy

**Decision**: no special handling. **Measured by reading**: the Password Manager
(`src/pwdmngr.cpp`) encrypts with AES keyed by the Master Password and a random salt stored with
each password (`PWDMNGR_SIGNATURE_ENCRYPTED`, lines 496-579); no DPAPI call exists in the tree
outside `dep/` (`CryptProtectData` not found), nothing binds the data to the key path. The probe
still checks that the copied `Password Manager` subkey is byte-identical and that the program opens
with the same Master Password verifier (US1-3).

## R6 - Old configuration files

**Decision**: `Parse` (`src/reglib/src/regparse.cpp`) gets an optional `legacyRoot`; a key line or
delete line that is not inside `onlyUnderHKCU` but is inside `HKEY_CURRENT_USER\<legacyRoot>` is
rewritten to the same path under `onlyUnderHKCU` before it is acted on. The pure rule is
`SalRegMapLegacyRoot` in `src/common/salregroot.h` (saltests), next to the feature-263 rules it
extends. `ImportConfiguration` (`salamdr2.cpp:3169`, `3195`) passes the old root for both the
memory parse and the registry parse; the check "the file contains our configuration"
(`memReg->OpenKey(... SalamanderConfigurationRoots[0] ...)`) then sees the mapped keys.

**Rationale**: a 0.1.x export starts with `[-HKEY_CURRENT_USER\Software\Tandem Commander\0.1]`
(delete line of the root) followed by the root's keys; mapping every line gives exactly the import
of a new export. Every other root rule of feature 263 stays (a key of another program or another
hive refuses the whole file). Parent lines (`[HKEY_CURRENT_USER\Software\Tandem Commander]`)
are already accepted as parents of both roots.

**Alternatives considered**: rewriting the file text before parsing (touches values that merely
contain the text; the line rule is precise).

## R7 - Release tool and version rule

**Decision**:
- `release.py evaluate`: remove `line-change`; replace `minorb-skip` by `version-step` - a warning
  unless the target is one of `x.y.(z+1)`, `x.(y+1).0`, `(x+1).0.0` relative to the previous
  release; keep `not-higher` and `tag-exists`.
- `release.py check`: new warning `patch-kind` when the target is a PATCH step and the lead's Kind
  (`**Build N.** <Kind> release.`) does not say a fix (`Bug-fix`, `Installer-fix`, or contains
  `fix`).
- The changelog keeps its formats; features add entries under `## [Unreleased]` (already parsed:
  `release.py:295`, label `Unreleased`, no date). The existing `## [0.1.11] — unreleased`
  becomes `## [Unreleased]`.
- `test_release.py`: the `line-change` case becomes "0.2.0 accepted"; new cases for
  `version-step` and `patch-kind`.

**Rationale**: SemVer steps are the maintainer's choice; the tool prevents mistakes (a skipped or
non-reset number, a feature release numbered as a patch) without forbidding a deliberate choice -
the same register as the existing warnings.

## R8 - Crash report name

**Decision**: `VERSINFO_SAL_SHORT_VERSION` becomes `MAJOR "." MINORA "." MINORB` + platform
(`0.2.0x64` → `TC0.2.0X64-20261025-143007.TXT`); `SalFormatBugReportName` accepts `.` inside the
version tag (not first, not last, never two in a row). The only user of the macro is
`callstk.cpp:833`.

**Rationale**: digits run together are ambiguous once a component has two digits (0.1.10 and
0.11.0 both gave `TC0110X64`); a dot is a valid file-name character and keeps the name readable.
The function stays CRT-free (it runs in the crash filter).

## R9 - Probes and tools

**Decision**: a dot-sourced helper `tools/tc_config_key.ps1` defines the key once
(`$TcConfigKeyName = 'Software\Tandem Commander\Settings'`, the PowerShell-provider and `reg.exe`
forms, and the legacy `0.1` forms); the probe of this feature uses it. The 68 existing probe
scripts that name the key by its literal (69 features; 20 further hits are recorded result files,
which stay as history) are switched by a mechanical one-to-one replacement
`Tandem Commander\0.1` → `Tandem Commander\Settings` (both the single- and the doubled-backslash
form), verified by a search that finds no live literal afterwards.

**Rationale**: the literals come in many forms (`HKCU:\...` provider paths, `reg.exe` arguments,
`.reg` text in here-strings with doubled backslashes, `[HKEY_CURRENT_USER\...]` lines); rewriting
each file to dot-source a helper is a large, error-prone edit of scripts that only run in a
closing pass, while the literal replacement is mechanical and checkable. The spec's FR-020 is
amended accordingly (new probes use the helper; old ones are switched to the key the program uses).

## R10 - Translation of the new message

**Decision**: one new core string `IDS_CFGMIGRATE_FAILED` in a free slot of an existing string
bundle of `src/lang/lang.rc2` (no new bundle, CLAUDE.md feature 084), then the two-stage `.slt`
refresh of `/tandem-backlog-implement` §2.13 (`translate.merge --templates <build>\tandemcommander\translator\templates --formality prefer_more`) in this feature, with the
text read back in every enabled language.

## R11 - Records and documents that state the old rule or the old key

Found by searching the tree (excluding `specs/` of older features, `.claude/worktrees`, release
notes of released versions and `temp/`):

| Place | Change |
|---|---|
| `.specify/memory/constitution.md` | *Release Documentation* last bullet → root is version-free, SemVer rule by reference; amendment 4.0.0 → 4.1.0 with Sync Impact Report |
| `CLAUDE.md` | product identity (registry root `…\Settings`, old `0.1` read once for migration), standing rule line (343) |
| `architecture/12-project-reference.md` | registry root, versioning |
| `backlog/RELEASE.md` | new section *Version numbering* (the one place, FR-013); release records row of `CHANGELOG.md` mentions `[Unreleased]` |
| `CHANGELOG.md` | preamble (SemVer), `[0.1.11] — unreleased` → `[Unreleased]`, entry of 343 |
| `PRIVACY.md` | where settings are stored, `Settings\Update Check`, the old key kept as a backup |
| `src/plugins/shared/spl_vers.h` | the comment on the version scheme (SemVer), the short version macro |
| `src/common/salregroot.h` comment, `src/mainwnd2.cpp:164-168` | the new root |
| `.claude/skills/tandem-release/SKILL.md`, `reference.md` | no `line-change`; `version-step`, `patch-kind`; choosing the number |
| `.claude/skills/tandem-backlog-implement/SKILL.md`, `stop-rules.md` | `## [Unreleased]`; the key name |
| `tools/release/release.py`, `test_release.py` | R7 |
| `specs/FEATURE-HISTORY.md` | entry 343 |
| backlog | new item: remove the old `0.1` key in a later release (clarification A) |

`setup/tandemcommander.iss` needs no change (it never touches `HKEY_CURRENT_USER\Software\Tandem
Commander`; `MyAppVersion` already takes any `x.y.z`). The new-version check (`salupdcheck.h`)
already compares three numbers numerically (5 digits each), so 0.1.10 recognises `v0.2.0`.
