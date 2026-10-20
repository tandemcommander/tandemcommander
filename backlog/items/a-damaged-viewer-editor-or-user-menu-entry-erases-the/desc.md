---
title: A damaged viewer, editor or User Menu entry erases the entries after it
type: bug
status: in-progress
severity: 7
area: panels-ui
source: review:250
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: 2026-10-20 56a5f414
effort: S
feature: 268
related: []
depends-on: []
reason: -
---

# A damaged viewer, editor or User Menu entry erases the entries after it

## Problem

The start-up loaders of the viewers list, the editors list and the User Menu end their list at the first damaged entry (a missing or unreadable required value - a hand-edited registry, an imported .reg) and leave that entry's key open. The save on exit clears the key and rewrites it from what was loaded, so every entry after the damaged one is erased from the configuration without a word (only a missing value is silent; a wrong type shows one "Error Loading Configuration" box).

## Evidence

At 1cb8c4fd: src/salamdr2.cpp, the viewers loop `while (OpenKey(viewersKey, buf, subKey))` - `if (GetValue(... VIEWERS_MASKS_REG ...) && strchr(masks, '|') == NULL && GetValue(... VIEWERS_TYPE_REG ...)) { ... } else break;` before `itoa(++i, buf, 10); CloseKey(subKey);`; the editors loop `while (OpenKey(editorKey, buf, subKey))` the same; src/mainwnd2.cpp, CMainWindow::LoadConfig, the User Menu loop `while (OpenKey(actKey, buf, subKey))` - `else break;` before `itoa(++i, buf, 10); CloseKey(subKey);`. The saves clear and rewrite the keys. Found by the independent review of feature 250 (specs/250-damaged-highlight-entry/fix-log.md, *Review*): the review reproduced the leaked key of the User Menu case on the hidden desktop (a User Menu entry without Item Name -> the Debug build's "monitored handles remained opened" note); the loss of the later entries is established by reading, not reproduced.

## Expected

A damaged entry is skipped (its key closed) and the entries after it are loaded, as the highlighting list does since feature 250; nothing the user had after the damaged entry disappears on exit.

## Notes

Severity 7 by the band "lose data in a narrow scenario" (the configuration entries after the damaged one); the scenario needs a damaged configuration. The low-memory `break` paths inside these loops also leave the key open; they can stay a `break` (out of memory) but should close it. A probe in the style of specs/250-damaged-highlight-entry/probe/hlt250_probe.ps1 can drive all three.

## Log

- 2026-10-20 — created (source review:250)
- 2026-10-20 — moved to Next position 1
- 2026-10-20 — verified at 56a5f414: reproduced at 56a5f414: probe dmg268 on the hidden desktop, 9 damaged rows of viewers/alt viewers/editors/User Menu keep only entries before the damaged one and leak its key; controls pass
- 2026-10-20 — run started, feature 268
