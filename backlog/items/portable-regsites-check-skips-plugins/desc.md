---
title: The portable registry-site check does not scan the plug-ins
type: tech-debt
status: new
severity: 4
area: tooling
source: review:428
who: agent
created: 2026-11-14
updated: 2026-11-14
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# The portable registry-site check does not scan the plug-ins

## Problem

`tools/check_portable_regsites.py` (feature 428, run by every `build.cmd`) classifies the registry write sites of the core only (`src/*.cpp`, `src/common`, reglib). Plug-ins under `src/plugins` are not scanned, so a plug-in that writes `HKEY_CURRENT_USER` directly - outside the core's registry services, which the portable edition maps to its own settings - would silently break the portable edition's promise to keep nothing of its own in the registry.

## Evidence

Found by the independent review of feature 428 (`specs/428-portable-build/fix-log.md`, "three independent refute-first reviews", finding B7). Direct writes in plug-ins today, both on the user's explicit request (FR-008 of 428): PictView *Set as Wallpaper* (`WallpaperStyle`, `TileWallpaper` in `HKCU\Control Panel\Desktop`, `src/plugins/pictview/render2.cpp`) and the Registry Editor plug-in's *Open Folder > Active Folder* (`HKCU\Software\Microsoft\Windows\CurrentVersion\Applets\Regedit\LastKey`, `src/plugins/regedt/fs5.cpp`, `OpenActiveFolder`). PRIVACY.md names both.

## Expected

The check also scans `src/plugins/**` (and `src/common/*.h`) for direct registry writes to `HKEY_CURRENT_USER` and fails the build on an unclassified one; the two known sites are classified with a `// portable:` marker and the reason.

## Log

- 2026-11-14 — created (source review:428)
