---
title: Check by hand the paste commands after switching back with a busy clipboard (375)
type: person-step
status: new
severity: 3
area: panels-ui
source: leftover:375
who: person
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Check by hand the paste commands after switching back with a busy clipboard (375)

## Problem

Feature 375 stopped the idle clipboard check from waiting (~150 ms on every activation) for a
clipboard that another program keeps open: it tries once, looks again every 0.5 s for at most
5 s, and a menu that shows the paste commands looks again at once while the last check found the
clipboard busy. The hidden-desktop probe measures the activation's wait but cannot read the
program's own menus and toolbars, so the enabled state of *Paste*, *Paste (Change Directory)* and
*Paste Shortcuts* after such an activation was not seen by eye.

## Evidence

`specs/375-idle-clipboard-check/fix-log.md`, *Checks* - "NOT DRIVEN: the enabled state of the paste
commands"; the later looks were counted by the review's cdb breakpoint (fix-log *Review*, review 1:
11 checks 500 ms apart, 1 before the change). Helper `specs/375-idle-clipboard-check/probe/clip_hold.ps1`
holds the clipboard open without changing its content; `quickstart.md` step 4.

## Expected

*Paste* and *Paste Shortcuts* are offered exactly when the clipboard holds something to paste -
also when the clipboard was busy at the moment of switching back and is released later.

## Steps

- [ ] Copy two files in Explorer, switch to Tandem Commander (a disk folder in the active panel):
      the *Paste* toolbar button and *Edit > Paste* are enabled; *Edit > Paste Shortcuts* too.
- [ ] Copy a path as text (for example `C:\Windows`) in Notepad, switch back: *Edit > Paste
      (Change Directory)* is offered.
- [ ] Copy two files in Explorer. In PowerShell run
      `powershell -ExecutionPolicy Bypass -File specs\375-idle-clipboard-check\probe\clip_hold.ps1 -MaxSeconds 3`
      and switch to Tandem Commander within the 3 s: the window answers at once (no hitch);
      after the helper prints `holder: closed`, *Paste* becomes enabled within about half a
      second without any action, and *Edit > Paste* is enabled.
- [ ] Repeat with `-MaxSeconds 8` (longer than the 5 s of later looks): after `holder: closed`
      right-click the empty area of the panel - the context menu's *Paste* is enabled; open the
      *Edit* menu - *Paste* is enabled.
- [ ] Repeat the third step with a ZIP archive open in the panel: right-click an item and the
      empty area - *Paste* follows the clipboard.

## Log

- 2026-11-01 — created (source leftover:375)
