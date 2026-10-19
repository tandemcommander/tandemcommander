---
title: Check network drive names and disconnected icons with a real SMB server
type: person-step
status: open
severity: 4
area: panels-ui
source: leftover:246
who: person
created: 2026-10-18
updated: 2026-10-19
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Check network drive names and disconnected icons with a real SMB server

## Problem

Feature 246 shows a mapped network drive's Windows name in the Change Drive menu and the
drive bar tooltip and makes the drive bar's disconnected icon follow Windows. Two parts
could not be driven on the development machine: hovering the drive bar (the tooltip follows
the real cursor; the hidden desktop has none) and the state "the drive letter is still
listed but its server is off" (only a real server that goes away produces it).

## Evidence

`specs/246-network-drive-labels/quickstart.md` § 3 (person steps); probe rows T1 HOVER
(NOT DRIVEN) in `specs/246-network-drive-labels/probe/results-fixed.txt`; `analysis.md`
G2 ("not producible on this machine"). The original report used a Samba server.

## Expected

The name, the tooltip and the icons behave as `specs/246-network-drive-labels/contracts/drive-ui-text.md`
describes with a real SMB server.

## Steps

- [ ] Map a share of a real NAS or Samba server to a letter (remembered) and rename the
      drive in Explorer (F2) to e.g. "Archiv" → Alt+F1 shows `Archiv (<UNC path>)`;
      hovering the drive's button on the drive bar shows the same tooltip.
- [ ] With Tandem Commander running, switch the server off (or unplug its network); switch
      to another window and back → the drive's button on the drive bar shows the
      disconnected icon (red cross); Alt+F1 shows the same icon.
- [ ] Switch the server on; pick the drive on the drive bar → the panel opens the drive and
      the icon is the connected one again.
- [ ] Switching between Tandem Commander and other windows stays instant while the server
      is off (no delay on activation); if a third-party network provider (Citrix, VMware,
      a WebDAV client) is installed, check this with it too.

## Log

- 2026-10-18 — created (source leftover:246)
- 2026-10-19 — moved to Person steps position 2
