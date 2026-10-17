---
title: Plug-in messages of feature 130 not driven (SFTP, Renamer, DiskMap, ...)
type: person-step
status: open
severity: 3
area: other-plugins
source: leftover:130
who: person
created: 2026-10-13
updated: 2026-10-17
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Plug-in messages of feature 130 not driven (SFTP, Renamer, DiskMap, ...)

## Problem

Rows of feature 130 (mixed templates in 13 plug-ins) were not driven by its probe; owed to a person or a later probe.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L610-614. Records per plug-in in `specs/130-plugin-mixed-templates/triage/`.

## Expected

Each message reads correctly in the language named (no mojibake).

## Notes

Some rows could be driven by an agent probe later (the source says "owed to a person or a later probe").

## Steps

- [ ] SFTP messages against the test server (container tandem-sftp, localhost:2222)
- [ ] Renamer's error line
- [ ] DiskMap's title in German and in Spanish
- [ ] Portables messages
- [ ] UnCAB's French line
- [ ] TAR's skip line and the RPM caption
- [ ] ZIP's comment dialog title
- [ ] PictView: Save As name, rename, print error
- [ ] The title of the progress dialog during a plug-in operation (the core change of 130)

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
