---
title: Answer GitHub issue #9 (paste fails in a folder with an exclamation mark)
type: person-step
status: open
severity: 3
area: file-ops
source: leftover:127
who: person
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Answer GitHub issue #9 (paste fails in a folder with an exclamation mark)

## Problem

GitHub issue #9 ("vkladanie zo schránky nefunguje v adresároch s ! v ceste") still has no
answer. Its backlog item `vkladanie-zo-schranky-nefunguje-v-adresaroch-s-v-ceste` was closed on
2026-10-23 as fixed by feature 127 (released in 0.1.10, tag `v0.1.10`): the reporter pasted a file
into its own folder, the copy name took the Slovak word "Kópia" from the code page into a UTF-8 name,
and Windows refused it with error 123. The exclamation mark plays no part. Posting the answer is
the maintainer's step (runs never post to GitHub). A paste with a real clipboard in a Slovak UI was
never driven (the hidden desktop has no clipboard).

## Evidence

- https://github.com/tandemcommander/tandemcommander/issues/9 (reported against 0.1.9, Slovak UI,
  with a screenshot of error 123).
- Fix: `src/fileswn6.cpp` `BuildScriptMain2`, `LoadStrU8(IDS_NEWNAME_COPY)` (feature 127), in
  `v0.1.10`.
- Measured at 6dc132a7 (2026-10-18): F5 copy into a folder named `!!temp` under a name with "ó"
  works.
- The closed item's analysis and its draft reply (`reply.md`, English) are in git history:
  `git show 641a36bd:backlog/items/vkladanie-zo-schranky-nefunguje-v-adresaroch-s-v-ceste/reply.md`.

## Expected

Issue #9 answered and closed; the paste with a real clipboard in a Slovak UI confirmed.

## Steps

- [ ] In 0.1.10 with the Slovak UI, copy a file with Ctrl+C in a folder whose path contains `!`
      and paste it with Ctrl+V into the same folder → a copy named `<name> - Kópia.<ext>` appears,
      no error 123.
- [ ] Paste the same file from Explorer (Ctrl+C there) into a folder with `!` in Tandem Commander
      → the file is copied, no error.
- [ ] Post the answer below on issue #9 and close the issue (or leave it open if the reporter is
      asked to confirm).

Draft answer (English):

> Thank you for the report and the screenshot – the screenshot is what showed us the cause.
>
> **What happened:** the exclamation mark in the path is not the cause. The screenshot shows a
> file pasted into **the same folder** it was copied from, so the program gives the copy a new
> name, `zsu-1191327 - Kópia.zip`. In version 0.1.9 the word "Kópia" from the Slovak translation
> was put into the file name in the wrong encoding (the code page instead of UTF-8). Windows
> refused that name, hence the message *(123) The filename, directory name, or volume label syntax
> is incorrect*. The same would have happened in any folder with a Slovak (or Czech, Hungarian, …)
> user interface – in the folders with "!" you most likely just happened to paste into the same
> folder.
>
> **Fix:** version **0.1.10** contains it (feature 127 – translated texts are now put into file
> names and messages as UTF-8). We checked that copying within a folder named `!!temp` under a
> name containing "ó" works.
>
> Please try it again after updating to 0.1.10. If pasting still fails – for example when pasting
> from **another** folder into a folder with "!" – please tell us where the files were copied from
> (a Tandem Commander panel or Explorer) and which message appears.

## Log

- 2026-10-23 — created (source leftover:127)
- 2026-10-23 — moved to Person steps
