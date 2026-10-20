---
title: Shell extensions in the panel background menu and the Find window never answer typed hot keys
type: bug
status: new
severity: 2
area: panels-ui
source: review:256
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

# Shell extensions in the panel background menu and the Find window never answer typed hot keys

## Problem

Since feature 256 a popup that finds no item for a typed key asks its owner with `WM_MENUCHAR` carrying the character, and carries out the owner's select / execute answer; shell extensions that draw their own items (TortoiseSVN) answer through `IContextMenu3::HandleMenuMsg2`. Two owners still lose the question or the answer: (1) the panel's list (`CFilesBox::WindowProc`) sends every `WM_MENUCHAR` to `Parent->ContextMenu` and returns, so for the background menu (right-click on empty panel space - its menu is `ContextSubmenuNew`'s) and for the New submenu inserted into a file's context menu the right handler is never asked; (2) the Find window's `DialogProc` returns the handler's answer as `(BOOL)lResult`, but `WM_MENUCHAR`'s result reaches the caller of a dialog only through `DWLP_MSGRESULT` - the answer comes back as 0.

## Evidence

Review of feature 256 (`specs/256-popup-wide-mnemonics/fix-log.md`, *Review*, finding S2). At 66520422 (branch 256-popup-wide-mnemonics): `src/filesbx1.cpp` `CFilesBox::WindowProc` `case WM_MENUCHAR:` - the `Parent->ContextMenu` branch returns before the `ContextSubmenuNew` forwarding (`SafeHandleMenuNewMsg2`); the background menu is built in `src/shellsup.cpp` (`ShellAction` context menu of the panel, `ContextSubmenuNew` ~2134 / 2195-2302) and the New submenu insertion ~2310-2330. `src/finddlg1.cpp` `CFindDialog::DialogProc` `case WM_MENUCHAR:` `return (BOOL)lResult;`. The reviewer measured the shell's own handler: for a menu that is not its own it answers `S_OK` and leaves the result untouched.

## Expected

The panel asks the handler whose menu the popup shows (the file's context menu or the background / New menu), and the Find window returns the handler's answer through `DWLP_MSGRESULT`, so a typed hot key of an owner-drawn shell-extension item works in both.

## Notes

Severity 2: only owner-drawn extension items with hot keys the program's own matching cannot see; the mouse works. Needs a person with TortoiseSVN (or another owner-drawn extension) to confirm. Feature 256 initialized the panel's results to 0 and ignores a failed `HandleMenuMsg2`, so a misrouted question answers "nothing" when the asked handler leaves the result alone (measured
with the shell's own handler only; an aggregated extension answering about a menu not its own is not
excluded - review 2 of 256, N2).

## Log

- 2026-10-20 — created (source review:256)
- 2026-10-20 — related item menu-popup-loop-wide-mnemonics done in feature 256
