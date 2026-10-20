---
title: Popup menu mnemonics fail on DBCS / UTF-8 code pages; dialog hot keys by byte
type: bug
status: in-progress
severity: 4
area: panels-ui
source: leftover:237
who: agent
created: 2026-10-16
updated: 2026-10-20
verified: 2026-10-20 084744e0
effort: M
feature: 256
related: []
depends-on: []
reason: -
---

# Popup menu mnemonics fail on DBCS / UTF-8 code pages; dialog hot keys by byte

## Problem

Left by features 236 / 237 (menu hot keys): (a) the popup's message loop is ANSI - a DBCS / code-page-65001 key byte matches nothing (needs a wide loop like 093's); (b) `OnChar` sends `WM_MENUCHAR` with `wParam = MF_POPUP` and no character - the owner-draw (TortoiseSVN) fallback can never match (upstream); (c) `GetControlHotKey` (`finddlg1.cpp:2956`) compares a dialog control's text with a key byte-wise.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L560-566 (point (4)). Features 236 (`salmenuhotkey.h`) and 237 (`SalMenuKeyMatch`, `SalMnemonicMatchW`) - `specs/236-menu-hotkeys-utf8/`, `specs/237-popup-menu-mnemonics/`.

## Expected

Popup mnemonics match whole characters on DBCS and UTF-8 code-page systems; owner-draw items get the typed character in `WM_MENUCHAR`; dialog control hot keys compare characters, not bytes.

## Notes

Narrow: only DBCS or code-page-65001 systems and owner-draw shell extensions; severity 4 because the function does not work there (the mouse is the workaround). Real-keyboard checks are a person's (093's IME pass).

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-20 — verified at 084744e0: at 084744e0: PeekMessageA (popup loop) turns posted U+0416 into 3F, U+010D into 63, PeekMessageW exact; WM_MENUCHAR wParam=MF_POPUP by reading; GetControlHotKey byte vs VK (ru/uk only)
- 2026-10-20 — run started, feature 256
