---
title: Code Viewer and Markdown Viewer show the page shifted right and down
type: bug
status: in-progress
severity: 5
area: webview
source: github#29
who: agent
created: 2026-11-12
updated: 2026-11-12
verified: 2026-11-12 a44dfdf4
effort: -
feature: 424
related: []
depends-on: []
reason: -
---

# Code Viewer and Markdown Viewer show the page shifted right and down

## Problem

A user who opens a text file with F3 gets the Code Viewer (the default F3 viewer for text and
source files), but its page does not fill the window: it starts far to the right and lower than the
client area's top-left corner. The left part of the client stays empty, and the right and bottom
parts of the text are cut off at the window edge. The reporter says the Markdown Viewer does the
same. Both viewers use the shared WebView2 host (`src/common/webhost/`), so the fault is probably in
how the page is placed or scaled there, not in either viewer's CSS.

## Evidence

- GitHub issue #29: https://github.com/tandemcommander/tandemcommander/issues/29 (2026-11-10,
  reporter batusek); the version is not stated. Original text in `issue.md`; the maintainer
  confirmed it as a bug in a comment.
- Screenshot (1913 x 462, Code Viewer, `[Plain Text]`, a large log file with the "Syntax
  highlighting is off" notice): the page's top-left corner, where the notice bar starts, is at
  about x = 597, y = 173. The client area starts at about y = 53, below the menu bar. So the page is
  offset by about 597 px to the right and 120 px down, and the text is clipped at the right edge.
  The page's font also looks larger than the 13px Consolas of `viewer.css`. That points to a scale
  or DPI mismatch, not to padding (measured from the screenshot only, not reproduced).
- By reading at 9921e415: `src/common/webhost/webhost.cpp`. The controller's bounds are always
  `{0, 0, cx, cy}`, at creation (around line 489) and in `CTcWebHost::Resize` (around line 600).
  `src/plugins/codeview/web/viewer.css` sets `margin: 0; padding: 0` on `html, body`. Nothing in
  the code explains a 597 px offset, so the reporter's setup (display scaling, several monitors
  with different DPI, the window opened on another monitor) is the likely trigger.

## Expected

On any display scaling, and on a monitor with a different DPI from the main window's, the page of
the Code Viewer and of the Markdown Viewer fills the viewer's client area exactly: its top-left is
the client's top-left, nothing is cut off at the right or bottom edge, and no empty band is left at
the left or top. A probe opens both viewers at 100 %, 150 % and a per-monitor DPI change, and checks
that the painted page starts at the client's origin.

## Approach

First reproduce it on the build: different display scaling, a second monitor with another DPI,
moving the viewer between monitors, opening it while the main window is on the second monitor.
Then check the thread or window DPI awareness at the point where the viewer window and the
WebView2 controller are created. Also check `RasterizationScale` /
`ShouldDetectMonitorScaleChanges` and `BoundsMode` (none of them is set in `webhost.cpp`) against
the client size given to `Resize`. A fix in the shared host fixes both viewers; architecture 11 is
binding (one host, never copied).

## Notes

Severity 5: does a function not work but a workaround exists? Yes - the default F3 viewer for text
files shows its text cut off, and the built-in viewer or another viewer still opens the file. One
reporter, the setup is not known. GitHub labels: bug, ai backlog.

No earlier feature names #29. 314 (Markdown Viewer page width) and 074 (Code Viewer gutter) changed
the page layout, but not by an offset like this one.

## Log

- 2026-11-12 — created (source github#29)
- 2026-11-12 — fields set from the issue text and labels
- 2026-11-12 — moved to Next position 1
- 2026-11-12 — verified at a44dfdf4: reachable at a44dfdf4: browser launched --embedded-browser-webview-dpi-awareness=1 (system aware, own system DPI fixed at its start; cross-process child windows); not driven at 100% here
- 2026-11-12 — run started, feature 424
