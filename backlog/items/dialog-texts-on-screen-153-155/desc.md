---
title: New texts on screen in a translation: Archive Update (153), refusals (155)
type: person-step
status: open
severity: 2
area: translations
source: leftover:153
who: person
created: 2026-10-17
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# New texts on screen in a translation: Archive Update (153), refusals (155)

## Problem

Four features changed texts whose look on screen was not checked by a person: 153's Archive Update dialog with a marked line (an archive member changed since its F4) - readable and scrolling, in English and one translated language; 155's clearer refusal texts - one refusal of each kind in a translated language; 156's drag image text and 159's Portables information line, both in Czech.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'The features' own quickstart.md person steps' ('153 (...)', '155 (...)') (at 7993914c). Sources: specs/153-archive-member-changed-warning/fix-log.md ~line 67 ('Owed to a person: the dialog with a marked line on screen (readable, scrolls), in English and ...'); specs/155-refusal-texts/fix-log.md ~line 65 ('Owed to a person: the texts on screen in a translated language (one refusal of each)'). Neither feature has a quickstart.md. Rows of 156 and 159 added by the migration review (`specs/242-backlog-system/ledger/review.md`, S1): specs/156-drag-image-text/fix-log.md L51 ("Owed to a person (the reporter): drag several files in Czech - 'vybrané 2 soubory' whole") and specs/159-portables-infoline/fix-log.md L10-11 ("owed to a person: Portables in Czech, a device selected and none connected"); both texts draw themselves and expose nothing to a probe; NEXT-WORK carried neither.

## Expected

Both dialogs readable and complete in English and in at least one translated language; any clipped or wrong text becomes a new item.

## Notes

155's refusals: folder copy / move into itself, the pack into itself with 'leave it out of the selection', the Renamer's own texts, an empty folder copied onto itself (NW §A item 10).

## Steps

- [ ] 153: the Archive Update dialog with a marked line - readable, scrolls; in English and one translated language
- [ ] 155: one refusal of each kind on screen in a translated language
- [ ] 156: Czech UI, drag several files with the mouse - the drag image's text reads "vybrané 2 soubory" whole (specs/156-drag-image-text/fix-log.md L51)
- [ ] 159: Czech UI, the Portables plug-in's information line with a device selected ("N vybrané zařízení") and with none connected ("Žádná zařízení") - accented letters correct (specs/159-portables-infoline/fix-log.md L10-11)

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
- 2026-10-17 — migration review S1: rows of 156 (drag image text) and 159 (Portables information line) added
