---
title: Paste fails in a folder whose path contains an exclamation mark
type: bug
status: open
severity: 5
area: file-ops
source: github#9
who: agent
created: 2026-10-17
updated: 2026-10-17
verified: -
effort: -
feature: -
related: []
depends-on: []
reason: -
---

# Paste fails in a folder whose path contains an exclamation mark

## Problem

In a folder whose path contains an exclamation mark (`!`), pasting from the
clipboard does not work: neither Ctrl+V in the panel nor *Paste* from the
context menu puts the copied files there. The reporter gives no further
details (no message text, no version, no copy source).

## Evidence

GitHub issue #9: https://github.com/tandemcommander/tandemcommander/issues/9 - original text (Slovak)
in `issue.md`. Version not stated; filed 2026-10-13, when 0.1.9 was the latest release. The issue
carries a screenshot that was not examined. Not reproduced yet; the cause is not investigated.

## Expected

Paste (Ctrl+V and the context-menu *Paste*) works in a folder whose path contains `!` exactly as in
any other folder, whether the copied items came from the program's own panel or from Explorer.

## Notes

Severity 5: a function does not work but a workaround exists (Copy with F5 between the panels, or
Explorer) - one reporter, no confirmations; a `!` in a folder name is not rare (names starting with
`!` sort first). GitHub labels: bug, ai backlog.

No earlier work found: `specs/FEATURE-HISTORY.md` has no entry for issue #9 or for `!` in paths.
First step of the fix: reproduce on the build with a source and a target folder containing `!`
(both directions, panel and Explorer as the source), then find where `!` is treated specially.

## Log

- 2026-10-17 — created (source github#9)
- 2026-10-17 — fields set from the issue text and labels
- 2026-10-17 — moved to Next position 7
