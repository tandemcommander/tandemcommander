---
title: Remove the old 0.1 configuration key in a later release
type: tech-debt
status: new
severity: 1
area: data-safety
source: leftover:343
who: agent
created: 2026-10-25
updated: 2026-10-25
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Remove the old 0.1 configuration key in a later release

## Problem

Since feature 343 the configuration lives under HKCU\Software\Tandem Commander\Settings; at the first start of 0.2.0 or later the old key ...\0.1 (and 0.1.backup.63A7CD13) is copied there and kept unchanged as a backup, by the maintainer's decision of 2026-10-25 (option A: keep; removal is a separate, later item). The key stays in every user's registry until something removes it.

## Evidence

specs/343-semver-settings-root/spec.md Clarifications; MigrateConfigurationRoot in src/mainwnd2.cpp never deletes SALCFG_LEGACY_ROOT; PRIVACY.md says the user may delete it.

## Expected

In a release chosen by the maintainer (not before going back to 0.1.x stops mattering), the program removes ...\0.1 and ...\0.1.backup.63A7CD13 once ...\Settings holds a configuration; PRIVACY.md updated in the same change.

## Log

- 2026-10-25 — created (source leftover:343)
