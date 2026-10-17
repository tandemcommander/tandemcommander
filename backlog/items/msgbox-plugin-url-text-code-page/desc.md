---
title: Message box shows a plug-in's code-page URL text as UTF-8
type: bug
status: open
severity: 2
area: encoding
source: leftover:185
who: agent
created: 2026-10-15
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Message box shows a plug-in's code-page URL text as UTF-8

## Problem

Left by feature 185 (message box copy to the clipboard): the dialog shows a plug-in's code-page `URL` / `URLText` as UTF-8 (they are not normalized; plug-ins only).

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L840-842. Feature 185 (`specs/185-truncate-tail-trim/`), `msgbox.cpp`.

## Expected

A plug-in's URL text is normalized at intake (plug-in metadata is UTF-8 by contract, rule 052) and shown correctly.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
