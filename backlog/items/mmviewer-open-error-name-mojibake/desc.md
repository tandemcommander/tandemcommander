---
title: Multimedia Viewer: the "cannot open" message shows a non-ASCII file name as mojibake
type: bug
status: new
severity: 1
area: other-plugins
source: measure:255
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Multimedia Viewer: the "cannot open" message shows a non-ASCII file name as mojibake

## Problem

Multimedia Viewer (not shipped: `plugins.cfg` mmviewer=off) composes its "Error opening %s"
message from the code-page `LoadStr` template and the UTF-8 file name. In a translation whose
template has letters outside ASCII (Czech: "Chyba otevírání %s. ..."), the composed text is not
valid UTF-8, the core's message box draws it through the code page, and a file name with non-ASCII
letters becomes mojibake. English is not affected (an ASCII template).

## Evidence

By reading, at e849e68c: `src/plugins/mmviewer/renmain.cpp` `CRendererWindow::OpenFile` (the
`sprintf(buff, LoadStr(IDS_ERROR_OPENING), name)` branch); `name` comes from `ViewFile`
(`mmviewer.cpp`, UTF-8 by interface 104); the Czech template in
`translations/czech/mmviewer.slt`. Reported by `python tools/check_encoding.py --plugins`
(`mixed-composition`); verdict in `specs/255-plugin-encoding-findings/verdicts.md` (branch `255-plugin-encoding-findings`).

## Expected

Czech UI: opening an unsupported file `žluťoučký.xyz` shows the message with the name spelled
correctly; `check_encoding.py --plugins` no longer reports `renmain.cpp`.

## Approach

`LoadStrU8` (`splloadstru8.h`) for the template, as feature 130 did in 13 other plug-ins, and a
heap or bounded buffer (never cut the name).

## Notes

The plug-in is not shipped and the effect needs a translation, hence severity 1.

## Log

- 2026-10-20 — created (source measure:255)
