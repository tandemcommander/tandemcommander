---
title: Submit the current release to winget once PR #426090 has settled
type: person-step
status: blocked
severity: 4
area: build-release
source: leftover:072
who: person
created: 2026-09-20
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [winget-repoint-pr-426090-decision, winget-manifest-fixes-from-072-audit, winget-per-user-scope-entry, checkver-update-channel-decision]
depends-on: []
reason: waits for microsoft/winget-pkgs#426090
---

# Submit the current release to winget once PR #426090 has settled

## Problem

The catalogue holds only the first submission, 0.1.7 (PR microsoft/winget-pkgs#426090, still open). The releases since (0.1.8 published 2026-09-20, 0.1.9 tagged, 0.1.10 prepared) were deliberately not submitted: the Publish to winget workflow is switched off before a release is published, and a 'release: published' event is not replayed. Once the PR is merged or closed, the current release has to be submitted by hand.

## Evidence

NEXT-WORK §6 (L2002-2026) and the release notes of the 0.1.9 / 0.1.10 preparation (NEXT-WORK L36-60: 'tools\winget\publish.ps1 -Version 0.1.9 -Submit (or the workflow by hand)'; the 0.1.9 templates were dry-run with publish.ps1 -LocalFile, validation succeeded). specs/072-winget-distribution/REMAINING-WORK.md 'Gate: is #426090 merged?' and P0 (audit of what moderation may ask next). specs/072-winget-distribution/fix-log.md (DisplayVersion removal). Migrated from specs/NEXT-WORK.md §6 (at 7993914c).

## Expected

The current release is in the winget catalogue as PavelStupka.TandemCommander; 'winget install tandemcommander' installs it.

## Notes

No release may be published with the Publish to winget workflow enabled while #426090 is open. Run a submission from main, never from a tag (v0.1.8's template still has DisplayVersion). What happens to the OPEN pull request itself - re-pointing it to the current release (072 audit: 0.1.7 does not start without the VC++ runtime, moderators ask for the current release), PrivacyUrl, the `Policy-Test-1.2` waiver - is the decision `winget-repoint-pr-426090-decision`; the template fixes that go into the same push are `winget-manifest-fixes-from-072-audit`. If #426090 is re-pointed and merged, this item submits only the releases newer than the one it carries. The catalogue's per-user entry (072 P2) is `winget-per-user-scope-entry`; checkver (072 P3) is `checkver-update-channel-decision`.

## Steps

- [ ] Check the state of microsoft/winget-pkgs#426090 (gh pr view 426090 -R microsoft/winget-pkgs): merged, closed, or open with new moderator requests (then `winget-repoint-pr-426090-decision` first).
- [ ] In GitHub Actions check that the Publish to winget workflow is disabled and that no second pull request was opened by the 0.1.8 / 0.1.9 / 0.1.10 publications.
- [ ] Once settled: Enable workflow, then Run workflow with version = the current released version and submit = true - or run tools\winget\publish.ps1 -Version <version> -Submit locally, from main.
- [ ] After the merge (allow a few hours for the index): winget install tandemcommander; winget show PavelStupka.TandemCommander.

## Log

- 2026-09-20 — maintainer: switch the Publish to winget workflow off by hand before publishing 0.1.8, so no second pull request opens while #426090 (0.1.7) is open
- 2026-09-24 — #426090 (0.1.7) still open; no pull request for 0.1.8 exists, as intended
- 2026-09-30 — #426090 (0.1.7) still open; the moderator asked to drop DisplayVersion - done the same day in the PR and in templates/installer.yaml.in; awaiting re-review
- 2026-09-30 — P0 audit recorded (072 REMAINING-WORK): re-pointing #426090 to 0.1.8 recommended, not acted on - the maintainer decides
- 2026-10-17 — migrated from specs/NEXT-WORK.md §5–§8 (feature 242)
- 2026-10-17 — migration review M2/N1: re-point steps moved to winget-repoint-pr-426090-decision; P2/P3 steps removed (own items); duplicate state check and the duplicate 2026-09-30 DisplayVersion log line removed; migration remarks replaced by slugs
