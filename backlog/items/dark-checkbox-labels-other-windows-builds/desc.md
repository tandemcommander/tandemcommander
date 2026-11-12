---
title: Dark theme: black checkbox labels in plug-in windows on some Windows builds
type: bug
status: new
severity: 4
area: other-plugins
source: leftover:427
who: both
created: 2026-11-12
updated: 2026-11-12
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Dark theme: black checkbox labels in plug-in windows on some Windows builds

## Problem

A Dark-theme user (GitHub #25) sees the checkbox labels of PictView's settings (all four on the
*Advanced* page) and of Batch Rename's main window drawn black on the dark background, while the
core's *Configuration* draws its labels light. On the machine of feature 427 (Windows 10.0.26300)
every one of these labels is light, so the cause depends on the reporter's Windows build, which is
not known.

## Evidence

- GitHub issue #25: https://github.com/tandemcommander/tandemcommander/issues/25 - text in
  `specs/427-dark-plugin-toolbars/issue.md`, screenshots in `specs/427-dark-plugin-toolbars/evidence/`.
  In them the checkbox boxes are drawn light (unlike this machine, where `DarkMode_Explorer` draws
  them dark) also in the core's Configuration, whose labels are light there.
- Feature 427, `specs/427-dark-plugin-toolbars/probe/result_measure_before.txt` and
  `result_after_rows.txt` (PV-LABELS, RN-LABELS): at `b3770fa5` and after 427 PictView 6/6 and
  Batch Rename 8/8 labels light, lowest contrast 13.77; the core 6/6 (8.58).
- `specs/427-dark-plugin-toolbars/probe/chk_experiment.ps1` (`result_chk_experiment.txt`): a
  `DarkMode_Explorer` checkbox draws a light label on this Windows on the main thread and on another
  thread, with and without the dark DWM attribute, in a child window; the default and the classic
  theme draw it black. So on the reporter's machine the plug-ins' checkboxes are either not
  `DarkMode_Explorer` there, or that build's `DarkMode_Explorer` draws checkbox text black where
  the core's labels come out light for another reason.
- The theming path is the same for both (`ThemeApplyChildEnumProc` in `src/themes.cpp`, called by
  winliblt at `WM_INITDIALOG` of dialogs and property-sheet pages).

## Expected

- Reproduced first on (a virtual machine of) the reporter's Windows build, or a build that draws
  `DarkMode_Explorer` checkboxes light-boxed: the plug-in labels black there, the core's light.
- The cause found and fixed so that every checkbox label of PictView's settings and Batch Rename
  draws light in Dark on that build; the 427 probe (`dark427_probe.ps1`, PV-LABELS / RN-LABELS)
  passes there and still on 10.0.26300.

## Notes

- Severity 4: the labels are hard to read, the settings still work (and read in Default) - one
  reporter.
- The person's part: the reporter's Windows version and build (`winver`) - asked in the draft reply
  of feature 427 (`specs/427-dark-plugin-toolbars/reply.md`); or a machine with such a build.
- Not changed by 427 on purpose: no checkbox drawing without a reproduction (custom-drawing every
  label would change every dialog of the program on every build).

## Log

- 2026-11-12 — created (source leftover:427)
- 2026-11-12 — moved to Inbox
