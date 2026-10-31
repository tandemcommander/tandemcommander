---
title: Plug-in hot keys on F-keys never run; F-keys run commands bound to letters
type: bug
status: open
severity: 4
area: panels-ui
source: measure:346
who: agent
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Plug-in hot keys on F-keys never run; F-keys run commands bound to letters

## Problem

A plug-in menu command whose hot key is an F-key (Plugins Manager accepts F-keys the program does not use, e.g. Ctrl+Alt+F6 or, before 346, Shift+F6) never runs when the user presses that key. Worse, an F-key with modifiers that no main-window accelerator takes runs a *different* plug-in command: the one bound to the letter P..[ with the same modifiers (F1 = P, F2 = Q, ... F6 = U, ... F11 = Z). Example: the Undelete plug-in's default hot key is Ctrl+Shift+U; Ctrl+Shift+F6 reaches the plug-in lookup only when it bypasses the accelerator (it did in the 346 probe) and then opened Undelete. In the real message loop any F-key combination that is not an accelerator row (e.g. Ctrl+Alt+F6, Alt+Shift+F2) reaches the panel's key handler and is looked up as the letter.

## Evidence

At f99a0746:
- `src/plugins2.cpp`, `CPlugins::QueryHotKey`: `BYTE vk = UpperCase[(BYTE)wParam];` - meant for letters typed with Caps Lock; `UpperCase[]` is a character table (`src/common/str.cpp`, `CharUpperA` of each byte), so the virtual keys VK_F1..VK_F12 (0x70..0x7B = 'p'..'{') become 'P'..'['. The hot key it builds is then compared with the stored `HOTKEY_GET` value (`FindHotKey`), which holds the real VK_F* code for an F-key binding - never equal.
- Callers: `CFilesWindow::OnSysKeyDown` (`src/fileswn0.cpp`, the panel, last step) and the command line (`src/editwnd.cpp`, `Plugins.HandleKeyDown`).
- Measured: `specs/346-shift-f6-inplace-rename/probe/rip346_probe.ps1`, row CS6 (`probe/result_after.txt`): Ctrl+Shift+F6 sent to the panel list opened the Undelete dialog (`[#32770 'Undelete'] ... Select disk to analyze`), in the before run too (e0c3690d). Fix-log `specs/346-shift-f6-inplace-rename/fix-log.md`, *Probe problems on the way* 1.

## Expected

Only letters are upper-cased (VK 'a'..'z' do not occur as virtual keys anyway; the Caps Lock note concerns the hot-key edit, which already stores upper case): an F-key is looked up as the F-key, so a plug-in command bound to an F-key runs, and an F-key never runs a command bound to a letter. A saltests check of the lookup (a pure function in `src/common/`) for F1..F12 and letters.

## Notes

- Feature 346 keeps a stored Shift+F6 plug-in binding at load (`IsSalHotKeyKeptAtLoad`) and tries the plug-ins before the panel's Shift+F6: once this is fixed, such a binding runs instead of Rename in Place - intended (the user's own choice wins), but name it in the changelog of the fix.
- Not verified: whether any plug-in ships a default hot key on an F-key (a grep of `SALHOTKEY(VK_F` in `src/plugins` found none at f99a0746).

## Log

- 2026-10-31 — created (source measure:346)
- 2026-10-31 — related item shift-f6-renames-the-focused-item-in-place-without-the done in feature 346
- 2026-10-31 — moved to Next position 33
