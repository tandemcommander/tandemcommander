---
title: On-screen sweep of 084 archivers: run the ready probes, then a visual pass
type: person-step
status: open
severity: 4
area: archives
source: leftover:084
who: person
created: 2026-10-01
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [rar-and-7zip-checks-087-089]
depends-on: []
reason: -
---

# On-screen sweep of 084 archivers: run the ready probes, then a visual pass

## Problem

Feature 084 (archiver clean-up) is complete on paper and unverified on screen. Its probes are ready but were not run at the maintainer's request (2026-10-01); the visual pass of the Pack / Unpack dialogs and archiver configuration pages and RAR packing with WinRAR 7.x are owed.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'On-screen sweeps' ('084 archivers (probes ready)') and §3 '084 (working archivers)' (~line 1101) (at 7993914c). Probes in specs/084-archiver-cleanup/probe/; steps in specs/084-archiver-cleanup/quickstart.md §4, §6.

## Expected

Both probes report no failure and restore HKCU\Software\Tandem Commander; the visual pass in English and Czech and the WinRAR packing are recorded in 084's fix-log.

## Notes

Both probes back up and restore HKCU\Software\Tandem Commander and verify the restore - still keep a backup of your own (see the probe-interruption rule). 087 and 089 also owe RAR packing with WinRAR (item rar-and-7zip-checks-087-089); one session with WinRAR installed can do all.

## Steps

- [ ] Close your own Tandem Commander
- [ ] specs/084-archiver-cleanup/probe/make_cfg_fixtures.ps1 -Exe "C:\Program Files\Tandem Commander\tandemcommander.exe" -OutDir specs\084-archiver-cleanup\probe\fixtures\cfg
- [ ] gui_probe.ps1 -Exe <Debug build>: Autoconfiguration, ARJ / Unicode browse and extract through 7-Zip, hiding, Cancel, the 0.1.8 -> 106 migration
- [ ] Visual pass of the Pack / Unpack dialogs and the archiver configuration pages in English and in Czech (084 quickstart.md §4)
- [ ] RAR packing with WinRAR 7.x (084 quickstart.md §6)

## Log

- 2026-10-01 — maintainer: the 084 probes are not run now (maintainer's request)
- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
