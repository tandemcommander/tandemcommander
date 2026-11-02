# Closing report - 399-zip-symlink-archive
Backlog item: zip-cannot-update-an-archive-reached-through-a-symbolic-link - ZIP cannot update an archive reached through a symbolic link
Outcome: closed

## What changed

- `src/common/salsafereplace.h`: `SalReplaceFollowsName` (pure - a name that is a reparse point, not a
  folder, with a name-surrogate tag), `SalFinalPathPlainW` (pure - `\\?\C:\...` -> `C:\...`,
  `\\?\UNC\srv\...` -> `\\srv\...`, anything else NULL), `SalReplaceTargetOfLinkW` (the reparse tag of
  the name + the final path of the open handle). Existing functions unchanged.
- ZIP plug-in (`add.cpp`, `add_del.cpp`, `add_del.h`): `CZipPack::ReplaceTarget`. `CreateTempFile`
  resolves a file-link archive name once (archive open), makes `Sal*.tmp` in the real archive's
  folder and takes the real archive's attributes; `ReplaceArchiveWithTemp` replaces the real archive
  and restores its attributes / newest time there. Messages keep the name the user used.
- `src/saltests/saltests.cpp`: `TestSafeReplace399`.
- No UI string, no resource, no registry, no plug-in interface change.

## Measurements (before / after, commands)

- Before (main 2a5b7d40), hidden-desktop probe `probe/zipsymlink_probe.ps1`
  (`tools\run_on_hidden_desktop.ps1`): 14 PASS / 4 FAIL - add / delete through an absolute and a
  relative file link: "Cannot replace original archive with temporary working file. Archive was not
  changed.", the real archive unchanged (`probe/result_before.txt`).
- After: 18 PASS / 0 FAIL - the real archive updated, the link still the same link, nothing new, no
  message; plain, junction and held-archive rows as before (`probe/result_after.txt`, re-run after
  the review fix). Registry restored and identical in every run.
- 320's probe `zipreplace_probe.ps1` on the new build: 12 / 0 (`probe/result_320_regression.txt`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> BUILD SUCCEEDED (only the pre-existing C4018 warnings of `salamdr2.cpp`).
- `saltests.exe` -> `saltests: 282271 checks, 0 failed`.
- Probes: 18 / 0 (399), 12 / 0 (320).
- No translation refresh needed (no UI text changed).

## Reviews (findings and what was done)

Review 1 (refute-first): no MUST, no SHOULD. NOTE 1 (the real archive's attributes read through the
plain path - with long paths disabled and a 260+ character target a hidden / system attribute would
be dropped) -> fixed (read through the `\\?\` form), rebuilt, probe 18 / 0, saltests 0 failed.
NOTE 2 (Pack's Overwrite into a link name, a cancelled pack into an empty archive through a link) ->
Inbox. The reviewer also proved FR-005 with a hidden real archive and resolved link chains, a link to
another volume, a SUBST drive and a UNC target.

## Owed to a person (with the new person-step items)

- `delete-the-review-scratch-folder-rev399scratch-eb-on-drive-e` - delete the reviewer's scratch
  folder `E:\rev399scratch_eB` (one 4-byte test file; the run's sandbox refused).
- Add the CHANGELOG entry below (no `## [Unreleased]` section exists; versions are the maintainer's):

  - **Adding files to or deleting files from a ZIP archive reached through a symbolic link failed
    with "Cannot replace original archive with temporary working file"** (feature 399). The ZIP
    plug-in now updates the archive the link leads to and the link stays a link; the temporary file
    is made next to the real archive. Choosing Overwrite in Pack for a link name still replaces the
    link itself.

## New Inbox items (slug - title)

- `pack-overwrite-into-an-archive-reached-through-a-symbolic` - Pack Overwrite into an archive
  reached through a symbolic link replaces the link
- `delete-the-review-scratch-folder-rev399scratch-eb-on-drive-e` - Delete the review scratch folder
  rev399scratch_eB on drive E
