---
title: Popup menu hot keys by hand: Russian layout, DBCS and UTF-8 systems, TortoiseSVN
type: person-step
status: open
severity: 3
area: panels-ui
source: leftover:256
who: person
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: M
feature: -
related: [menuchar-owner-routing, menubar-loop-wide-mnemonics]
depends-on: []
reason: -
---

# Popup menu hot keys by hand: Russian layout, DBCS and UTF-8 systems, TortoiseSVN

## Problem

Feature 256 made the popup menus take typed characters as UTF-16, ask the owner (`WM_MENUCHAR`) with the character, and carry out an owner's select / execute answer; the Find window's hidden option hot keys also compare characters. The hidden-desktop probe posts characters to a popup; a real keyboard, an IME, other system code pages and a real owner-drawn shell extension were not available to the run.

## Evidence

`specs/256-popup-wide-mnemonics/fix-log.md`, *Not driven (owed to a person)*; `specs/256-popup-wide-mnemonics/quickstart.md` step 4. Probe `probe/pm256_probe.ps1` (posted characters): before 3 FAIL, after 6 / 0.

## Expected

Each step below behaves as written on a Release build of 0.1.11 or later.

## Steps

- [ ] Czech (or English) Windows, a Russian keyboard layout added: User Menu (Configuration > User Menu; F9 opens it) item named "&Жук" running e.g. `notepad`; open the User Menu, switch to the Russian layout, type Ж - the item runs; type ? - nothing or the item whose hot key is ?, never "&Жук".
- [ ] The same User Menu with an item "&Čtení": with the Czech layout type č - the item runs (not an item whose hot key is C).
- [ ] A Japanese (DBCS) Windows, or the system locale set to Japanese: a User Menu item "&日記" (or a plug-in menu item with a full-width hot key); type 日 through the IME in the open popup - the item runs; ASCII hot keys in the same popup still work.
- [ ] Windows with "Beta: Use Unicode UTF-8 for worldwide language support" on: a popup item with an accented hot key (e.g. "&Čtení") - typing č runs it.
- [ ] TortoiseSVN installed, right-click a file in a working copy (in the panel), open the TortoiseSVN submenu and type the hot key of one of its owner-drawn items - the item is selected / run (not measured before 256: by reading, no owner could match).
- [ ] Any popup (Files menu, context menu, drive menu Alt+F1): arrows, Home / End, Enter, Esc, Alt, F10, mouse clicks behave as before.
- [ ] Find window (Alt+F7) with the Options part collapsed: Alt+the hot key of "Containing" / "HEX-mode" / "Case sensitive" / "Whole words" / "Regular expression" expands Options and focuses the control (English and Czech: as before). With a Russian build of the language file, Alt + the Cyrillic hot key does the same.

## Log

- 2026-10-20 — created (source leftover:256)
- 2026-10-20 — moved to Person steps position 15
