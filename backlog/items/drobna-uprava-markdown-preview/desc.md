---
title: Markdown Viewer: a button to copy a code block to the clipboard
type: feature
status: in-progress
severity: 3
area: other-plugins
source: github#20
who: both
created: 2026-11-06
updated: 2026-11-07
verified: 2026-11-07 924e7c82
effort: M
feature: 408
related: []
depends-on: []
reason: -
---

# Markdown Viewer: a button to copy a code block to the clipboard

## Problem

A user reads a Markdown file in the Markdown Viewer and wants to copy the content of a code block. Today they must select the text by mouse. The reporter asks for a copy button on each code block (`<pre>`) that puts the block's content on the clipboard, as Claude Code and many documentation sites show it.

## Evidence

GitHub issue #20: https://github.com/tandemcommander/tandemcommander/issues/20. Reported 2026-11-04; the version is not stated (0.2.0 was the current release); the original text is in `issue.md`.

By reading at d18047fe:
- `src/plugins/mdview/htmlgen.cpp:225`, `EmitCodeBlock`, writes `<pre><code class="language-…">` with the highlighted runs.
- `src/plugins/mdview/webglue.cpp:87-91`, `MdConfigureHost`, keeps the lockdown: `cfg.ScriptsEnabled = false; cfg.WebMessagesEnabled = false;` ("a rendered Markdown document needs no script and has nothing to say back to the host"). The shared host serves a scripts-off Content-Security-Policy.
- So a JavaScript `navigator.clipboard` button is not possible without changing that lockdown. WebView2 rules are binding: `architecture/11-webview2-integration.md`, feature 081.

## Expected

- Each fenced or indented code block in the rendered document has a small *Copy* control in its top-right corner. It is visible on hover or focus and works in the Default and Dark themes.
- Activating it puts the block's **source text** on the clipboard as Unicode text: the code as written in the Markdown, without highlighting markup, with the original line breaks. Nothing else is copied. Brief feedback shows it worked, for example the control reads *Copied*.
- The viewer stays script-free and sends no web messages: the control must work under the existing lockdown, or the spec records a maintainer decision to change it.
- The shared host is not copied or forked (CLAUDE.md, WebView2 rule).
- Clipboard content and the look are a person's check: there is no real clipboard on the hidden desktop.

## Approach

Script-free idea, to measure first:
- Render the control as a link to an address in the viewer's own virtual host, for example `https://mdview.invalid/copy/<n>`, where `<n>` indexes a table of block sources the generator keeps, like the `img/<n>` table.
- The plug-in intercepts that navigation through the host's navigation hook, cancels it and copies table entry `<n>` with the clipboard API on the UI thread.
- Check that the host offers a navigation hook to the plug-in without new web-message traffic. If it does not, extending the shared host is part of this feature (`src/common/webhost/`, contract in `architecture/11-…`).
- The new UI strings (*Copy*, *Copied*, the tooltip) need the two-stage `.slt` refresh in the same run.

## Notes

Severity 3: a nice-to-have convenience; users can select and copy by hand. A usual enhancement request from one reporter. GitHub labels: enhancement, ai backlog.

Enabling scripts in the Markdown Viewer would be a security trade-off of the feature-021 lockdown and is the maintainer's decision. This item does not assume it.

## Log

- 2026-11-06 — created (source github#20)
- 2026-11-06 — fields set from the issue text and labels
- 2026-11-06 — moved to Next position 2
- 2026-11-07 — verified at 924e7c82: still present at 924e7c82: EmitCodeBlock writes a bare pre/code, no copy control (htmlgen dump); the host OnActivateLink hook exists
- 2026-11-07 — run started, feature 408
