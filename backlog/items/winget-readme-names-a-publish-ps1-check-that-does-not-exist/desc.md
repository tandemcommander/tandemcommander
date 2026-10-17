---
title: winget README names a publish.ps1 check that does not exist
type: tech-debt
status: new
severity: 1
area: build-release
source: review:243
who: agent
created: 2026-10-17
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [winget-records-stale-claims-from-072-audit]
depends-on: []
reason: -
---

# winget README names a publish.ps1 check that does not exist

## Problem

The troubleshooting part of `tools/winget/README.md` lists the error "`setup\tandemcommander.iss has no PrivilegesRequiredOverridesAllowed`" as something `publish.ps1` reports, but `publish.ps1` has no such check: a removed directive would not be caught by the script at all, and a maintainer reading the README believes it would.

## Evidence

At `c3319ffa`: `tools/winget/README.md:203-205`; `grep -n PrivilegesRequiredOverridesAllowed tools/winget/publish.ps1` finds nothing. The related item `winget-records-stale-claims-from-072-audit` records the same refuted claim in `specs/FEATURE-HISTORY.md` and 072's fix-log, but not in this README. Found by the tooling analysis of feature 243 (`specs/243-tandem-release-skill/research.md` F12).

## Expected

Either `publish.ps1` checks the directive and fails with that message (`CLAUDE.md`: keep `PrivilegesRequiredOverridesAllowed=dialog`, winget depends on it), or the README paragraph is removed. Fixing it together with the related item is natural.

## Log

- 2026-10-17 — created (source review:243)
