---
title: Menu bar hot keys typed after F10 arrive as code-page bytes
type: bug
status: open
severity: 3
area: panels-ui
source: measure:256
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: [menubar-loop-swallows-typed-characters]
depends-on: []
reason: -
---

# Menu bar hot keys typed after F10 arrive as code-page bytes

## Problem

With the menu bar active and no popup open (F10, or Alt pressed and released), a typed letter opens the top-level menu whose hot key it is. That loop, `CMenuBar::EnterMenuInternal`, takes messages with the code-page `PeekMessage` and converts the byte with `SalACPCharToW`: a character outside the keyboard layout's code page arrives as `?`, a DBCS character as two bytes, so a menu bar hot key outside that code page (a translation, a plug-in's menu) cannot be typed there, and `?` can open the menu whose hot key is `?`. Alt+letter from the main loop (093, `IsMenuBarMessageEx`) and the popups (feature 256) are wide already.

## Evidence

At 05b87f57 (branch 256-popup-wide-mnemonics): `src/menubar.cpp` `CMenuBar::EnterMenuInternal`, the loop `while (!leaveLoop)` - `PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)`, `case WM_CHAR:` `HotKeyIndexLookup(SalACPCharToW((char)msg.wParam), index)`, then `DispatchMessage(&msg)`. Mechanism measured in feature 256 (`specs/256-popup-wide-mnemonics/probe/peek_mechanism.ps1`, ACP 1250): a `WM_CHAR` posted as UTF-16 arrives through `PeekMessageA` as 3F for U+0416 and U+4E2D, 63 for U+010D; through `PeekMessageW` exact. Feature 256 made the same change in `CMenuPopup::TrackInternal` (probe `pm256_probe.ps1` 3 FAIL -> 6 / 0).

## Expected

The menu bar's loop takes messages wide (`PeekMessageW` / `DispatchMessageW`) and matches the typed UTF-16 unit, as the popups do since feature 256.

## Notes

Not named by the item of feature 256 (`menu-popup-loop-wide-mnemonics`), so left unchanged there. Related to `menubar-loop-swallows-typed-characters` (the same loop, another defect). Not reproduced in the product: the probe of 256 drives popups only; posting `WM_CHAR` to the main window while the menu bar loop runs should drive it the same way.

## Log

- 2026-10-20 — created (source measure:256)
- 2026-10-20 — moved to Next position 44
