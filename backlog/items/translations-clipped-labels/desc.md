---
title: 711 clipped labels in the shipped translations
type: bug
status: open
severity: 3
area: translations
source: measure:166
who: both
created: 2026-10-14
updated: 2026-10-18
verified: -
effort: L
feature: -
related: [translate-merge-bundle-rekey]
depends-on: []
reason: -
---

# 711 clipped labels in the shipped translations

## Problem

Feature 166 measured every single-line label in the dialog font: the English templates have 0 clipped, the committed translations of the 8 enabled languages 711 (cs 72, de 99, fr 163, nl 83, hu 46, ro 76, sk 84, es 88; all 11 folders 1,260), plus 661 controls reaching past the frame of their group box. Example (Czech, Configuration > Viewer): "Velikost tabulatoru:" needs 90 px and has 57. The merge cannot fix them (no free space: the next control or the dialog edge).

## Evidence

Migrated from specs/NEXT-WORK.md §A item 16 (L365) (at 7993914c). specs/166-translation-layout/fix-log.md; `specs/166-translation-layout/probe/layout_check.py --list` names each label; `probe/cfgshot_probe.ps1` takes a picture of a configuration page.

## Expected

`layout_check.py` reports 0 clipped labels for the enabled languages (or each remaining one recorded with a reason); each changed dialog checked with a picture.

## Approach

Per language: shorter texts (pinned in `translations/ui-overrides.json`) or wider dialogs; 166 did not run the wholesale regeneration of all modules (170 files) - it removes only 23 of 1,260 and needs a visual check. Pictures need the hidden desktop with the maintainer's instance not running (probes share its registry key).

## Notes

who both: an agent changes and measures, a person or pictures confirm the look.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
- 2026-10-18 — measure:244 - the Configuration > Panels page in French clips two existing checkbox texts (Rediriger le clavier du panneau..., Maj+chiffre...); the new quick-search checkbox of 244 was pinned to fit (specs/244-quick-search-substring-filter/fix-log.md, Translations)
