# Feature Specification: Version-free configuration root and Semantic Versioning of releases

**Feature Branch**: `343-semver-settings-root`
**Created**: 2026-10-25
**Status**: Draft
**Input**: User description: "Priprav analyzu a implementaci upravy projektu dle kontextu, tedy automaticke prejmenovani registru z 0.1 na Settings, dale upravu projektu a vsech relevantnich casti, dokumentace a skriptu tak, abychom mohli prejit na semver x.y.z cislovani." (Prepare the analysis and implementation: the automatic rename of the registry configuration root from `0.1` to `Settings`, and the change of the project, all relevant parts, documentation and scripts so that the project can move to SemVer x.y.z numbering.)

## Background

The maintainer decided on 2026-10-25 (conversation before this feature) to number releases by
Semantic Versioning: a regular release with new features or visible changes raises MINOR
(`0.2.0`, `0.3.0`), a fixes-only release raises PATCH (`0.2.1`). Until now every release raised only
the third number (0.1.0 … 0.1.10, the tree heads for 0.1.11), however much it carried - 0.1.10
carried features 124–241. The maintainer also decided that the configuration key must not keep a
version number in its name, neither the old `0.1` nor a new one.

Measured on `main` at 72a02f2b (reading the tree; nothing built or run yet):

- **The configuration root carries the version.** All settings live under
  `HKEY_CURRENT_USER\Software\Tandem Commander\0.1` (`src/mainwnd2.cpp:164`, the one-entry array
  `SalamanderConfigurationRoots`). Code reads it through `SalamanderConfigurationRoots[0]` and
  `SALAMANDER_ROOT_REG` in 12 core files (start-up, save, plug-in configuration, export, import of
  a configuration file, the update check state `0.1\Update Check`, the crash-time backup
  `0.1.backup.63A7CD13`, the corrupted-configuration recovery).
- **The release tool refuses SemVer.** `tools/release/release.py:628` refuses any change of
  `MAJOR.MINORA` (`line-change`: "the configuration root follows it - decide the migration
  first"); its test `test_release.py:396` expects `0.2.0` to be refused. The constitution
  (*Release Documentation*, last bullet) states that the registry root "tracks `MAJOR.MINORA`
  only, so a MINORB release MUST NOT move configuration". Changing only the version to `0.2.0`
  would therefore either be refused or, if forced, start the program with empty settings.
- **The upstream upgrade chain is dormant and risky.** `GetUpgradeInfo`,
  `FindLatestConfiguration`, `CImportConfigDialog` and `DeleteOldConfigurations` still exist: a
  second entry in the root array would revive a start-up dialog that offers to import and delete
  older configurations, loading them through the program's own load/save (lossy for anything the
  core does not load itself). Backlog item
  `remove-the-dormant-start-up-import-of-older-open-salamander` records that adding a root back
  would revive them. The rename must not use this chain.
- **A configuration file exported by 0.1.x names the `0.1` root.** The import of a configuration
  file (Options → Import Configuration, and the start-up `config.reg` from the installation
  folder, `%APPDATA%\Tandem Commander` or `-C`) accepts only keys inside the current root
  (feature 263, `salregroot.h`); a 0.1.x export would be refused after the rename.
- **The version appears in many records.** `spl_vers.h` (three numbers, a history entry per
  build), `MyAppVersion` and the installer name (`tandemcommander-<ver>-x64-setup.exe`, which the
  new-version check of feature 123 builds), the changelog heading `## [0.1.11] — unreleased`,
  `PRIVACY.md`, `CLAUDE.md`, `architecture/12-project-reference.md`, `backlog/RELEASE.md`, the
  constitution, the skills `/tandem-release` and `/tandem-backlog-implement`, and the crash report
  name (`TC0110X64-…TXT`: the version's digits run together, so 0.1.10 and 0.11.0 would give the
  same name).
- **Probes write the product's key.** 88 probe files of 69 features (`specs/*/probe`) back up and
  restore `HKCU\Software\Tandem Commander\0.1` by its literal name; after the rename they would
  protect a key the program no longer uses and leave the real one unprotected.
- What already works with three-part versions: the new-version check parses and compares
  `major.minor.patch` numerically (up to 5 digits each, `salupdcheck.h`), the installer and winget
  take any `x.y.z`, `release.py` already reads a `## [Unreleased]` changelog heading.

## Clarifications

### Session 2026-10-25

- Q: What happens to the old key `…\0.1` after a successful migration? → A: It stays unchanged
  as a backup; this feature never deletes it. A later, separate backlog item may remove it
  (option A of three: keep / delete at once after verification / delete automatically in a later
  release). A downgrade to 0.1.x then finds the settings as they were at the migration moment.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Settings survive the update to the first SemVer release (Priority: P1)

A user of Tandem Commander 0.1.x (any of 0.1.0–0.1.10) installs the next release. On its first
start the program finds the settings in the old versioned key, moves them to the version-free key
`HKEY_CURRENT_USER\Software\Tandem Commander\Settings` without asking anything, and starts exactly
as configured before: window layout, panels and tabs, hot paths, user menu, viewers and editors,
plug-in settings, FTP / SFTP connections with their protected passwords and the Master Password,
the update-check state, histories.

**Why this priority**: losing the configuration on an update is the one outcome that would hurt
every existing user; without this story the version cannot change at all.

**Independent Test**: on a test configuration created by 0.1.10 (all areas above filled), start
the new build once; compare the new key with the old one value by value and check the program's
behaviour (the probe of this feature).

**Acceptance Scenarios**:

1. **Given** a configuration only under `…\0.1`, **When** the new version starts for the first
   time, **Then** `…\Settings` holds every key and value of `…\0.1` unchanged (same names, types
   and data), no dialog or question appears (no language choice, no import offer, no
   "import older configuration" dialog), and the program shows the user's own layout and settings.
2. **Given** the migrated configuration, **When** the user changes a setting and restarts,
   **Then** the change is kept and is written only under `…\Settings`.
3. **Given** a configuration under `…\0.1` with saved FTP and SFTP passwords protected by a Master
   Password, **When** the new version starts, **Then** the connections open with the same Master
   Password and no password is lost or asked again.
4. **Given** a configuration under `…\0.1`, **When** the migration has finished, **Then** the
   key `…\0.1` still exists unchanged, as a backup; this version never deletes it.

---

### User Story 2 - The migration never loses or half-applies settings (Priority: P1)

Whatever goes wrong during the first start - the program is killed in the middle of the copy, the
registry refuses a write, the old configuration was left damaged by a crash - the user never ends
up with a half-copied configuration in use, and never with defaults written over their settings.

**Why this priority**: the project's first rule is never to lose the user's data; a migration
that runs once on every machine must fail closed.

**Independent Test**: interrupt the migration at controlled points and make it fail (test seam in
the Debug build); check that the next start completes it from the intact old key.

**Acceptance Scenarios**:

1. **Given** a migration interrupted before it finished, **When** the program starts again,
   **Then** no incomplete `…\Settings` is used; the migration runs again from `…\0.1` and ends
   complete.
2. **Given** a copy that fails (a write refused), **When** the program starts, **Then** it tells
   the user that the settings could not be moved, uses the old configuration for this session
   (settings are read from and saved to `…\0.1` as by 0.1.x) and tries again at the next start;
   nothing is deleted.
3. **Given** `…\0.1` marked as damaged by an interrupted save and a valid crash-time backup
   `…\0.1.backup.63A7CD13`, **When** the new version starts, **Then** the user gets the same
   recovery 0.1.10 would have given (the backup is used), now under the new names.
4. **Given** both `…\Settings` and `…\0.1` exist (e.g. after a downgrade and a new upgrade),
   **When** the program starts, **Then** `…\Settings` is used and nothing is copied over it.
5. **Given** no configuration at all, **When** the program starts, **Then** it behaves as a fresh
   start does today (default settings, the existing first-start offer to import Salamander
   settings of feature 245) and creates only `…\Settings`.

---

### User Story 3 - The maintainer releases by SemVer (Priority: P2)

The maintainer prepares the next release as `0.2.0` with `/tandem-release 0.2.0`, later a
fixes-only `0.2.1`, then `0.3.0`, without the tool refusing a MINOR or MAJOR change, with a
warning when the chosen number does not follow the rules, and with the documentation stating the
rules in one place.

**Why this priority**: it is the purpose of the change, but it only matters once Story 1 makes
a MINOR change safe.

**Independent Test**: run the release tool in dry-run mode on the feature branch for `0.2.0`,
`0.2.1`, `0.3.0`, `1.0.0`, and for invalid steps; check refusals and warnings (tool tests).

**Acceptance Scenarios**:

1. **Given** the last release `0.1.10`, **When** the maintainer prepares `0.2.0`, **Then** the
   tool accepts it and sets every release record; `0.1.11` is also still accepted.
2. **Given** the last release `0.2.0`, **When** the maintainer prepares `0.2.2`, `0.4.0` or
   `0.3.1`, **Then** the tool warns that the step skips a version or does not reset the lower
   numbers, and goes on only after confirmation; a version not higher than the last release stays
   refused.
3. **Given** a PATCH release whose changelog lead names a feature release, **When** the
   maintainer prepares it, **Then** the tool warns that a PATCH release should carry fixes only.
4. **Given** features finished between releases, **When** they add their changelog entries,
   **Then** they add them under a heading that does not name a version (`## [Unreleased]`); the
   release names the version.

---

### User Story 4 - Old configuration files still import (Priority: P2)

A user keeps a configuration file exported by 0.1.x (Options → Export Configuration) or deploys a
`config.reg` written for 0.1.x next to the program. The new version imports it into the new key.

**Why this priority**: exported files are users' backups; refusing them after the update would
silently turn backups into dead files.

**Independent Test**: import a 0.1.10 export through the menu and through the start-up
`config.reg`; check the values under `…\Settings`.

**Acceptance Scenarios**:

1. **Given** a file exported by 0.1.10, **When** the user imports it, **Then** its keys and
   values land under `…\Settings` as if they had been exported from there.
2. **Given** a file naming keys outside the program's root (another program, `HKEY_CLASSES_ROOT`),
   **When** it is imported, **Then** it is still refused as a whole (feature 263 unchanged).
3. **Given** a file exported by the new version, **When** it is imported, **Then** it works as
   today.

---

### User Story 5 - Every record, tool, probe and document agrees (Priority: P3)

After the change no project record, script, skill, probe or document states the old rule (root
tracks `MAJOR.MINORA`, third number per release) or depends on the literal `0.1` key, except
where it describes the old key on purpose (the migration, history).

**Why this priority**: the agents and the maintainer work from these records; a stale rule would
be followed and would break the next release or a probe.

**Independent Test**: search the tree for the old key and the old rule; every hit is a deliberate
historical or migration reference.

**Acceptance Scenarios**:

1. **Given** the finished feature, **When** the tree is searched for `Tandem Commander\0.1` and
   for the `MAJOR.MINORA` rule, **Then** every remaining hit outside `specs/<old features>` and
   release notes of released versions is a deliberate reference to the old key (migration,
   privacy statement, changelog history).
2. **Given** a probe that protects the product's configuration, **When** it runs after the change,
   **Then** it backs up and restores the key the program actually uses (new probes through one
   shared definition).

### Edge Cases

- The program is killed (task end, power cut, sign-out) in the middle of the copy → the partial
  copy is recognisable as incomplete and is never used; the next start repeats the migration.
- A write under `…\Settings` is refused (permissions, policy, registry quota) → fall back to `…\0.1`
  for the session with a message, retry next time, delete nothing.
- `…\0.1` exists but holds no configuration (only an empty key or leftovers) → treated as no
  configuration (fresh start), as 0.1.10 does today.
- `…\0.1` is marked damaged and a valid backup exists → same recovery as before, under the new
  names; if no valid backup exists, the user gets the existing "corrupted configuration" question
  for the new key, never a silent default.
- A 0.1.x instance (another installation or a portable copy) runs while the new version migrates →
  the new version's first start must not be confused by it; settings the old instance saves later
  go to `…\0.1` and are not merged (documented limitation).
- The user downgrades to 0.1.x after the migration → 0.1.x finds `…\0.1` in the state of the
  migration moment (it is kept) and works with it; changes made there are not carried forward
  when the user upgrades again (`…\Settings` wins).
- Two users of one machine → each has their own `HKEY_CURRENT_USER`; each migrates at their own
  first start.
- The configuration is very large (long histories, many FTP sites, thumbnails cache keys) → the
  migration still completes and the start is not noticeably slower than a normal start.
- Group Policy restrictions read by the program live outside the product key → unaffected.
- The update check of 0.1.10 meets the tag `v0.2.0` → it recognises it as newer and offers
  `tandemcommander-0.2.0-x64-setup.exe` (feature 123 contract unchanged).
- Crash reports of 0.1.10 and a future 0.11.0 → the report names must tell the versions apart.

## Requirements *(mandatory)*

### Functional Requirements

**Configuration root**

- **FR-001**: The program MUST keep all its settings under the version-free key
  `HKEY_CURRENT_USER\Software\Tandem Commander\Settings`, and no future version number MUST be
  part of the key name. Changes of the settings' structure keep being handled by the existing
  configuration version number inside the key.
- **FR-002**: At start, before anything reads a setting (language, upgrade information, the
  configuration itself), the program MUST check: if `…\Settings` holds no configuration and
  `…\0.1` does, it MUST copy the whole `…\0.1` tree to `…\Settings` - every subkey and value with
  its name, type and data unchanged, including plug-in configuration, password data and the
  update-check state - without any question or dialog.
- **FR-003**: The migration MUST be all-or-nothing as seen by the program: an incomplete copy
  MUST never be used as the configuration, and the next start MUST recognise and repeat an
  interrupted migration.
- **FR-004**: The migration MUST verify the copy before the program uses it (the copied tree is
  equal to the source).
- **FR-005**: If the migration cannot complete, the program MUST tell the user once per start in
  a translated message, MUST use `…\0.1` as the configuration for that session (read and save,
  as 0.1.x does), MUST retry at the next start, and MUST delete nothing.
- **FR-006**: The crash-time backup (`<root>.backup.63A7CD13`) and the damaged-configuration
  recovery MUST keep working under the new root; a valid backup of `…\0.1` present at migration
  time MUST give the same recovery it gives today.
- **FR-007**: The program MUST NOT write to `…\0.1` after a successful migration.
- **FR-008**: After a successful migration `…\0.1` MUST stay unchanged as a backup; this feature
  MUST NOT delete it (neither at once nor in a later start). Removing it is left to a separate,
  later backlog item, which this feature records. The privacy statement MUST say that the old key
  stays as a backup and that the user may delete it (it is under the key named in *Removing your
  data*).
- **FR-009**: The migration MUST NOT use or revive the dormant upstream upgrade chain (the
  start-up dialog to import and delete older configurations); the list of configuration roots
  the program loads as its own stays one entry.
- **FR-010**: Import of a configuration file (menu and start-up `config.reg`) MUST accept a file
  whose keys are inside `…\0.1` and import it under `…\Settings`; every other root rule of feature
  263 stays (keys of other programs or other root keys refuse the whole file).
- **FR-011**: Export of the configuration MUST write `…\Settings`.
- **FR-012**: The settings import from Altap / Open Salamander (feature 245) and its first-start
  offer MUST behave as today; a migrated configuration counts as an existing configuration (no
  first-start offer after migration).

**Version numbering**

- **FR-013**: The project's version rule MUST be Semantic Versioning `MAJOR.MINOR.PATCH`: MINOR
  for a release with new features or user-visible changes, PATCH for a fixes-only release, MAJOR
  for a deliberate break (1.0.0 when the maintainer declares the product stable). The rule MUST
  be stated in one place (`backlog/RELEASE.md`) and referred to from the constitution, `CLAUDE.md`
  and the changelog preamble.
- **FR-014**: The release tool MUST accept a change of MAJOR or MINOR (no `line-change`
  refusal); it MUST keep refusing a version that is not higher than the last release or already
  tagged.
- **FR-015**: The release tool MUST warn (and the skill ask) when the step is not one of the next
  versions `x.y.(z+1)`, `x.(y+1).0`, `(x+1).0.0`, and when a PATCH release's changelog lead names
  a feature release.
- **FR-016**: Unreleased changelog entries MUST go under `## [Unreleased]`; the release turns it
  into `## [x.y.z] — YYYY-MM-DD`. The current `## [0.1.11] — unreleased` heading MUST become
  `## [Unreleased]`. The skills that add entries (`/tandem-backlog-implement`) and prepare
  releases (`/tandem-release`) MUST say so.
- **FR-017**: The constitution MUST drop the rule that the registry root tracks `MAJOR.MINORA`
  and state that the root is version-free; it is amended with its own version bump and Sync
  Impact Report.
- **FR-018**: The crash report file name MUST identify the version unambiguously (0.1.10 and
  0.11.0 give different names) and stay a valid file name.
- **FR-019**: Component versions that are not the product version (plug-ins' own versions, the
  plug-in interface version `LAST_VERSION_OF_SALAMANDER`, the build number) MUST stay as they
  are; the build number keeps rising by one per release.

**Records, tools, probes, documents**

- **FR-020**: Every probe and tool that backs up, seeds or restores the product's configuration
  MUST protect the key the program uses (`…\Settings`, and `…\0.1` where the probe exercises the
  migration). New probes MUST take the key from one shared definition; existing probes are
  switched to the new key by a mechanical replacement, checked by a search (plan R9).
- **FR-021**: `PRIVACY.md` MUST describe where settings are stored after the change
  (`…\Settings`, the update-check state under it, the fate of `…\0.1`) in the same change.
- **FR-022**: `CLAUDE.md`, `architecture/12-project-reference.md`, `backlog/RELEASE.md`, the
  release-records contract, the skills and `specs/FEATURE-HISTORY.md` MUST describe the new root
  and the SemVer rule; `CHANGELOG.md` MUST carry a user-facing entry under `[Unreleased]`.
- **FR-023**: New user-facing texts (the migration failure message) MUST be translated through
  the project's two-stage translation refresh in this feature.
- **FR-024**: The pure decisions (when to migrate, which source to use, whether a copy is
  complete, mapping of an old-root file line, the next-version rule, the crash report name) MUST
  be covered by automated checks; the end-to-end migration MUST be proven by a probe on the
  hidden desktop against a configuration created by a real 0.1.10 build.

### Key Entities

- **Configuration root**: the registry key under which the program keeps all settings; old
  `…\Tandem Commander\0.1`, new `…\Tandem Commander\Settings`. Holds the configuration subkey,
  plug-in configuration, password data, update-check state, markers of an interrupted save.
- **Crash-time backup**: a sibling key `<root>.backup.63A7CD13` with a completeness marker, used
  when the root is marked damaged.
- **Migration state**: whatever lets the program tell a finished copy from an interrupted one.
- **Release version**: `MAJOR.MINOR.PATCH` plus the build number; set by the release in the
  release records.
- **Changelog section**: `[Unreleased]` while work goes on, `[x.y.z] — date` once released.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After updating from a 0.1.10 configuration, 100% of its keys and values are present
  under the new key with identical data, and the user is asked nothing at the first start.
- **SC-002**: In every interruption and failure scenario of User Story 2 (at least: killed before,
  during and after the copy; a refused write; a damaged source with and without a valid backup),
  the next start ends with the user's complete settings in use and zero values lost.
- **SC-003**: The first start after the update takes no more than one second longer than a normal
  start on a configuration of typical size, and later starts are not slower than before.
- **SC-004**: A configuration file exported by 0.1.10 imports into the new version with all its
  values; a file with a foreign key is still refused.
- **SC-005**: The release tool accepts `0.2.0` after `0.1.10` and `0.2.1` / `0.3.0` / `1.0.0`
  after `0.2.0`, warns on every skipped or non-reset step, and refuses a lower or tagged version.
- **SC-006**: A search of the tree finds no live reference to the `0.1` key or to the old
  version rule outside deliberate historical or migration references.
- **SC-007**: All existing automated checks stay green, and every probe that protects the
  configuration restores the user's key byte for byte after it runs.

## Assumptions

- The next release is `0.2.0`: it carries this migration and features 242–343, so it is a MINOR
  release by the new rule. The version itself is set only by `/tandem-release` on the release
  day; this feature only makes it possible.
- The new key name is `Settings` (the maintainer's choice; not `Configuration`, which already
  names a subkey inside the root). `%APPDATA%\Tandem Commander\Settings backups` is a folder, not a
  registry key, and does not conflict.
- A raw, value-by-value copy of the registry tree is the migration (not a load-and-save through
  the program), so nothing the program does not load itself is lost.
- Password protection does not depend on the key's path (no DPAPI entropy bound to the path in
  the tree), so protected passwords stay valid after the copy; the plan verifies it.
- The installer and uninstaller do not touch `HKEY_CURRENT_USER\Software\Tandem Commander`, so no
  installer change is needed; winget and the update check accept any `x.y.z`.
- Patch releases are made from a branch at the release tag when `main` already carries features;
  the release tool keeps asking when it is not run on `main`.
- Removing the dormant upstream upgrade chain (backlog item
  `remove-the-dormant-start-up-import-of-older-open-salamander`) is a separate item; this feature
  only guarantees not to use it.
- Probes of features older than this one are updated mechanically to the shared key definition;
  their recorded results are history and are not re-run unless the closing pass names them.
