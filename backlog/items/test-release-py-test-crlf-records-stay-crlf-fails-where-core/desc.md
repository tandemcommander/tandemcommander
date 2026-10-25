---
title: test_release.py: test_crlf_records_stay_crlf fails where core.autocrlf is true
type: tech-debt
status: new
severity: 2
area: tooling
source: measure:343
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

# test_release.py: test_crlf_records_stay_crlf fails where core.autocrlf is true

## Problem

tools/release/test_release.py NewVersion::test_crlf_records_stay_crlf fails with 'git commit -q -m crlf: nothing to commit' on a machine whose global git config sets core.autocrlf=true: the test rewrites a record with CRLF line ends and expects git to see a change, but autocrlf normalises it away. Measured with the unchanged HEAD files of 72a02f2b and with feature 343's version (same failure); the other 44 tests pass.

## Evidence

specs/343-semver-settings-root/fix-log.md, section Release tooling and records.

## Expected

The test sets core.autocrlf=false (and core.eol) in its temporary repository, so it passes whatever the user's global git configuration is.

## Log

- 2026-10-25 — created (source measure:343)
