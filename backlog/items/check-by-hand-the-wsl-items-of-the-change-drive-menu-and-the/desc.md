---
title: Check by hand the WSL items of the Change Drive menu and the drive bar (374)
type: person-step
status: new
severity: 3
area: panels-ui
source: leftover:374
who: person
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Check by hand the WSL items of the Change Drive menu and the drive bar (374)

## Problem

Feature 374 added one `Linux - <distribution>` item per WSL distribution to the Change Drive menu
(Alt+F1 / Alt+F2), a WSL button (a drop-down with several distributions) to the drive bar, and the
check box *Linux Distributions (WSL)* to the *Change Drive Menu and Drive Bar* configuration page.
The hidden-desktop probe checked the items, their texts, order, tooltips, the opened paths and the
option through the program's probe seam, but it cannot look at icons or use a real mouse.

## Evidence

`specs/374-wsl-drive-item/fix-log.md`, section *Probe* - "Not driven on the hidden desktop": the
look of the penguin icon in the menu and on the bar, a real mouse click on the drop-down button,
and ticking the new check box on the configuration page. Probe `probe/wsl374_probe.ps1` 13 / 13 PASS.

## Expected

The items look right and work with the real mouse and keyboard on a computer with WSL.

## Steps

- [ ] On a computer with at least two WSL distributions, press Alt+F1: the items
      `Linux - <name>` stand between the cloud storages and Network and show the Linux penguin
      icon (the icon of `System32\wsl.exe`), sharp at the current display scaling.
- [ ] Click the drive bar's penguin button with the mouse: a menu of the distributions drops
      down under it; choosing one opens `\\wsl.localhost\<name>` in that bar's panel. The
      button's tooltip reads `Linux`.
- [ ] Options > Configuration > *Change Drive Menu and Drive Bar*: the check box *Linux
      Distributions (WSL)* stands between *Cloud Storage Services* and *Network*, nothing
      overlaps (also in Czech and German); clear it, OK: the menu and the bar show no WSL item;
      tick it again: they come back.

## Log

- 2026-11-01 — created (source leftover:374)
