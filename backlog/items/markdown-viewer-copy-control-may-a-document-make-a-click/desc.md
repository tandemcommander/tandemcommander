---
title: Markdown Viewer copy control: may a document make a click overwrite the clipboard
type: decision
status: new
severity: 4
area: other-plugins
source: review:408
who: person
created: 2026-11-07
updated: 2026-11-07
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Markdown Viewer copy control: may a document make a click overwrite the clipboard

## Problem

Feature 408 put a *Copy* control on every code block of the Markdown Viewer. The page runs no script, so the control is a link the viewer intercepts. Raw HTML and inline CSS pass through since feature 021, so a document can restyle the genuine control: stretch it invisibly over the whole page and hide its block. Any click on the page then replaces the user's clipboard with the hidden block's text. No document could touch the clipboard before 408. The previous clipboard content is lost and there is no undo.

## Evidence

- Review 1 of feature 408, M1 (`specs/408-mdview-code-copy/fix-log.md`, *Review*): the restyled control copied `HIDDEN PAYLOAD` with no visible sign. 408 then made every copy confirmed by a native notice outside the page (a tracking tooltip, `CViewerWindow::ShowCopyNotice` in `src/plugins/mdview/viewer.cpp`), showing *Copied* and up to three non-blank lines of what was copied plus a `…` line when more follow (`MdCopyNoticeText` in `src/plugins/mdview/htmlgen.cpp`).
- Review 3, S2: the notice softens the risk but does not undo the overwrite; lines made of characters that render blank are hidden from the notice, so such a block shows as *Copied* plus `…` only.
- Probe `specs/408-mdview-code-copy/probe/copy408_probe.ps1`, row HIJACK: the restyled control copies the hidden block; the notice is visible with its first lines.
- Spec `specs/408-mdview-code-copy/spec.md`, *Assumptions* (autonomous run, review 1 M1): the run kept this behaviour as the conservative default.

## Expected

The maintainer decides whether the remaining risk is acceptable or which mitigation the viewer gets.

## Notes

Raised by review 3 of feature 408 as a trade-off a run should not decide alone. Not verified on a real desktop (the hidden desktop has no real clipboard): the look of the notice and what a user notices are part of the release checklist lines of 408.

## Question

May a Markdown document, by restyling the viewer's genuine copy control, make an ordinary-looking click overwrite the clipboard (always followed by the native *Copied* notice that shows what was copied)?

## Options

- **A — accept (as shipped by 408).** One click copies; every copy shows the native notice with up to three lines and `…`. Risk: a malicious document can overwrite the clipboard on a click; the user sees the notice but may not read it.
- **B — offer an undo in the notice.** The viewer keeps the previous clipboard text and the notice (made clickable, or a key) puts it back. Costs: a larger notice UI (no longer a plain tooltip), new strings, keeping the previous clipboard content in memory for a few seconds; non-text clipboard formats cannot all be restored.
- **C — ask before copying.** A native question (*Copy N lines to the clipboard?*) after every activation. Removes the silent-overwrite risk; costs the convenience the issue asked for (two steps instead of one).
- **D — show the control only on code blocks the page did not restyle.** Not possible without script: the viewer cannot read the page's layout.
- **E — enable scripts in the viewer and use the browser clipboard API.** The feature-021 lockdown question; the API's user-gesture rule does not stop a restyled control either.

## Recommendation

A, with B as a later improvement if users ask: the copied text is always the document's own code, the notice makes every copy visible, and a question on every copy (C) would defeat the feature.

## Log

- 2026-11-07 — created (source review:408)
