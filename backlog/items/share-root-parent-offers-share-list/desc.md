---
title: `..` / Go to root in \\server\share does nothing without the Network plug-in
type: improvement
status: in-progress
severity: 3
area: panels-ui
source: leftover:125
who: agent
created: 2026-10-13
updated: 2026-10-21
verified: 2026-10-21 e35f8588
effort: M
feature: 284
related: [decide-ship-network-plugin-nethood, share-list-offers-sign-in]
depends-on: []
reason: -
---

# `..` / Go to root in \\server\share does nothing without the Network plug-in

## Problem

The parent of a share's root (`..`, Backspace, *Go to root* in `\\server\share`) does nothing without a Network plug-in. It could offer the share list of feature 125 (`CFilesWindow::PickServerShare`). Not part of GitHub #5.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L537-539. Feature 125 (`specs/125-unc-server-shares/`), `CFilesWindow::PickServerShare`.

## Expected

In the root of `\\server\share`, `..` / Backspace / *Go to root* offer the server's share list (as Change Directory to `\\server\` does since 125); with the Network plug-in present the plug-in's behaviour stays.

## Notes

Depends in spirit on the nethood decision: if the plug-in is enabled, its `net:` panel covers this.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-21 — verified at e35f8588: reproduced at e35f8588: hidden-desktop probe at `\\localhost\C$` - Backspace and Go to root leave the panel there, no share list; no up-dir entry is listed (Home, Enter opens a folder)
- 2026-10-21 — run started, feature 284
