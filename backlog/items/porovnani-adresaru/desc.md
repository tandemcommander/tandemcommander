---
title: The mask hints link is clipped in translated dialogs (Compare Directories and 10 more)
type: bug
status: in-progress
severity: 3
area: translations
source: github#11
who: both
created: 2026-11-06
updated: 2026-11-07
verified: 2026-11-07 f38220a2
effort: S
feature: 409
related: [translations-clipped-labels-cs, translations-clipped-labels-de, translations-clipped-labels-es, translations-clipped-labels-fr, translations-clipped-labels-hu, translations-clipped-labels-nl, translations-clipped-labels-ro, translations-clipped-labels-sk]
depends-on: []
reason: -
---

# The mask hints link is clipped in translated dialogs (Compare Directories and 10 more)

## Problem

In the *Compare Directories* dialog of the Czech translation, the link that explains the mask syntax ("nápověda k masce") is clipped: the text does not fit its control. The same mask-hints link (`IDC_FILEMASK_HINT`) is clipped in up to 11 dialogs in most translations, because translated texts are longer than the English "mask hints" and the control widths come from the English layout (38-46 dialog units). The Romanian text "mascheaza indiciile" also means "masks the hints", which is a mistranslation.

## Evidence

GitHub issue #11: https://github.com/tandemcommander/tandemcommander/issues/11. Reported 2026-10-14; the version is not stated (0.1.9 was the current release then). Still present in the translations at d18047fe. The original text is in `issue.md`.

Measured at d18047fe with `python -I -X utf8 specs/166-translation-layout/probe/layout_check.py translations --list`. Under the Windows console code page it fails with `UnicodeEncodeError` without `-X utf8`. The `CLIP …/salamand D<n> #102` rows are control 102 = `IDC_FILEMASK_HINT`:
- the reported dialog: `CLIP czech/salamand D191 #102 91>85 nápověda k masce` (needs 91 px, has 85);
- the same dialog in other languages:
  - `french … 112>85 indications sur masques`;
  - `romanian … 91>85 mascheaza indiciile`;
  - `russian … 113>85`;
  - `slovak … 91>85 nápoveda k maske`;
  - `spanish … 110>85 sugerencias de plantilla`;
  - `ukrainian … 109>85`;
- the count of clipped `#102` rows per language:
  - 11 each: czech, french, slovak, spanish, ukrainian;
  - 10 each: german, russian;
  - 1: romanian.
- the Czech dialogs: D100, D104, D191, D205, D405, D520, D535, D630, D2320, D2350, D2490.

English template: `src/lang/lang.rc`, `RTEXT "mask hints",IDC_FILEMASK_HINT,…` at lines 80, 93, 176, 238, 366, 863, 891, 1127, 1204, 1240 ("extended mask hints", 72 du) and 1836 (D191: x 200, width 42). The link is a `CHyperLink` (`STF_DOTUNDERLINE`, for example `src/dialogs3.cpp:179`).

## Expected

- `layout_check.py --list` shows no `CLIP <language>/salamand D<n> #102` row for any **enabled** language (`translations/languages.cfg`), and no new `CROSS` row.
- The fix shortens the translated texts where a shorter natural wording exists. The wording is pinned in `translations/ui-overrides.json`, so a later merge keeps it.
- Where shortening is not enough, the fix widens the control to the left (it is right-aligned and must keep its right edge) inside the dialog's room, per language `.slt` or in the English template.
- The Romanian text is corrected (meaning: hints for masks) and pinned.
- Pictures of Compare Directories (D191) in Czech and at least one more language on the hidden desktop show the whole link. The maintainer's instance must not run: probes share its registry key.
- The `translations-clipped-labels-<lang>` items are told in their *Log* that their `#102` rows are done.

## Notes

Severity 3: cosmetic, a clipped label that is still readable and works as a link. Seen in every translation except English. One reporter, open since 2026-10-14. GitHub labels: bug, ai backlog.

The maintainer decided on 2026-11-06 to keep this issue as its own small item instead of leaving it inside `translations-clipped-labels-cs`. It fixes the mask-hints link in all languages at once, so the per-language items no longer need to. "Clipped from both sides" in the report was not checked on screen; the checker shows only that the text is 6 px too wide in D191.

## Log

- 2026-11-06 — created (source github#11)
- 2026-11-06 — fields set from the issue text and labels; maintainer decision 2026-11-06: own item, not folded into translations-clipped-labels-cs
- 2026-11-06 — moved to Next position 2
- 2026-11-07 — verified at f38220a2: still present at f38220a2: layout_check.py --list shows 11 clipped #102 rows each in cs fr sk es, 10 in de, 1 in ro (D191 91>85 in cs)
- 2026-11-07 — run started, feature 409
