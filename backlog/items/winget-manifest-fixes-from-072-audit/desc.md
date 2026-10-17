---
title: winget manifest fixes (072 audit): DisplayName, ProductCode; PrivacyUrl check
type: bug
status: open
severity: 3
area: build-release
source: leftover:072
who: agent
created: 2026-09-30
updated: 2026-10-17
verified: 2026-10-17 7993914c
effort: S
feature: -
related: [winget-repoint-pr-426090-decision, winget-submit-release-after-pr-426090, winget-per-user-scope-entry, winget-records-stale-claims-from-072-audit]
depends-on: [winget-repoint-pr-426090-decision]
reason: -
---

# winget manifest fixes (072 audit): DisplayName, ProductCode; PrivacyUrl check

## Problem

The audit of PR #426090 (2026-09-30) found manifest inaccuracies a winget moderator is likely to ask about: AppsAndFeaturesEntries.DisplayName does not match what the installer writes (`AppVerName` is commented out, so Inno Setup writes `Tandem Commander <version>`; the template says `Tandem Commander`), and ProductCode is only in AppsAndFeaturesEntries and not at installer level (schema 1.10.0 asks for both). The installer template comment still gives the refuted reason "the pipeline runs elevated". PrivacyUrl is not a change: the template line exists since feature 083; what is owed is a check that the URL answers 200 on `main` before it goes out with the next push to #426090.

## Evidence

specs/072-winget-distribution/REMAINING-WORK.md §P0 (P0.3, P0.6, P0.7, 'Repository record fixes' - template comment), re-checked by the migration at 7993914c: DisplayName and installer-level ProductCode still open; `tools/winget/templates/installer.yaml.in:13-21` still has the refuted reason; `locale.en-US.yaml.in:42` has the PrivacyUrl line. Migrated from specs/NEXT-WORK.md §6 ('Read 072/REMAINING-WORK.md § P0 before anything else here') at 7993914c. Plan order corrected by the migration review (`specs/242-backlog-system/ledger/review.md`, M2, N10).

## Expected

The manifests generated from the templates state DisplayName and ProductCode as the installed program reports them, the template comments give the true reasons, and the PrivacyUrl `https://github.com/tandemcommander/tandemcommander/blob/main/PRIVACY.md` was checked to answer 200 before the push - all in the same push as the re-pointed #426090 (072 §P0 *Recommended plan* 2-3), so the repository and the PR stay identical.

## Approach

Waits for `winget-repoint-pr-426090-decision`. With option A (the audit's plan) the templates change NOW, while #426090 is open, together with the re-pointing push - the audit's step 2, not "only once #426090 is settled": (6) set `UninstallDisplayName=Tandem Commander` in `setup/tandemcommander.iss` from the next release, or render the versioned name into `AppsAndFeaturesEntries.DisplayName`; (7) add `ProductCode` at installer level in `tools/winget/templates/installer.yaml.in`; correct the comment at `installer.yaml.in:13-21`. Render the re-pointed manifest with `tools/winget/publish.ps1 -Version <v>` from `main` (dry run `-LocalFile <installer>`, validate) and push the same files to the fork branch. With option C the templates stay unchanged while the PR is open (072 *Gate*).

## Notes

The decision about the open PR (re-point, VC++ runtime risk of 0.1.7, the Policy-Test-1.2 waiver) is `winget-repoint-pr-426090-decision`; later submissions are `winget-submit-release-after-pr-426090`; the stale records outside the templates are `winget-records-stale-claims-from-072-audit`.

## Log

- 2026-09-30 — audit of #426090 recorded in 072/REMAINING-WORK.md §P0 - not acted on
- 2026-10-17 — migrated from the consolidation of the migration parts (feature 242)
- 2026-10-17 — unblocked
- 2026-10-17 — migration review M2: waits for the re-point decision, not blocked on the PR
- 2026-10-17 — migration review M2/N10: Approach follows the audit plan (templates change with the re-pointing push, not after the PR settles); PrivacyUrl reworded as a check
- 2026-10-17 — title shortened to 80 characters
- 2026-10-17 — title shortened to 80 characters
