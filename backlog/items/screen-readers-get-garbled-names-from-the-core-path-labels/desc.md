---
title: Screen readers get garbled names from the core path labels (CStaticText)
type: bug
status: open
severity: 3
area: encoding
source: review:287
who: both
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Screen readers get garbled names from the core path labels (CStaticText)

## Problem

The core's self-painted labels (`CStaticText`: the *Name:* line of the error / question /
overwrite dialogs, path labels of other dialogs) show a name with letters outside ASCII correctly on
screen, but give it to anyone who asks for the window's text (a screen reader, UI Automation, a
test tool) garbled: `Klíč` comes out as `KlĂ­ÄŤ`. A blind user hears nonsense for every such name.

## Evidence

`src/gui.cpp` at 243174e4, `CStaticText::WindowProc`, `case WM_GETTEXT`: copies `Text` - UTF-8
bytes - into the caller's buffer as they are. The control is a code-page window, so Windows converts
the result for a wide caller with the code page: UTF-8 read as cp1250. Measured by the probe of
feature 287 (`specs/287-regedt-move-class-name/probe/move287_probe.ps1`, `Painted-Text`, which
reverses exactly this conversion to read the name), and noted by its review
(`specs/287-regedt-move-class-name/fix-log.md`, *Review*, N3). Not checked with a real screen
reader.

## Expected

`WM_GETTEXT` (and `WM_GETTEXTLENGTH`) of a `CStaticText` give its text so that a wide caller
receives the real letters (e.g. answer in code page for an `A` caller and in UTF-16 for a `W`
caller, or make the control a Unicode window); the painted text stays as it is.

## Notes

Before changing it, find every reader of these controls' text in the tree and in the probes:
probes of earlier features may rely on the UTF-8 bytes (287's `Painted-Text` does; it would have to
change with the fix). A check with a real screen reader (Narrator) is owed to a person, hence
`who: both`. Severity 3: the screen shows the right text; only assistive technology is affected.

## Log

- 2026-10-21 — created (source review:287)
- 2026-10-21 — moved to Next position 55
