---
title: Stale winget claims in project records and publish.ps1 order (072 audit)
type: tech-debt
status: open
severity: 2
area: build-release
source: leftover:072
who: agent
created: 2026-09-30
updated: 2026-10-17
verified: 2026-10-17 7993914c
effort: S
feature: -
related: [winget-manifest-fixes-from-072-audit]
depends-on: []
reason: -
---

# Stale winget claims in project records and publish.ps1 order (072 audit)

## Problem

Project records repeat claims the 072 audit refuted: `specs/FEATURE-HISTORY.md` (072 entry, ~L281-283) says `publish.ps1` refuses to run without PrivilegesRequiredOverridesAllowed; 072's `fix-log.md` ~128-131 makes the check-09 claim; and `tools/winget/publish.ps1` (`Render-Template`) substitutes the placeholders (L195) before it drops every line starting with `#` (L203-204), so a release-notes line that starts with `#` after substitution - e.g. a wrapped `{{RELEASE_SUMMARY}}` line beginning `#426090` - silently vanishes from the submitted manifest. Not triggered by 0.1.8 (820 characters, no `#`).

## Evidence

specs/072-winget-distribution/REMAINING-WORK.md §P0 'Repository record fixes' (L157-163); re-checked by the migration at 7993914c: all three still present; the publish.ps1 order confirmed at 7993914c by the migration review (L195 `$text.Replace('{{' + $key + '}}', …)`, then L203-204 `if ($line.TrimStart().StartsWith('#')) { … continue }`; `specs/242-backlog-system/ledger/review.md`, S2). Migrated from specs/NEXT-WORK.md §6 ('… and stale records') at 7993914c.

## Expected

The records state what is true (or name the correction), and publish.ps1 strips the template's comment lines before substituting: a dry run (`-LocalFile`) whose release summary has a line starting with `#` keeps that line in the manifest, and a dry run of the current release produces byte-identical manifests to the old order.

## Approach

Records: add a dated correction rather than rewriting history. publish.ps1 is outside tools/winget/templates/, so it may change while #426090 is open - but run the dry run and compare the output.

## Log

- 2026-10-17 — migrated from the consolidation of the migration parts (feature 242)
- 2026-10-17 — migration review S2: Problem / Expected state the real effect (a release-notes line starting with # is dropped from the manifest)
