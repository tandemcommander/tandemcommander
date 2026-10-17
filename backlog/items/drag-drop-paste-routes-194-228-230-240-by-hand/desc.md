---
title: Drag & drop and paste routes of 194, 228, 230, 240 by hand
type: person-step
status: open
severity: 6
area: data-safety
source: leftover:230
who: person
created: 2026-10-17
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [clipboard-drag-mouse-routes-099-101-107-119-121]
depends-on: []
reason: -
---

# Drag & drop and paste routes of 194, 228, 230, 240 by hand

## Problem

Four fixes of the drag & drop and paste routes were made by reading and building only: the routes need a real OLE drag & drop or the clipboard, neither of which exists on the hidden desktop. Two of them guard data: before 230, dragging or pasting only `a.txt` into a ZIP from a case-sensitive folder holding `a.txt` and `A.txt` also packed `A.txt` (with Move: deleted it from disk) and overran a heap array; before 228, a source folder deeper than 259 bytes was cut, the listing could come from a sibling folder, and a Move of a junction into a ZIP passed the 099 link check and deleted what lies behind the junction. 194 (a drop onto a shortcut whose target path is longer than 260) and 240 (a too long folder name now says why) were not driven either.

## Evidence

Owed-to-a-person passages of the fix-logs, none of which reached NEXT-WORK (its rows for these features are `done`): `specs/194-drop-shortcut-target/fix-log.md` ~L39 ("Owed to a person: drag a file onto a shortcut whose target folder's path is longer than 260 bytes (or has 130+ Czech letters) - the drop goes into the target folder"); `specs/228-dragdrop-archive-long-source/fix-log.md` *Read (not driven)* (L8-24); `specs/230-dragdrop-case-sensitive-names/fix-log.md` *Read (not driven)* (L8-15) and *Review* 1 (the case-insensitive fallback, e.g. PowerShell `Set-Clipboard -Path .\README.TXT` for `readme.txt`); `specs/240-dragdrop-long-folder-name/fix-log.md` L14 ("Not driven (drag & drop / clipboard)"). Code: `CFilesWindow::DragDropToArcOrFS` / `AddDragDropItem` in `src/fileswna.cpp`, `ClipboardPasteToArcOrFS` (`fileswn9.cpp`). Found by the review of the migration (`specs/242-backlog-system/ledger/review.md`, S1).

## Expected

Every step below passes on a Release build; results recorded in the four fix-logs; a failure becomes a new item.

## Notes

Severity 6: a check that guards data-loss fixes (reference.md §3). The routes of 099, 101, 107, 119 and 121 are the person step `clipboard-drag-mouse-routes-099-101-107-119-121` - one session can do both. A case-sensitive folder can be made with `fsutil file setCaseSensitiveInfo <folder> enable`.

## Steps

- [ ] 194: drag a file with the mouse onto a `.lnk` whose target folder's path is longer than 260 bytes (or holds 130+ Czech letters) - the file lands in the target folder.
- [ ] 228: a source folder deeper than 259 bytes next to a sibling whose name starts the same (`...\Projekt` and `...\Projekt - kopie`); drag items from the deep folder into a ZIP panel, and Ctrl+C there / Ctrl+V into the ZIP panel - exactly the dragged items are packed, with their own sizes and times.
- [ ] 228: the same deep folder holding a junction (with a plain folder of that name in the sibling); Shift+drag (Move) the junction into a ZIP - the 099 link warning appears; nothing behind the junction is deleted.
- [ ] 230: a case-sensitive folder holding `a.txt` and `A.txt`; drag only `a.txt` into a ZIP, and Ctrl+C / Ctrl+V it - only `a.txt` is packed; with Shift+drag / Ctrl+X (Move) `A.txt` stays on disk.
- [ ] 230: in a normal folder, `Set-Clipboard -Path .\README.TXT` (PowerShell) for `readme.txt`, Ctrl+V into a ZIP panel - packed, no "some files were not found".
- [ ] 240: drag (and Ctrl+C / Ctrl+V) a folder whose name is over 255 bytes (86+ CJK letters) into a ZIP panel - "Cannot finish operation because of too long name", nothing packed half.

## Log

- 2026-10-17 — created (source leftover:230)
- 2026-10-17 — moved to Person steps position 5
- 2026-10-17 — body written from the fix-logs of 194, 228, 230, 240 (migration review S1)
