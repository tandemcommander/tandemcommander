---
title: A damaged highlighting entry hangs the program at start-up
type: bug
status: open
severity: 7
area: panels-ui
source: measure:245
who: agent
created: 2026-10-18
updated: 2026-10-19
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# A damaged highlighting entry hangs the program at start-up

## Problem

LoadConfig reads the panel item highlighting list in a loop that only advances when the entry has a Masks value; an entry without it (a damaged or hand-edited configuration, an imported .reg) is opened again and again: the start-up never ends and a key handle leaks each round.

## Evidence

src/mainwnd2.cpp:2596 at 18e0bd3c (CMainWindow::LoadConfig, the Panel Items Hilighting loop): itoa(++i) and CloseKey(hSubKey) are inside the if (GetValue(... Masks ...)) branch only. Found by reading while writing the settings import (feature 245), not reproduced.

## Expected

An entry without masks is skipped (the loop advances and closes the key) or ends the list; the program starts.

## Log

- 2026-10-18 — created (source measure:245)
- 2026-10-19 — moved to Next position 2
