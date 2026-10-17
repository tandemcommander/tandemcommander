---
title: Read the 78 findings of check_encoding.py --plugins one by one
type: tech-debt
status: open
severity: 4
area: encoding
source: leftover:239
who: agent
created: 2026-10-16
updated: 2026-10-17
verified: -
effort: L
feature: -
related: []
depends-on: []
reason: -
---

# Read the 78 findings of check_encoding.py --plugins one by one

## Problem

Feature 239 added `tools/check_encoding.py --plugins` (a report only, never fails). Its 78 findings in the plug-ins are unread: `lossy-lenient-at-intake` 38, `utf8-to-legacy-sink` 18 (ZIP 11), `strict-probe-rejects-wtf8` 12, `mixed-composition` 6, others 4. Each may be a real encoding defect or a false positive.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L549-552. The list: `specs/239-check-encoding-plugins/plugins_findings.txt`; feature 239 (`specs/239-check-encoding-plugins/`). The scan of `plugins/` was found missing by feature 124.

## Expected

Each of the 78 findings has a verdict (fixed, false positive with a reason, or its own item); the plug-in scan can become strict for the shipped plug-ins.

## Approach

Start with `utf8-to-legacy-sink` (18, ZIP 11) - the class most likely to lose letters; split real defects per plug-in into features.

## Notes

Severity is the migrating agent's estimate for the class (mojibake in plug-ins = 4 by the anchors); individual findings may be higher.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
