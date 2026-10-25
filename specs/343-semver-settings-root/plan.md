# Implementation Plan: Version-free configuration root and Semantic Versioning of releases

**Branch**: `343-semver-settings-root` | **Date**: 2026-10-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/343-semver-settings-root/spec.md`

## Summary

The configuration root `HKCU\Software\Tandem Commander\0.1` carries the version line, and the
release tool and the constitution forbid a MINOR change because of it. The program gets the
version-free root `…\Settings`; a one-time migration at the very start of `WinMainBody` copies the
old tree raw into a side key (`RegCopyTreeW`), compares it value by value, and commits it with one
atomic `RegRenameKey` - the pattern feature 245 already uses for plug-in settings. The old key is
never written after a successful migration and never deleted (clarification A). A failed migration
leaves everything as it was, runs the session on the old root and tells the user once the language
is loaded; the next start retries. Configuration files written for the old root import into the new
one by a line-mapping rule next to feature 263's root rules. The release tool drops `line-change`,
warns on non-SemVer steps and on a feature release numbered as a patch; the changelog collects
work under `## [Unreleased]`; the constitution, `CLAUDE.md`, `RELEASE.md`, the skills,
`PRIVACY.md` and the probes are brought in line. Research: [research.md](research.md) R1-R11.

**Revised after review 1**: tri-state key probes (an unreadable key is never absent), the record
`Moved To Settings` in the parent key, a legacy-session mutex, leftovers removed only at the commit,
the backup copied into its own side key - `contracts/config-root-migration.md`.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143; Python 3 (release tool); PowerShell 5.1 (probes)
**Primary Dependencies**: none new - Win32 registry API (`RegCopyTreeW`, `RegRenameKey`,
`RegEnumKeyExW`, `RegEnumValueW`, all Vista+), the core's reglib `Parse`
**Storage**: Windows registry, `HKEY_CURRENT_USER\Software\Tandem Commander`
**Testing**: saltests (new groups: migration decision, legacy root mapping, bug report name);
`tools/release/test_release.py`; hidden-desktop probe `specs/343-semver-settings-root/probe/cfgroot343_probe.ps1`
(rows in [quickstart.md](quickstart.md)); `tools/check_encoding.py --strict`; `tools/test_bin_help.py`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application + release tooling and project records
**Performance Goals**: the migration adds < 1 s to the first start (a typical configuration is a few
thousand values: copy + compare in tens of ms); later starts add one key lookup
**Constraints**: never lose or half-apply settings (fail closed); no dialog during the migration; no
write under `0.1` after success; no new network communication; plug-in ABI unchanged; `PRIVACY.md`
updated in the same change (what is stored where)
**Scale/Scope**: core files `salamdr1.cpp`, `mainwnd2.cpp`, `salamdr2.cpp`, `consts.h`/`salamand.h`,
`reglib/src/regparse.{h,cpp}`, `callstk.cpp` (name only via macro), `common/salregroot.h`,
`common/salbugreport.cpp`, new `common/salcfgmigrate.h`, `spl_vers.h`, `lang/lang.rc2` +
`texts.rh2`, `saltests.cpp`; `tools/release/release.py` + tests; 1 new and 68 switched probe scripts;
documents listed in research R11

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency or build step - PASS |
| II. Backward compatibility | settings of every 0.1.x configuration are carried over unchanged and the old key stays as a backup; old configuration files keep importing; plug-in ABI unchanged; the identity rule ("never writes Open Salamander / Altap / Newt keys") untouched - PASS |
| III. Incremental modernization | one start-up step and one parse rule; the dormant upstream chain is not revived (it stays for its own backlog item) - PASS |
| IV. Windows commitment | Win32 registry API only - PASS |
| V. Plug-in architecture | plug-in keys copied raw; nothing in the plug-in interface changes - PASS |
| VI. UI consistency | one message box in the program's style, translated through the standard pipeline - PASS |
| Release Documentation | its last bullet (root tracks `MAJOR.MINORA`) is replaced by this feature - **amendment 4.0.0 → 4.1.0** (guidance materially changed, no principle redefined), with a Sync Impact Report; changelog entry under `[Unreleased]` - PASS after the amendment |

Re-check after Phase 1 design: unchanged - PASS.

## Project Structure

### Documentation (this feature)

```text
specs/343-semver-settings-root/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/
│   ├── config-root-migration.md   # keys, decision table, steps, seam, message
│   ├── legacy-root-import.md      # SalRegMapLegacyRoot, Parse legacyRoot
│   └── versioning.md              # SemVer rule, release.py checks, [Unreleased], crash report name
├── checklists/requirements.md
├── fix-log.md                     # running log (implementation)
├── probe/                         # cfgroot343_probe.ps1, fixtures, result_*.txt
└── tasks.md                       # /speckit-tasks
```

### Source Code (repository root)

```text
src/
├── common/salcfgmigrate.h        # NEW pure decision (saltests)
├── common/salregroot.h           # + SalRegMapLegacyRoot
├── common/salbugreport.cpp       # dots in the version tag
├── mainwnd2.cpp                  # roots = "Settings"; SALCFG_LEGACY_ROOT; MigrateConfigurationRoot()
├── salamdr1.cpp                  # call the migration first; show the failure message later
├── salamdr2.cpp                  # ImportConfiguration passes the legacy root
├── reglib/src/regparse.{h,cpp}   # Parse(..., legacyRoot)
├── consts.h / salamand.h         # declarations
├── lang/lang.rc2, texts.rh2      # IDS_CFGMIGRATE_FAILED
├── plugins/shared/spl_vers.h     # SemVer comment, VERSINFO_SAL_SHORT_VERSION with dots
└── saltests/saltests.cpp         # new checks; root literals updated
tools/
├── release/release.py, test_release.py
└── tc_config_key.ps1             # NEW shared key definition for probes
translations/                     # .slt refresh for the new string
specs/*/probe/*.ps1               # 68 scripts: literal 0.1 → Settings
.specify/memory/constitution.md, CLAUDE.md, architecture/12-project-reference.md,
backlog/RELEASE.md, CHANGELOG.md, PRIVACY.md, specs/FEATURE-HISTORY.md,
.claude/skills/tandem-release/*, .claude/skills/tandem-backlog-implement/*
```

**Structure Decision**: the migration lives in `mainwnd2.cpp` next to the other root logic
(`SalamanderConfigurationRoots`, `MyRegRenameKey`, `FindLatestConfiguration`), so no project file
changes; its decision is a header-only rule in `src/common/` with saltests (CLAUDE.md *Working
method*).

## Order of work

1. Measure first: build the pre-change Debug (`main` state) and record with the probe skeleton
   that today a `0.2.0` would start empty-handed (`release.py status 0.2.0` refuses `line-change`;
   a key renamed by hand → fresh start) - `probe/result_before.txt`; write the fixture
   configuration with that build.
2. Pure rules + saltests (decision, mapping, bug report name).
3. Migration + start-up wiring + message + seam; import mapping.
4. Probe rows (quickstart §2), fix until green.
5. Release tool + tests; changelog heading; documents; constitution; skills; probes switched.
6. `.slt` refresh for the new string; `build.cmd full` Debug and Release; saltests; encoding guard.
7. Independent refute-first review; fixes; FEATURE-HISTORY; backlog item for removing `0.1` later.

## Complexity Tracking

No constitution violations to justify.
