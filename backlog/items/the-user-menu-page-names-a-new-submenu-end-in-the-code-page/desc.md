---
title: The User Menu page names a new submenu end in the code page, not UTF-8
type: bug
status: open
severity: 2
area: encoding
source: review:268
who: agent
created: 2026-10-20
updated: 2026-10-21
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# The User Menu page names a new submenu end in the code page, not UTF-8

## Problem

When the user checks *Submenu* for a User Menu item (Options > Configuration > User Menu), the page adds a closing item named with `LoadStr(IDS_ENDUSERSUBMENU)` - a code-page string - while `CUserMenuItem::ItemName` holds UTF-8 (read with `SalRegQueryValueExW8`, drawn with `SalU8ToWAlloc`, saved with `SalRegSetValueExW8`). In a UI language whose "(Submenu End)" text has non-ASCII letters (German "(Untermenü Ende)"), the end item's name is stored in the code page; it shows correctly today only through fallback paths (an ANSI draw, a "transitional tolerance" on save).

## Evidence

At 318a1198: src/dialogs4.cpp, `CCfgPageUserMenu`, the Submenu-checkbox branch - `CUserMenuItem* item = new CUserMenuItem(LoadStr(IDS_ENDUSERSUBMENU), emptyBuffer, ...)`. Standing rule of CLAUDE.md: "`LoadStr` is code page; UTF-8 sinks take `LoadStrU8`". Found by the second independent review of feature 268 (specs/268-damaged-list-entries/fix-log.md, *Review*), which cited the draw fallback at src/edtlbwnd.cpp (`DrawTextEx`) and the save tolerance at src/salamdr6.cpp; feature 268 creates the same end item in the loader with `LoadStrU8`. Not reproduced in a German UI.

## Expected

The page names a new submenu end with `LoadStrU8(IDS_ENDUSERSUBMENU)`, so the stored name is UTF-8 in every UI language.

## Notes

Severity 2: no visible defect today (the fallbacks hide it), and an end's name is never used as a command. The review's line numbers for edtlbwnd.cpp / salamdr6.cpp were not re-checked.

## Log

- 2026-10-20 — created (source review:268)
- 2026-10-21 — moved to Next position 73
