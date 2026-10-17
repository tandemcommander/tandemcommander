---
title: On-screen pass of 081: Markdown Viewer on the shared WebView2 host, sections A-D
type: person-step
status: open
severity: 4
area: webview
source: leftover:081
who: person
created: 2026-09-20
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [panel-tabs-078-release-pass-and-leak-watch]
depends-on: []
reason: -
---

# On-screen pass of 081: Markdown Viewer on the shared WebView2 host, sections A-D

## Problem

The Markdown Viewer moved onto the shared WebView2 host in 081. The machine-checkable half is done (builds, guards, 29 generator assertions, the content-policy compatibility check, probes for the hostile corpus, the keeper, cross-plug-in warmth and close-during-cold-start); the person half of the regression pass is owed.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'On-screen sweeps' ('081 §A-D') and §3 '081 §A-D' (~line 1125) (at 7993914c). Steps: specs/081-mdview-shared-webhost/quickstart.md §A-D.

## Expected

No request leaves the machine for the hostile corpus; the toggle, unload / reload and dark menus behave; rows A1-A10 look as before; recorded in 081's records.

## Notes

The pre-migration tree Debug_x64_prefix081\ is gone (checked 2026-09-24); rebuild it from 6b4d7af (the commit before 081's first), Debug x64, in a separate worktree only if the A1-A10 comparison is wanted. It is a confirmation only: render_diff.ps1 already found 0 of 729,144 pixels different.

## Steps

- [ ] A network monitor over the hostile corpus: no request leaves the machine
- [ ] The 'Keep the rendering engine ready' toggle
- [ ] Plug-in unload / reload through the Plugins Manager
- [ ] The dark menus
- [ ] An eye over rows A1-A10 against the pre-migration build (optional; rebuild from 6b4d7af, Debug x64)

## Log

- 2026-09-24 — the reference tree Debug_x64_prefix081 is gone from the build folder (checked)
- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
