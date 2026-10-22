---
title: Markdown Viewer: a scheme, width or View Source change shows the document from the top
type: improvement
status: open
severity: 3
area: other-plugins
source: measure:314
who: both
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: M
feature: -
related: [mdview-page-width-levels]
depends-on: []
reason: -
---

# Markdown Viewer: a scheme, width or View Source change shows the document from the top

## Problem

Every change that rebuilds the Markdown Viewer's page - a color scheme (menu or F9), Follow
System Theme, View Source (Ctrl+U), Load Remote Images, a new find term, and since feature 314
View > Page Width - shows the document again from the top. A user reading in the middle of a
long document loses their place each time.

## Evidence

At 67d1e782 (branch 314-mdview-page-width), by reading:

- `src/plugins/mdview/viewer.cpp` `CViewerWindow::Regenerate` -> `RebuildHtml` + `ShowDocument`:
  `DocVersion++`, `Web->Navigate(DocVersion, fragment)` with an empty fragment = a new document
  `https://mdview.invalid/doc.html?v=<N>`, which opens at the top.
- The page runs with scripts off (feature 021 lockdown, `MdConfigureHost` in `webglue.cpp`), and
  the shared host `src/common/webhost/webhost.h` (`CTcWebHost`) has no call that reads or restores
  a scroll position (no script execution, no DevTools call, no `Reload`).
- Feature 314 (`specs/314-mdview-page-width/spec.md`, Clarifications) made a width change behave
  like a scheme change for this reason; the item `mdview-page-width-levels` had asked to keep the
  reading position.

## Expected

- After any rebuild the same part of the document is on screen (the same scroll fraction, or the
  heading that was at the top).
- The page keeps running without document scripts; the WebView2 binding contract
  (`architecture/11-webview2-integration.md`) is followed - a host addition is a coordinated
  change for both viewers.

## Approach

- Options to measure: a host-side `ExecuteScript` (runs even with scripts disabled; reads and
  sets `scrollY` / the fraction) or the DevTools protocol, added once to `CTcWebHost`; or a
  `Reload` that lets Chromium restore the scroll position. Each is a change to the shared host and
  the binding contract.
- A cheap partial step inside the plug-in (review of 314): when a find match is current
  (`FindIndex >= 0`), rebuild with the fragment `mdfind-<FindIndex>` so the page returns to the
  match.

## Notes

- Who `both`: the scroll position on a real screen is a person's check (the hidden-desktop probe
  of 314 can capture the page but not drive scrolling by wheel).

## Log

- 2026-10-23 — created (source measure:314)
- 2026-10-23 — moved to Inbox
- 2026-10-23 — moved to Next position 76
