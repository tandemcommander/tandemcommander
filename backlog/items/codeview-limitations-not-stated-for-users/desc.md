---
title: Code Viewer: its known limitations are not stated anywhere a user can read
type: improvement
status: open
severity: 1
area: help-docs
source: leftover:070
who: agent
created: 2026-08-26
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [help-contents-fails-no-manual-shipped]
depends-on: []
reason: -
---

# Code Viewer: its known limitations are not stated anywhere a user can read

## Problem

Feature 070's handoff listed three limitations of the Code Viewer "to state in the changelog when this ships": (1) 18 grammars and 1 theme are excluded for licence reasons, so `.glsl`, `.matlab`, `.tcl`, nginx configs, Ada, gnuplot, Racket and org files open as plain text (`glsl` additionally ships as a minimal no-op grammar stub because C++, Elm and Nim declare it in `embeddedLangs`); (2) the plain band (over 1 MB, or lines over 20,000 characters) has no highlighting by design; (3) "Restore default file types" takes effect at the next application start, because the viewer list can only be written from `Connect()`. The plug-in shipped in 0.1.6 (build 190) without them: the 0.1.6 entry of CHANGELOG.md does not mention them and no user-facing document does (a search for `glsl` finds only specs/070-*).

## Evidence

specs/070-source-viewer-plugin/REMAINING-WORK.md, *Known limitations to state in the changelog when this ships* (L167-178); fix-log.md defect 1 (the glsl stub). CHANGELOG.md `## [0.1.6] - 2026-08-29` (L1896-1930 at 7993914c) has no such text. Not in specs/NEXT-WORK.md at 7993914c.

## Expected

The three limitations are stated in a user-facing place - the Code Viewer's page of the manual once a manual ships, or the README / the next release notes - with the excluded-format list re-checked against the plug-in's current data.

## Notes

Re-check the list of excluded grammars before stating it (src/plugins/codeview/test, `gen_langmap.py`, the licence exclusions in the 070 research) - it may have changed since 2026-08-26. Where the text goes depends on the decision about shipping a manual (help-contents-fails-no-manual-shipped).

## Log

- 2026-10-17 — migrated from specs/*/REMAINING-WORK.md (feature 242)
