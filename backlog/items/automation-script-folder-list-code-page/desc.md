---
title: Automation: a script folder with non-ASCII letters is shown and stored through the code page
type: bug
status: new
severity: 3
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

# Automation: a script folder with non-ASCII letters is shown and stored through the code page

## Problem

In the Automation plug-in's configuration (not shipped: `plugins.cfg` automation=off), the list of
script folders is an ANSI list view. A folder picked with *Browse* comes from the core as UTF-8
(`GetTargetDirectory`) and is put into the list with `ListView_SetItemText` (the A message), so a
folder with non-ASCII letters is shown as mojibake. On OK the list is read back with
`ListView_GetItem` (A) and stored; the bytes pass the code page twice, and bytes the code page does
not define (cp1250: 0x81, 0x83, 0x88, 0x90, 0x98 - e.g. the second byte of "ň") do not come back,
so the stored folder can differ from the chosen one and its scripts are not found. The folders
loaded from the configuration go the same way (`ListView_InsertItem` with
`GetScriptDirectoryRaw`).

## Evidence

By reading, at e849e68c: `src/plugins/automation/cfgdlg.cpp` - `OnBrowseBtnClicked`
(`ListView_SetItemText(hwndList, iSel, 0, szPath)` after `GetTargetDirectory`), the transfer
function above `OnInitDialog` (`ListView_InsertItem` / `ListView_GetItem` + `AddScriptDirectory`).
Reported by `python tools/check_encoding.py --plugins` (`utf8-to-legacy-sink`); verdict in
`specs/255-plugin-encoding-findings/verdicts.md`.

## Expected

A script folder with letters outside the code page (e.g. `C:/Skripty/Žluťoučký kůň`) chosen with
*Browse* is shown correctly and stored byte for byte; after reopening the configuration it is
still the same folder. `check_encoding.py --plugins` no longer reports `cfgdlg.cpp`.

## Approach

Make the list view Unicode (`ListView_SetUnicodeFormat` or the W messages) and convert with
`SplU8ToWAlloc` / `SplWToU8Alloc` (`splunicode.h`) at insert and read-back; the label edit
(`LVN_ENDLABELEDIT`) and the edit box beside it need the same look.

## Notes

The plug-in is not shipped; severity is one lower for that. Not reproduced on a build (the
plug-in is not built by default).

## Log

- 2026-10-20 — created (source measure:255)
