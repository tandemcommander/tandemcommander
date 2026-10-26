---
title: winget manifest fixes (072 audit): DisplayName, ProductCode; PrivacyUrl check
type: bug
status: open
severity: 3
area: build-release
source: leftover:072
who: agent
created: 2026-09-30
updated: 2026-10-26
verified: 2026-10-26 5990595b
effort: S
feature: -
related: [winget-per-user-scope-entry, winget-records-stale-claims-from-072-audit]
depends-on: []
reason: -
---

# winget manifest fixes (072 audit): DisplayName, ProductCode; PrivacyUrl check

## Problem

The winget manifests generated from `tools/winget/templates/` do not state the installed program exactly as the installer writes it: `AppsAndFeaturesEntries.DisplayName` is `Tandem Commander`, but Inno Setup writes `Tandem Commander <version>` (`AppVerName` is commented out), and `ProductCode` is only in `AppsAndFeaturesEntries`, not at installer level (schema 1.10.0 asks for both). The installer template comment still gives the refuted reason "the validation pipeline runs elevated" for dropping the per-user entry. Found by the 072 audit of PR #426090 (2026-09-30) as what a moderator was likely to ask about. That PR was merged on 2026-10-08 and 0.1.9, 0.1.10 and 0.2.0 were accepted with the same manifests; winget list/upgrade works (it matches by ProductCode), so this is manifest accuracy, not a functional defect.

## Evidence

At 5990595b: `tools/winget/templates/installer.yaml.in` - `AppsAndFeaturesEntries` (DisplayName `Tandem Commander`, ProductCode `{35C0B0DC-DB73-429C-AAA8-FBC41C937F66}_is1`), no installer-level ProductCode, header comment with the refuted elevation reason; `setup/tandemcommander.iss:13` `;AppVerName=...` commented out. The installed 0.2.0 (machine scope) has DisplayName `Tandem Commander 0.2.0` in `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{35C0B0DC-DB73-429C-AAA8-FBC41C937F66}_is1` (read 2026-10-26). The catalogue's 0.2.0 installer manifest (microsoft/winget-pkgs#461652) carries the same values. `locale.en-US.yaml.in:42` has the PrivacyUrl line; the URL answered 200 on 2026-10-26. Source: specs/072-winget-distribution/REMAINING-WORK.md §P0 (P0.6, P0.7, 'Repository record fixes').

## Expected

The manifests generated from the templates state DisplayName and ProductCode as the installed program reports them, and the template comments give the true reasons. The fixed templates reach the catalogue through the Publish to winget workflow with the next release; the PrivacyUrl still answers 200 at that time.

## Approach

(6) Either set `UninstallDisplayName=Tandem Commander` in `setup/tandemcommander.iss` (from the next release; the Apps & Features name then loses the version) or render the versioned name `Tandem Commander {{VERSION}}` into `AppsAndFeaturesEntries.DisplayName` - the second changes nothing in the installer and is the smaller step; (7) add `ProductCode` at installer level in `tools/winget/templates/installer.yaml.in`; correct the header comment. Check with `tools/winget/publish.ps1 -Version 0.2.0 -LocalFile <installer>` (generate and validate, no submission). The change must be in the commit the next release is tagged from: on a published release the workflow checks out the release's tag and submits the templates found there.

## Notes

No pull request gates this any more (#426090 merged 2026-10-08; the decision `winget-repoint-pr-426090-decision` was closed as obsolete on 2026-10-26). The stale records outside the templates are `winget-records-stale-claims-from-072-audit`; the per-user entry is `winget-per-user-scope-entry` and does not ride along.

## Log

- 2026-09-30 — audit of #426090 recorded in 072/REMAINING-WORK.md §P0 - not acted on
- 2026-10-17 — migrated from the consolidation of the migration parts (feature 242)
- 2026-10-17 — unblocked
- 2026-10-17 — migration review M2: waits for the re-point decision, not blocked on the PR
- 2026-10-17 — migration review M2/N10: Approach follows the audit plan (templates change with the re-pointing push, not after the PR settles); PrivacyUrl reworded as a check
- 2026-10-17 — title shortened to 80 characters
- 2026-10-17 — title shortened to 80 characters
- 2026-10-26 — related item winget-submit-release-after-pr-426090 closed: done: #426090 merged 2026-10-08, 0.1.9, 0.1.10 and 0.2.0 submitted by the workflow and merged, the catalogue is current and works; maintainer 2026-10-26
- 2026-10-26 — dependency winget-repoint-pr-426090-decision closed: decided 2026-10-26: obsolete, #426090 merged 2026-10-08 and the catalogue holds 0.2.0; maintainer
- 2026-10-26 — maintainer decision 2026-10-26: kept; rewritten without the #426090 gate - the fixes reach the catalogue with the next release through the workflow
- 2026-10-26 — verified at 5990595b: still true: template DisplayName Tandem Commander vs installed Tandem Commander 0.2.0 (HKLM uninstall key), no installer-level ProductCode, same in the catalogue 0.2.0 manifest
