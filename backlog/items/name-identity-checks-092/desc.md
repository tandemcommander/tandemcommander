---
title: Name identity of 092 by hand: accented names that differ only in case
type: person-step
status: open
severity: 5
area: data-safety
source: leftover:092
who: person
created: 2026-10-01
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [shares-snapshots-fat-same-folder-guards]
depends-on: []
reason: -
---

# Name identity of 092 by hand: accented names that differ only in case

## Problem

Feature 092 made the core compare names by the file system's rule (ordinal case-insensitive); its GUI checks on a Release build in Czech or another accented language are owed: cursor, Quick Rename, Move onto a case twin, Change Directory, viewer stepping, an archive open in both panels, selection, copy to the same folder.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'The features' own quickstart.md person steps' ('092') (at 7993914c). Steps: specs/092-name-identity-unicode/quickstart.md 'Owed to a person (Release build, Czech or another accented language)' 1-8.

## Expected

Each step as the quickstart says; results in 092's fix-log.

## Notes

The case-sensitive network share of 092 ('Not testable on this machine', fix-log S3 item 1) is in shares-snapshots-fat-same-folder-guards.

## Steps

- [ ] Prepare a folder with Článek.txt, ĥ.txt, Ĺ.txt, a subfolder Článek and an archive Č.zip
- [ ] 1 Cursor: on Ĺ.txt Ctrl+R keeps it; renaming Článek.txt to článek.txt in Explorer keeps the cursor on the file
- [ ] 2 Quick Rename Článek.txt to ČLÁNEK.TXT: one rename, no question; F6 on folder Článek to článek renames it
- [ ] 3 Move ĥ.txt onto Ĺ.txt (F6, type Ĺ.txt): the overwrite question appears
- [ ] 4 Shift+F7 with the path in the other case: Alt+F12 shows one entry; Backspace puts the cursor on Článek
- [ ] 5 F3 in the folder entered as článek: Space steps to the next file
- [ ] 6 Č.zip in the left panel and č.zip in the right; F4 edit, save, leave: both panels show the updated archive
- [ ] 7 Select Článek.txt and ĥ.txt, Ctrl+R: both stay selected, Ĺ.txt does not become selected
- [ ] 8 F5 to the same folder: 'Copy of ...' names offered as for ASCII names

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
