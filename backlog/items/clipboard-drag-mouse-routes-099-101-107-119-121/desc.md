---
title: Paste, drag and drop and mouse-only routes by hand (099, 101, 107, 119, 121)
type: person-step
status: open
severity: 6
area: data-safety
source: leftover:099
who: person
created: 2026-10-06
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [drag-drop-paste-routes-194-228-230-240-by-hand]
depends-on: []
reason: -
---

# Paste, drag and drop and mouse-only routes by hand (099, 101, 107, 119, 121)

## Problem

Agent sessions have no clipboard and no real mouse; the paste and drag-and-drop routes of the move-into-archive link scan (099), the folder-alias move guard (107) and the packing guards (119), 101's paste rows and 121's folder-picker tree-view pick were not driven by probes. These are the routes on which a wrong move could lose data.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'By hand' ('paste and drag & drop routes of 099 (also Explorer as the drag source), 107 step 5, 119 step 2b, 101's paste rows') and §B quickstart list ('121 (the folder picker's tree-view pick, ...)') (at 7993914c). Steps: specs/099-move-into-archive-links/quickstart.md 'By hand' 1-3; specs/107-folder-alias-move/quickstart.md 'By hand' step 5; specs/119-packing-leftovers/quickstart.md 'By hand' step 2b; specs/101-small-leftovers/quickstart.md 'By hand' (the probe's 4 NOT DRIVEN clipboard rows); specs/121-small-batch/quickstart.md 'By hand (a person, optional)'.

## Expected

Every route refuses or warns exactly as the keyboard route does; nothing is moved, packed or deleted that should not be; results in each fix-log.

## Notes

Clipboard rows of 124 and 127 (Copy Name in the Registry Editor, Ctrl+C in an error box) are the person step `clipboard-and-screen-rows-124-127`. The drag & drop and paste routes of 194, 228, 230 and 240 are `drag-drop-paste-routes-194-228-230-240-by-hand` - one session can do both.

## Steps

- [ ] 099: mklink /J C:\t\B\J C:\t\X (a file in X); a ZIP open in the other panel; drag B onto it with Shift (Move) - the link warning; the same with Ctrl+X / Ctrl+V; also with Explorer as the drag source
- [ ] 107 step 5: drag F with the mouse (Shift = move) onto the right panel in step 2's state (\\localhost\C$\t\parentlong), and Ctrl+X / Ctrl+V - the same refusal
- [ ] 119 step 2b: drag src.zip and b.txt onto the panel showing src.zip - 'Copy Error', nothing packed; Ctrl+X, into src.zip, Ctrl+V - 'Move Error', both files still there; the same with D\x.7z
- [ ] 101: minimise to the tray in a folder named in Cyrillic - the tip shows the name; copy a 600-character path in Notepad, Ctrl+Shift+V in a panel; Alt+F5 with Move on a selection holding a folder without read access - the new message, in Czech in the Czech UI
- [ ] 121: a plug-in folder picker (Undelete's Restore to, CAB's target) - pick a folder under Network shortcuts (gets the target folder); This PC or a control-panel item - OK disabled

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
- 2026-10-17 — related: the drag & drop / paste routes of 194-240
- 2026-10-17 — migration review N3: cross-references to final slugs
- 2026-10-17 — related item real-keyboard-ime-pass-093-124-130 closed: done: steps carried out by hand by the maintainer before the 0.1.10 release; maintainer 2026-10-17
