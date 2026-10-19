---
title: Desktop view (Folders plug-in) repeats its shell columns after a view-mode switch
type: bug
status: new
severity: 3
area: other-plugins
source: review:248
who: agent
created: 2026-10-19
updated: 2026-10-19
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Desktop view (Folders plug-in) repeats its shell columns after a view-mode switch

## Problem

Switching the Desktop view (`fld:`, the Folders plug-in) from Detailed to another view mode
and back to Detailed adds the shell's columns again: the header reads "Název … | Velikost |
Typ položky | Datum změny | Název | Velikos…" - every shell column twice (one more copy per
round trip).

## Evidence

Found by review 1 of feature 248 (`specs/248-folders-column-names/fix-log.md`, *Review*,
SHOULD 1); older than 248 - the same on `main` at 7f37ec00. At 93e777eb:

- `src/plugins/folders/fs1.cpp:396`, `CPluginDataInterface::SetupView` calls `GetShellColumns()`
  on every Detailed set-up; `GetShellColumns` appends with `ShellColumns.Add(col)`
  (`fs1.cpp:474`) and `VisibleColumns.Add(realIndex)` (`fs1.cpp:487`) and never clears either
  array.
- `src/fileswn2.cpp:1155`: the core calls `PluginData.SetupView` again on the same data
  interface whenever the view mode changes.
- Reproduction (the reviewer's temporary copy of `probe/folders248_probe.ps1`): `fld:`, command
  2972 (Detailed), 2971 (Brief), 2972 again - the header crop shows the columns twice. Not
  re-measured by the 248 run.

## Expected

After any number of view-mode switches the Detailed view of `fld:` shows each shell column
once, in the shell's order.

## Approach

Clear `ShellColumns` and `VisibleColumns` at the start of `GetShellColumns` (or fill them once
per data interface). Extend `specs/248-folders-column-names/probe/folders248_probe.ps1` with a
mode round trip and a check that each column name appears once.

## Log

- 2026-10-19 — created (source review:248)
