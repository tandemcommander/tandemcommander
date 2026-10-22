---
title: Tabs 312: real keyboard in both key modes and the Tabs page in eight languages
type: person-step
status: new
severity: 3
area: panels-ui
source: measure:312
who: person
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: S
feature: -
related: [panel-tabs-chrome-shortcuts-and-reopen-closed-tab, panel-tabs-078-release-pass-and-leak-watch]
depends-on: [panel-tabs-chrome-shortcuts-and-reopen-closed-tab]
reason: -
---

# Tabs 312: real keyboard in both key modes and the Tabs page in eight languages

## Problem

Feature 312 was verified by a hidden-desktop probe that sends key messages; the real keyboard and the translated Tabs page were not seen.

## Evidence

Branch 312-tabs-browser-keys, fix-log sections Checks and Stopped; probe specs/312-tabs-browser-keys/probe/tabs312_probe.ps1.

## Expected

The real keys do what the probe rows show, in both modes, and the Tabs page reads well in all eight languages.

## Steps

Run after the two-stage `.slt` refresh of feature 312 (the item it depends on), on a build of the
branch `312-tabs-browser-keys` or of `main` after it was merged.

- [ ] Classic mode (Configuration > Tabs, *Browser-like tab shortcuts* off), tabs on, in the panel:
      Ctrl+T on a `.lnk` file focuses its target, Ctrl+W restores the last selection, Ctrl+Page
      Down enters the focused folder, Ctrl+Page Up goes up, Ctrl+Shift+T / W open / close a tab,
      Ctrl+Shift+Page Down / Up switch tabs, Ctrl+Shift+G does nothing, Ctrl+Tab goes to the
      command line - the same as 0.1.10.
- [ ] Classic mode, focus in the command line with typed text: Ctrl+T, Ctrl+W, Ctrl+Shift+T,
      Ctrl+Shift+W do nothing and the text stays; Ctrl+Shift+Page Down / Up switch tabs.
- [ ] Browser-like mode, in the panel: Ctrl+T new tab, Ctrl+W close, Ctrl+Page Down / Up next /
      previous tab (no folder entered), Ctrl+Shift+T reopens the closed tab at its place with its
      selection, Ctrl+Shift+W restores the selection, Ctrl+Shift+G focuses a shortcut's target,
      Ctrl+Shift+Page Down / Up still switch, Ctrl+Tab unchanged; no stray character typed into
      quick search or the command line.
- [ ] Browser-like mode, focus in the command line: the same keys work and the typed text stays.
- [ ] Menus show the keys of the mode: Left > Tabs (New Tab Ctrl+T, Close Tab Ctrl+W, Next Tab
      Ctrl+Page Down, Previous Tab Ctrl+Page Up, Reopen Closed Tab Ctrl+Shift+T), Edit > Restore
      Selection Ctrl+Shift+W, Commands > Go to Shortcut or Link Target Ctrl+Shift+G (also at the
      Beginner skill level); the toolbar tooltips and the strip's + tooltip likewise; with the option
      off the 0.1.10 labels.
- [ ] Configuration > Tabs in all eight languages: the texts fit, the list's two columns are
      readable, clicking the option changes the list at once, the option and list are greyed while
      *Show tabs in panels* is off; the Appearance page has no gap where the checkbox was.
- [ ] Options > Show > Tabs and the toolbar context menu > Tabs: checked while tabs are on; with two
      tabs the "will be closed" question comes; No keeps them.

## Log

- 2026-10-22 — created (source measure:312)
