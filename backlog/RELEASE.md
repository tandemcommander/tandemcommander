# Release procedure

The repeated steps of a release and the checks owed at every release.
Collected from `specs/NEXT-WORK.md` and `CLAUDE.md` by feature 242 (the
migration ledger rows `release-checklist` in
`specs/242-backlog-system/migration-ledger.md`); the preparation is the
skill `/tandem-release <x.y.z>` since feature 243. Building, tagging,
publishing and the winget submission are the maintainer's steps; an agent
session only prepares the tree. Steps that need a person and are not
repeated per release are items in `BACKLOG.md` (*Person steps*).

## Current release: 0.2.0 (build 195) — published 2026-10-25

- Published (checked 2026-10-26): tag `v0.2.0` on `origin`, GitHub release
  with `tandemcommander-0.2.0-x64-setup.exe` (not a draft, not a
  pre-release), the installer archived in `setup/output`; `main` and
  `production` on `origin` at the release commit. The **Publish to winget**
  workflow ran on the release and `microsoft/winget-pkgs#461652` (0.2.0) was
  merged the same day; the catalogue holds 0.1.7, 0.1.9, 0.1.10 and 0.2.0.
- The released state is `main` at the commit "Version 0.2.0: the tree
  prepared for the release (2026-10-25)" (prepared by `/tandem-release`). It
  carries features 244–343 (everything since `v0.1.10`). It is the first
  MINOR release under Semantic Versioning (feature 343): the settings move
  once from `…\0.1` to `…\Settings` at the first start.
- Branches that must not be tagged: `release-0.1.10` (on `origin`) —
  feature 132 without 135, whose *Update Thumbnail* damages the maker notes
  of real camera files; `release-0.1.10-final` (on `origin`) — features
  124–142 only, superseded by the release of 0.1.10 from `main`.
- Gating person steps:
  - (none)
- Verified by the skill: `release.py check` 0 findings,
  `check_encoding.py --strict` TOTAL 0. The code was built and tested before
  the run; the maintainer builds the signed program.

## Version numbering

The one statement of the rule (feature 343); the constitution, `CLAUDE.md`,
the changelog preamble and `tools/release/release.py` refer here.

- Versions follow **Semantic Versioning `MAJOR.MINOR.PATCH`** (in the sources
  the upstream names `VERSINFO_SALAMANDER_MAJOR` / `MINORA` / `MINORB` stay).
- **MINOR** (`0.2.0`, `0.3.0`, …): a regular release — new features or
  user-visible changes. A release from `main` is normally a MINOR release.
- **PATCH** (`0.2.1`): fixes only. When `main` already carries features since
  the last release, the patch is made from a branch at the release tag
  (`release-x.y`), with only the fixes picked onto it.
- **MAJOR**: a deliberate break; `1.0.0` when the maintainer declares the
  product stable.
- The build number rises by one with every release, whatever the step.
- The plug-in interface version (`LAST_VERSION_OF_SALAMANDER`) and the
  plug-ins' own versions are independent of the product version.
- The configuration root (`HKCU\Software\Tandem Commander\Settings`) does not
  depend on the version; any step needs no migration. (Versions up to 0.1.10
  kept it under `…\0.1`; 0.2.0 and later copy it once at the first start.)
- `release.py` warns (`version-step`) when the target is not the next PATCH,
  MINOR or MAJOR version of the last release, and (`patch-kind`) when a PATCH
  release's lead does not name a fix; it refuses a version that is not higher
  than the last release or already tagged.
- Finished work adds its changelog entries under `## [Unreleased]`; the
  release turns that heading into `## [x.y.z] — YYYY-MM-DD`.

## Release records

A release changes exactly these eight records, in one commit
(`Version x.y.z: the tree prepared for the release (YYYY-MM-DD)`). This is
the one list; `CLAUDE.md` and the constitution point here, and
`tools/release/release.py` implements it (formats:
`specs/243-tandem-release-skill/contracts/records.md`).

| Record | What the release sets |
|--------|----------------------|
| `src/plugins/shared/spl_vers.h` | `VERSINFO_SALAMANDER_*`, `VERSINFO_BUILDNUMBER` (= the previous release's build + 1) and its history entry naming the version; `LAST_VERSION_OF_SALAMANDER` changes only with the plug-in API |
| `setup/tandemcommander.iss` | `MyAppVersion` |
| `CHANGELOG.md` | one section `## [x.y.z] — YYYY-MM-DD` holding everything unreleased (the `## [Unreleased]` section), opened by the lead `**Build N.** <Kind> release. …` (the winget summary: ≤ 900 characters, no `#`) |
| `PRIVACY.md` | "This statement describes Tandem Commander x.y.z … In <previous>, the version before it, …" and "Last updated YYYY-MM-DD." |
| `CLAUDE.md` | the product line (version, build, release date, features, previous version / build / tag) and *Status* |
| `architecture/12-project-reference.md` | the product line |
| `backlog/RELEASE.md` | *Current release* (heading, state to release, branches not to tag, gating person steps) |
| `release_notes/release_notes_vx.y.z.md` | the GitHub release body (tracked) |

## Preparing the tree

1. Closing pass on the state to release, **before** the skill (it does not
   build or test; as done for 0.1.10 on 2026-10-14, recorded in commit
   `8e5d6c8a`): `build.cmd full` Debug and `build.cmd full release`
   succeed; `saltests` 0 failed; `tools/check_encoding.py` TOTAL 0; the
   probes of the release's features and the regressions they name, on the
   hidden desktop (`tools/run_on_hidden_desktop.ps1`), 0 FAIL. Record every
   FAIL or NOT DRIVEN row with its reason (a known intermittent failure, a
   service not running); a row owed to a person becomes a person step.
2. On `main`, the day of the release: **`/tandem-release <x.y.z>`** (the
   number by *Version numbering*). It refuses a released or lower version, a
   dirty tree and a copyright year that has passed; asks when the step is not
   the next PATCH, MINOR or MAJOR version, when not on `main`, when gating
   person steps are open, and when an open decision concerns the release's
   content; reviews the delta since the previous tag (user-visible changes
   all in the changelog, unapplied drafts, privacy triggers); sets the eight
   records; checks them (`python tools/release/release.py check <x.y.z>`,
   `tools/check_encoding.py --strict`); commits once, locally.
   `--dry-run` shows what it would change.

## Releasing (the maintainer)

1. Merge the release branch if any. **If the release happens on another day
   than the prepared one, run `/tandem-release <x.y.z>` again that day** —
   it moves every date (changelog, `PRIVACY.md`, `CLAUDE.md`, the project
   reference, the release notes) and folds what was added since — and
   commit before tagging.
2. `build.cmd full release sign setup` (signed tree and installer).
3. Tag `v<x.y.z>`.
4. The **Publish to winget** workflow stays **on**: publishing the GitHub
   release (step 5) opens the winget pull request by itself (so it did for
   0.1.10 and 0.2.0). `microsoft/winget-pkgs#426090` (0.1.7) was merged on
   2026-10-08; the old rule to switch the workflow off no longer applies.
5. Publish the GitHub release **with the installer attached** under the
   exact name `tandemcommander-<x.y.z>-x64-setup.exe` (the program's
   new-version check, feature 123, offers a release only then; not a draft,
   not a pre-release); its body is `release_notes/release_notes_vx.y.z.md`.

## After publishing (the maintainer)

- Check the "newer version" notification once with the **previous** Release
  build against the real endpoint (feature 123).
- Run one antivirus scan of the Release build (the core makes an outbound
  connection at start-up since 123); submit false positives of the release
  to the vendors (Avast review: `specs/076-avast-false-positive-review/`).
- winget: check that the workflow run succeeded and follow the pull request
  `PavelStupka.TandemCommander version <x.y.z>` in microsoft/winget-pkgs
  until it is merged. If the run failed, *Run workflow* from `main` (never
  from the tag) or `tools\winget\publish.ps1 -Version <x.y.z> -Submit`. The
  manifest fixes of the 072 audit are the backlog item
  `winget-manifest-fixes-from-072-audit`.
- A bumped tree is not a published release: check the tag and
  `setup/output` (published installers are archived there; rebuilding an
  unbumped version overwrites them — verify the hash against
  `tools/winget/manifests`).

## Standing dates

- The code-signing certificate: renew **with the same certificate identity**
  before **2027-08-03** (antivirus reputation is tied to it).
