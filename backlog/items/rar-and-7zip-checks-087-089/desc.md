---
title: RAR reading and 7-Zip plug-in by hand: associations, WinRAR (087, 089)
type: person-step
status: open
severity: 4
area: archives
source: leftover:087
who: person
created: 2026-10-01
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [onscreen-sweep-084-archivers, clean-machine-start-077]
depends-on: []
reason: -
---

# RAR reading and 7-Zip plug-in by hand: associations, WinRAR (087, 089)

## Problem

Features 087 (7-Zip 26.03 engine with RAR reading) and 089 (its follow-ups) owe GUI checks: RAR on a fresh and an upgraded configuration, the password prompt, the 'links not unpacked' message, an update over 0.1.8, associations after an update, and packing into RAR with WinRAR.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'The features' own quickstart.md person steps' ('087 (RAR on a fresh and an upgraded configuration, the password prompt, the links message, an update over 0.1.8)', '089 (associations after an update, packing into RAR with WinRAR)') (at 7993914c); '087 ... its GUI pass joins item 3' (revision 2026-10-01). Steps: specs/087-7zip-2603-rar/quickstart.md 'Owed to a person (GUI)' 1-6; specs/089-7zip-followups/quickstart.md 'Owed to a person' 1-4.

## Expected

Every step as the two quickstarts say; results in 087's and 089's fix-logs.

## Notes

Back up HKCU\Software\Tandem Commander first. 087 step 1 needs a clean machine (Windows Sandbox with the Release tree mapped read-only, no WinRAR, no 7-Zip) - the same setup as clean-machine-start-077.

## Steps

- [ ] 087 step 1, clean machine (Windows Sandbox, no WinRAR / 7-Zip): Enter on each RAR fixture, F3, F5 out, Alt+F9; encrypted ones prompt; test_read_format_rar5_unicode.rar reports 2 links not unpacked; part1 of a multi-part set extracts across parts; a damaged archive gives an error, no crash
- [ ] 087 step 2: associations on a fresh configuration (rar;r## = 7-Zip plug-in viewer, RAR (WinRAR) packer) and over a 0.1.8 configuration (rar;r## joins the 7z row; copying into an open RAR says updates are not supported; Alt+F5 with RAR (WinRAR) still works; two restarts add nothing)
- [ ] 087 steps 3-4d: 7z regression (create, add, delete, test, extract; open in 7-Zip), hostile names, Unpack and delete with a wrong password / damaged file keeps the archive, wrong RAR5 password, Skip then Cancel
- [ ] 087 steps 5-6: read-only RAR (F8 / add says not supported); installer over 0.1.8 removes plugins/7zip/7zwrapper.dll
- [ ] 089 steps 1-2: associations after an update from 0.1.8; with WinRAR installed, copy a file into an open RAR - packed by WinRAR
- [ ] 089 steps 3-4: a 7z with a lone-surrogate name (list, extract, pack); add a file into a cleaned-name folder of a 7z - overwrite question, one item afterwards

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
