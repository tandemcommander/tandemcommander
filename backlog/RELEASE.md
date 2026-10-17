# Release procedure

The repeated steps of a release and the checks owed at every release.
Collected from `specs/NEXT-WORK.md` and `CLAUDE.md` by feature 242 (the
migration ledger rows `release-checklist` in
`specs/242-backlog-system/migration-ledger.md`). Building, tagging,
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
- Before publishing, these four person steps (rows 1–4 of *Person steps* in
  `BACKLOG.md`; the first is the one that matters), then the checks below:
  1. `pictview-own-photos-pipette-histogram-print` — Update Thumbnail on a
     few own camera photos (135), with the pipette, histogram and print rows;
  2. `sftp-test-container-rows-133` — upload into a read-only directory,
     the stale-reason row, Quick Rename to a long name;
  3. `plugin-batch-131-rows-needing-volume-or-file` — the rows of 131 that
     need a volume or a special file;
  4. `real-keyboard-ime-pass-093-124-130` — the rows 124–130 recorded as NOT
     DRIVEN (real keyboard).

  The other person steps do not gate this release.

## Preparing the tree (an agent may do this)

1. Bump, **in the same change** as the `CHANGELOG.md` entry
   (`## [x.y.z] — YYYY-MM-DD`): `VERSINFO_SALAMANDER_*` and
   `VERSINFO_BUILDNUMBER` (comment naming the version) in
   `src/plugins/shared/spl_vers.h`, `MyAppVersion` in
   `setup/tandemcommander.iss`, the product line in `CLAUDE.md`, the
   validity line of `PRIVACY.md`, and `architecture/12-project-reference.md`.
   `LAST_VERSION_OF_SALAMANDER` changes only with the plug-in API.
2. Draft the GitHub release notes (`temp/release_notes_v<x.y.z>.md`, not
   tracked).
3. Review the `<previous tag>..HEAD` delta before the release (the pattern of
   feature 056): user-visible changes all in the changelog, nothing
   unfinished, no stale claims.
4. `tools/winget/publish.ps1` reads the release date from the changelog
   heading and the release summary from its lead paragraph (≤ 900
   characters) — keep both right. A dry run:
   `tools\winget\publish.ps1 -Version <x.y.z> -LocalFile <installer>`.
5. Closing pass on the state to release (as done for 0.1.10 on 2026-10-14,
   commit `4c852fe9`): `build.cmd full` Debug and `build.cmd full release`
   succeed; `saltests` 0 failed; `tools/check_encoding.py` TOTAL 0; the
   probes of the release's features and the regressions they name, on the
   hidden desktop (`tools/run_on_hidden_desktop.ps1`), 0 FAIL. Record every
   FAIL or NOT DRIVEN row with its reason (a known intermittent failure, a
   service not running); a row owed to a person becomes a person step.

## Releasing (the maintainer)

1. Merge the release branch; **if the release happens on another day than
   the changelog says, change the date in the changelog heading,
   `PRIVACY.md` ("Last updated …"), the product line of
   `CLAUDE.md` ("release dated …") and `architecture/12-project-reference.md`**.
2. `build.cmd full release sign setup` (signed tree and installer).
3. Tag `v<x.y.z>`.
4. Before publishing the GitHub release: switch the **Publish to winget**
   workflow **off** by hand (Actions tab) while
   `microsoft/winget-pkgs#426090` is not settled — and check in the Actions
   tab that it really is off before relying on it (for 0.1.8 this was never
   confirmed).
5. Publish the GitHub release **with the installer attached** under the
   exact name `tandemcommander-<x.y.z>-x64-setup.exe` (the program's
   new-version check, feature 123, offers a release only then).
6. Release notes: the installer's SHA-256 and a VirusTotal link.

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
