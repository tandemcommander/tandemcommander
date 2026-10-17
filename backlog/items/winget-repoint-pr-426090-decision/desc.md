---
title: winget: re-point the open PR #426090 to the current release (072 audit)?
type: decision
status: open
severity: 4
area: build-release
source: leftover:072
who: person
created: 2026-10-17
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [winget-manifest-fixes-from-072-audit, winget-submit-release-after-pr-426090, winget-records-stale-claims-from-072-audit]
depends-on: []
reason: -
---

# winget: re-point the open PR #426090 to the current release (072 audit)?

## Problem

The only winget submission, microsoft/winget-pkgs#426090, is for 0.1.7 and still open. The audit of 2026-09-30 (072 §P0, "NOT ACTED ON - the maintainer decides when") found what moderation is likely to ask next: (P0.1, highest risk) 0.1.7 does not start without the Visual C++ runtime - tag `v0.1.7` has no `copy_vc_runtime.cmd`, the manifest declares no `Microsoft.VCRedist.2015+.x64` dependency, and moderators launch new packages (#425232: exit code -1073741515, DLL not found); (P0.2) moderators ask for the current release (#424958 after the same `DisplayVersion` comment, also #428418, #427695); (P0.3) a `PrivacyUrl` may be required for products that store credentials. Two manifest inaccuracies would be fixed in the same push: (P0.6) `AppsAndFeaturesEntries.DisplayName` differs from what the installer writes, (P0.7) `ProductCode` only in `AppsAndFeaturesEntries`, not at installer level. The audit's plan acts on the OPEN pull request; nothing happens until the maintainer chooses.

## Evidence

`specs/072-winget-distribution/REMAINING-WORK.md` §P0 (L39-170): *Likely moderator requests* 1-3, *Corrections* 4 (`Policy-Test-1.2` is not about the certificate; resolved by an administrator waiver), 6, 7, *Recommended plan* 1-4 (L139-155). NEXT-WORK §6 L2012-2020 at 7993914c ("Recommended: re-point #426090 to 0.1.8. Recorded only, not acted on - the maintainer decides."). *Timing*: every push to the PR removes all validation labels and restarts validation (`.github/policies/labelManagement.issueUpdated.yml` in winget-pkgs). Found missing from the migration by the review of 242 (`specs/242-backlog-system/ledger/review.md`, M2).

## Expected

The maintainer has chosen A, B or C; the chosen steps are carried out by `winget-manifest-fixes-from-072-audit` (templates) and the person (the push to the fork branch of #426090, the PR comment), and the result is logged in `winget-submit-release-after-pr-426090`.

## Notes

The audit named 0.1.8 because it was the current published release on 2026-09-30. Re-pointing uses the newest release that is really published (a tag plus a GitHub release with the installer attached - a bumped tree is not a release). The submission must be rendered from `main`, never from a tag (`v0.1.8`'s template still holds `DisplayVersion`, *Recommended plan* 4). The template fixes 6 / 7 and `PrivacyUrl` must go into `tools/winget/templates/` together with the push, so the repository and the PR stay identical (*Recommended plan* 2-3). Whether the PR is still open must be checked first (`gh pr view 426090 -R microsoft/winget-pkgs`); NEXT-WORK's last check was 2026-09-30. Independent of the choice (072 §P0.4): the PR's `Policy-Test-1.2` label is not about the new code-signing certificate (as the PR comment of 2026-09-17 assumed) but probably a "Targeted Brand" heuristic on the Description; it is resolved by an administrator waiver (`@wingetbot waivers add Policy-Test-1.2`; #433311 took 13 days); rewording the Description is allowed but costs a validation round.

## Question

Should the open pull request #426090 be re-pointed from 0.1.7 to the current published release now, with the manifest fixes of the 072 audit in the same push?

## Options

- **A - re-point now (the audit's plan).** In the fork branch replace `manifests/p/PavelStupka/TandemCommander/0.1.7/` with the current release rendered by `tools/winget/publish.ps1 -Version <v>` from `main`; retitle the PR `New package: PavelStupka.TandemCommander version <v>` and comment why. In the same push: the template fixes 6 (DisplayName) and 7 (installer-level ProductCode) and the `PrivacyUrl` line (already in the template since 083; check that the URL answers 200 on `main`). Resolves P0.1 and P0.2; costs one validation round.
- **B - stay on 0.1.7 and add the VCRedist dependency.** Declares `Microsoft.VCRedist.2015+.x64` so 0.1.7 starts; ships a version users should not get (0.1.8 fixed the runtime dependency and the antivirus findings). The audit calls it worse.
- **C - wait.** Leave the PR as it is until a moderator asks; the templates stay unchanged while it is open. Risk: the moderator launches 0.1.7 and it fails without the runtime (P0.1), then asks for the current release anyway (P0.2).

## Recommendation

A, as the audit recommends (`072/REMAINING-WORK.md` §P0 *Recommended plan* 1-4). This is the audit's recommendation recorded by the migration, not a maintainer decision.

## Log

- 2026-10-17 — created (source leftover:072)
- 2026-10-17 — moved to Decisions for the maintainer position 2
- 2026-10-17 — body written: question, options A/B/C and the audit's recommendation from 072 §P0 (migration review M2)
