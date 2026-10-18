---
title: Paste fails in a folder whose path contains an exclamation mark
type: bug
status: blocked
severity: 5
area: file-ops
source: github#9
who: agent
created: 2026-10-17
updated: 2026-10-18
verified: 2026-10-18 6dc132a7
effort: -
feature: -
related: []
depends-on: []
reason: not reproduced at 6dc132a7: fixed by feature 127 (0.1.10) - the copy-name word was a code-page string inside a UTF-8 name; issue #9 needs an answer; a real-clipboard paste in Slovak is owed to a person
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
- 2026-10-18 — verified at 6dc132a7: not reproduced: the screenshot shows error 123 for a paste into the same folder (new name with the Slovak word Kopia); 0.1.9 built that word from the code page into a UTF-8 name (invalid UTF-8 -> ERROR_INVALID_NAME); feature 127 (0.1.10) takes it through LoadStrU8; F5 copy into a folder named !!temp under a name with o-acute works at 6dc132a7; the exclamation mark plays no part; the clipboard rows were not driven (hidden desktop)
- 2026-10-18 — analysis: the reporter (0.1.9, Slovak UI) pasted a file into its own folder, so the program made the name "<name> - Kopia.zip"; IDS_NEWNAME_COPY came through LoadStr (code page) into a UTF-8 path and the file layer refused it with error 123; fixed by feature 127 (fileswn6.cpp BuildScriptMain2, LoadStrU8); a paste with a real clipboard in a Slovak UI is still owed to a person
- 2026-10-18 — blocked: not reproduced at 6dc132a7: fixed by feature 127 (0.1.10) - the copy-name word was a code-page string inside a UTF-8 name; issue #9 needs an answer; a real-clipboard paste in Slovak is owed to a person
- 2026-10-18 — reply.md: draft answer written (Slovak + English), not sent
- 2026-10-18 — reply.md: draft answer rewritten in English only, not sent
