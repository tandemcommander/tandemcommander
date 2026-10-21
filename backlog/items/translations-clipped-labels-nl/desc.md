---
title: Clipped labels in the Dutch translation (78)
type: bug
status: new
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

# Clipped labels in the Dutch translation (78)

## Problem

Users of the Dutch translation see cut labels in dialogs: 78 single-line labels in the committed `translations/dutch/*.slt` are wider than their control in the dialog font (MS Shell Dlg 8 pt), in 48 dialogs. The English templates have none. By module: salamand 24, ftp 18, zip 10, filecomp 7, pictview 7, codeview 4, 7zip 3, renamer 2, checksum 1, undelete 1, uniso 1.

## Evidence

Measured at dcb6b30a by the run that split `translations-clipped-labels` (2026-10-21): `python specs/166-translation-layout/probe/layout_check.py translations --list`, the `CLIP dutch/...` rows - each names the module, the dialog, the control id, needed > available px and the text (78; feature 166 measured 83). The checker measures every language folder; filter its listing by `CLIP dutch/`. `specs/166-translation-layout/probe/cfgshot_probe.ps1 -Lang dutch` takes a picture of a configuration page (`-Page`). Background: `specs/166-translation-layout/fix-log.md` (the merge cannot widen them: no free space - the next control or the dialog edge).

## Expected

`layout_check.py --list` shows no `CLIP dutch/` row (or each remaining one recorded with a reason in the feature's fix-log); no new `CROSS dutch/` row; each changed dialog checked with a picture on the hidden desktop.

## Approach

Shorter texts, pinned in `translations/ui-overrides.json` so a later merge keeps them, or a wider control / dialog in the language's `.slt` where the dialog has room (`tools/translate/layout.py` `widen` does not cross a group box frame). Keep the meaning and the register of the surrounding texts. The `salamand` module carries most of them; dialog 630 (Configuration > Viewer) is the largest single dialog across the languages. Measure before and after with the checker; `build.cmd full` builds the language modules.

## Notes

Split from `translations-clipped-labels` (one item per enabled language). who both: an agent changes and measures; the look on screen is confirmed by pictures (hidden desktop, the maintainer's own instance not running - probes share its registry key) or by a person reading the language. Shortened wording in a language the agent does not read natively deserves a reader's check.

## Log

- 2026-10-21 — created (source manual)
