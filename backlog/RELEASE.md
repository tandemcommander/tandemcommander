# Release procedure

The repeated steps of a release and the checks owed at every release.
Collected from `specs/NEXT-WORK.md` and `CLAUDE.md` by feature 242 (the
migration ledger rows `release-checklist` in
`specs/242-backlog-system/migration-ledger.md`); the preparation is the
skill `/tandem-release <x.y.z>` since feature 243. Building, tagging,
publishing and the winget submission are the maintainer's steps; an agent
session only prepares the tree. Steps that need a person and are not
repeated per release are items in `BACKLOG.md` (*Person steps*).

## Current release: 0.1.10 (build 194) — prepared, not published

- The state to release is the local branch **`release-0.1.10-final`** on top
  of `142-pictview-thumb-unicode` (features 124–142). The branch
  **`release-0.1.10`** — also on `origin` — is an earlier state (features
  up to 133, without 134–142) and **must not be tagged**: it holds feature
  132 without 135, whose *Update Thumbnail* damages the maker notes of real
  camera files. **135 must ship with 132.**
- Features after 142 (143–242) are in `CHANGELOG.md` under the next
  version. Which of them join 0.1.10 — 197 (a junction in a deep folder was
  emptied: its target's files deleted, in every release) and 217 (an exit
  that did not end after a failed SSH handshake) above all — is the
  maintainer's decision before the merge:
  `post-142-fixes-joining-0-1-10-decision` (*Decisions for the maintainer*).
  If fixes are picked, run the closing pass (below) again on the result.
- Gating person steps: rows 1–4 of *Person steps* in `BACKLOG.md`; the
  first is the one that matters; the other person steps do not gate this
  release.
  - `pictview-own-photos-pipette-histogram-print` — Update Thumbnail on a
    few own camera photos (135), with the pipette, histogram and print rows;
  - `sftp-test-container-rows-133` — upload into a read-only directory,
    the stale-reason row, Quick Rename to a long name;
  - `plugin-batch-131-rows-needing-volume-or-file` — the rows of 131 that
    need a volume or a special file;
  - `real-keyboard-ime-pass-093-124-130` — the rows 124–130 recorded as NOT
    DRIVEN (real keyboard).

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
| `CHANGELOG.md` | one section `## [x.y.z] — YYYY-MM-DD` holding everything unreleased, opened by the lead `**Build N.** <Kind> release. …` (the winget summary: ≤ 900 characters, no `#`) |
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
2. On `main`, the day of the release: **`/tandem-release <x.y.z>`**. It
   refuses a released version, a dirty tree, a MAJOR/MINORA change and a
   copyright year that has passed; asks when not on `main`, when gating
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
4. Before publishing the GitHub release: switch the **Publish to winget**
   workflow **off** by hand (Actions tab) while
   `microsoft/winget-pkgs#426090` is not settled — and check in the Actions
   tab that it really is off before relying on it (for 0.1.8 this was never
   confirmed).
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
- winget: once #426090 has settled — *Enable workflow*, then *Run
  workflow* from `main` (never from the tag), or
  `tools\winget\publish.ps1 -Version <x.y.z> -Submit`. The pending
  submission and the manifest fixes are backlog items
  (`winget-submit-release-after-pr-426090`,
  `winget-manifest-fixes-from-072-audit`); what to do with the open PR
  itself is the decision `winget-repoint-pr-426090-decision`.
- A bumped tree is not a published release: check the tag and
  `setup/output` (published installers are archived there; rebuilding an
  unbumped version overwrites them — verify the hash against
  `tools/winget/manifests`).

## Standing dates

- The code-signing certificate: renew **with the same certificate identity**
  before **2027-08-03** (antivirus reputation is tied to it).
