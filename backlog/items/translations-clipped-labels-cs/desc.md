---
title: Clipped labels in the Czech translation (74)
type: bug
status: open
severity: 3
area: translations
source: manual
who: both
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: M
feature: -
related: [translations-clipped-labels]
depends-on: []
reason: -
---

# Clipped labels in the Czech translation (74)

## Problem

Users of the Czech translation see cut labels in dialogs: 74 single-line labels in the committed `translations/czech/*.slt` are wider than their control in the dialog font (MS Shell Dlg 8 pt), in 48 dialogs. The English templates have none. Example (Configuration > Viewer, dialog 630 of salamand): "Velikost tabulatoru:" needs 90 px and has 57; the picture `specs/166-translation-layout/probe/cfg_viewer_czech_committed.png` shows it and four more cut labels of that page. By module: salamand 47, ftp 8, pictview 7, filecomp 4, codeview 3, zip 2, dbviewer 1, renamer 1, undelete 1.

## Evidence

Measured at dcb6b30a by the run that split `translations-clipped-labels` (2026-10-21): `python specs/166-translation-layout/probe/layout_check.py translations --list`, the `CLIP czech/...` rows - each names the module, the dialog, the control id, needed > available px and the text (74; feature 166 measured 72). The checker measures every language folder; filter its listing by `CLIP czech/`. `specs/166-translation-layout/probe/cfgshot_probe.ps1 -Lang czech` takes a picture of a configuration page (`-Page`). Background: `specs/166-translation-layout/fix-log.md` (the merge cannot widen them: no free space - the next control or the dialog edge).

## Expected

`layout_check.py --list` shows no `CLIP czech/` row (or each remaining one recorded with a reason in the feature's fix-log); no new `CROSS czech/` row; each changed dialog checked with a picture on the hidden desktop.

## Approach

Shorter texts, pinned in `translations/ui-overrides.json` so a later merge keeps them, or a wider control / dialog in the language's `.slt` where the dialog has room (`tools/translate/layout.py` `widen` does not cross a group box frame). Keep the meaning and the register of the surrounding texts. The `salamand` module carries most of them; dialog 630 (Configuration > Viewer) is the largest single dialog across the languages. Measure before and after with the checker; `build.cmd full` builds the language modules.

## Notes

Split from `translations-clipped-labels` (one item per enabled language). who both: an agent changes and measures; the look on screen is confirmed by pictures (hidden desktop, the maintainer's own instance not running - probes share its registry key) or by a person reading the language. Shortened wording in a language the agent does not read natively deserves a reader's check.

## Log

- 2026-10-21 — created (source manual)
- 2026-10-21 — moved to Next position 62
