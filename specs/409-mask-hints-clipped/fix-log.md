# Fix log - 409 mask hints link clipped in translated dialogs

Backlog item `porovnani-adresaru` (GitHub #11). Branch `409-mask-hints-clipped`, started from
`main` f38220a2 on 2026-11-07.

## Measurement before (HEAD f38220a2)

`python -I -X utf8 specs/166-translation-layout/probe/layout_check.py translations --list`
(output kept as `probe/layout_before.txt`): `TOTAL clipped 1251 crossing 551`. Clipped rows of
control 102 (`IDC_FILEMASK_HINT`) in enabled languages: czech 11, french 11, slovak 11,
spanish 11, german 10, romanian 1 = **55**; dutch and hungarian 0. The reported dialog:
`CLIP czech/salamand D191 #102 91>85 nápověda k masce`. Disabled russian / ukrainian: 11 each
plus 5 CROSS rows each (not shipped).

Reachability: Commands > Compare Directories (command 737, `CCompareDirsDialog`,
`src/dialogs6.cpp`) creates `CHyperLink(HWindow, IDC_FILEMASK_HINT, STF_DOTUNDERLINE)`; the same
link is created in the 10 other dialogs (`src/dialogs2.cpp`, `dialogs3.cpp`, `dialogs4.cpp`,
`dialogsp.cpp`). `CStaticText::GetTextXOffset` (`src/gui.cpp`) puts right-aligned text at
`Width - TextWidth` - negative when it does not fit, so the first letters are cut.

Cause analysis: the `.slt` geometry is re-derived by every merge from the English template and
then grown by `tools/translate/layout.py` `widen()` from an estimate - to the right (Czech D191:
42 -> 51 du, right edge 242 -> 251). A `.slt`-only fix would not survive a merge (research.md R1, R2).

## Decisions

- Width in the English template, leftwards, right edge kept: cx 84 ("mask hints"), 120 (D2350)
  = at least `estimate_width` of every enabled language's pinned text, so `widen()` leaves the
  rows alone (research.md R2, R3).
- Pins (research.md R5): de "Maskenhinweise" / "erweiterte Maskenhinweise"; fr "aide sur les
  masques" / "aide sur les masques étendus"; es "ayuda de plantillas" / "ayuda de plantillas
  ampliadas"; ro "indicii pentru măști" / "indicii pentru măști extinse". cs, sk, nl, hu unchanged.
- `widen()` itself is not changed (spec *Clarifications*).
- speckit-analyze: 0 CRITICAL / 0 HIGH; LOW U1 (the room check's estimate test passes only after
  the refresh - by design), U2 (the "before" pictures come from the build present at the start),
  C1 (disabled languages excluded) - accepted.

## Work

### T002-T003 room check (`probe/hint_room_check.py`)

- At HEAD (`probe/room_before.txt`): EDGE and ROOM PASS in 11 dialogs, EST FAIL in 11 (every
  width below the merge's estimate of the translated text) - `TOTAL: 11 failed`.
- Negative control of ROOM after the change: a template copy with the D2320 link widened to
  x 150 (over the *Unpack with* combo) -> `ROOM D2320 FAIL new overlap with #2326`, exit 1. A
  first control (D535 link widened to x 180) did **not** fail - after the label move below nothing
  shares that line, so it was not a valid control; recorded and replaced.

### T004 English layout (`src/lang/lang.rc`)

11 `RTEXT ... IDC_FILEMASK_HINT` rows: x moved left by the added width, cx 84 (D2350 120), right
edge unchanged (table in research.md R3).

### D535 (Configuration > Recycle Bin): the first merge clipped another label

The first merge after the widening (`probe` not kept; layout checker `/tmp` run) showed three new
`CLIP …/salamand D535 #1157` rows (fr 393>323, ro 358>323, es 362>323): the merge's `widen()` grows
`IDC_STATIC_8` ("Hold SHIFT to delete…", y 175..183) to the right only up to the next control that
shares its lines - the link at y 169..177 now started at x 204 instead of 250, so the label's room
shrank from 239 to 193 du. Fix: `IDC_STATIC_8` / `IDC_STATIC_9` 2 du down (175 -> 177, 184 -> 186;
still inside their group box, which ends at 199). The link and the label no longer share a line;
the label grows up to the frame (cz 257, fr/ro/es 284 du). After the second merge no new row of any
kind. English: the two lines are 3 px lower (picture `probe/cfg_system_english_after.png`).

### T005-T006 Translations (stop-rules §2.13)

- Step 0: no new or changed English text; changed: geometry of 11 dialog controls + 2 labels of
  D535 (module `salamand`). No `english_fallback` rows in any language before.
- Commands: `.\build.cmd` -> BUILD SUCCEEDED; `src\vcxproj\build_langs.cmd --export-templates
  --module salamand` -> 1/1; dry run -> 0 unique gaps, ~0 chars in all 8 languages; real merge
  `--formality prefer_more --budget 2000` (twice: after the widening and after the D535 move) ->
  0 gaps, DeepL characters 0, validation failures 0.
- Pins (`translations/ui-overrides.json`, `salamand`, keys `#mask hints` / `#extended mask hints`;
  note list `_feature_409`): de "Maskenhinweise" / "erweiterte Maskenhinweise"; fr "aide sur les
  masques" / "aide sur les masques étendus"; es "ayuda de plantillas" / "ayuda de plantillas
  ampliadas"; ro "indicii pentru măști" / "indicii pentru măști extinse". English-text keys: control
  id 102 is shared with other controls of salamand. Read back: all 11 rows per language carry the
  pinned text; formal register not affected (no verbs addressing the user); Spanish keeps the
  corpus's "plantilla", French "masque", German "Maske".
- Changed rows per language: exactly 13 (11 hint rows + `1157` / `1158` of D535) - no other
  layout drift.
- `python -m translate.slt --verify` -> 298 files, round-trip byte-exact. `.\build.cmd full` ->
  BUILD SUCCEEDED, 189 language modules.

### T007 layout checker after

Old checker (`probe/layout_head_old_checker.txt` -> after): `TOTAL clipped 1251 -> 1196`,
crossing 551 -> 551; the 55 hint rows gone, no new CLIP / CROSS row.

### Findings fixed on the way (stop-rules rule 11)

1. **The layout checker under-counted clipping** (severity 2, a development tool). The running
   program has 77 px for the 51 du Czech D191 link (`GetClientRect`, probe `result_before_czech.txt`)
   where `layout_check.py` counted 85 px; 84 du = 126 px on screen, 140 px in the checker. Cause:
   the base unit kept its fraction (6.71) where Windows computes in integers
   (`(cx/26 + 1)/2` = 6), and `px()` truncated instead of the `MulDiv` rounding. Fixed in
   `specs/166-translation-layout/probe/layout_check.py`; now `px(51)` = 77 and `px(84)` = 126,
   exactly the program's numbers. Corrected checker on HEAD's translations (`git archive
   f38220a2 translations`, `probe/layout_head_corrected_checker.txt`): `TOTAL clipped 2230
   crossing 551`; hint rows in enabled languages **60** (cs 11, de 11, fr 11, sk 11, es 11,
   ro 4, nl 1). After (`probe/layout_after.txt`): `TOTAL clipped 2168 crossing 551`; hint rows
   **0**; no new row; two more gone (`D535 #1157` fr, es - the label move). Per-language totals
   at HEAD are about twice the counts in the `translations-clipped-labels-*` items; each item got
   a *Log* line with its corrected number.

### T008 pictures (hidden desktop, `probe/comparedirs_shot.ps1`)

The dialog opens collapsed (the link is in the part *More* shows): the probe sets
`Configuration\Compare More Options` = 1. PrintWindow right after the dialog opened sometimes
caught children not yet painted (French: bottom buttons missing, once also the link) - the probe
now forces `RedrawWindow(… ALLCHILDREN|UPDATENOW)` and waits 1.5 s, and checks the picture itself
(INK: dark pixels in the first and the last 12 px of where the right-aligned text must be).

| Run | FIT (text px / client px) | INK first / last 12 px | Picture |
|---|---|---|---|
| czech, HEAD's `salamand.slt` (negative control, module rebuilt from `git show f38220a2:…`) | FAIL 91 / 77 | FAIL 0 / 41 | `comparedirs_czech_before.png` - shows "nápověda k mas", moved right past the field |
| czech after | PASS 91 / 126 | PASS 39 / 32 | `comparedirs_czech_after.png` |
| french after | PASS 98 / 126 | PASS 43 / 35 | `comparedirs_french_after.png` |
| english after | PASS 50 / 126 | PASS 37 / 36 | `comparedirs_english_after.png` - link unchanged at the field's right edge |

All runs: END PASS (exit 0, no reports), registry restored and identical (SHA-256 B90B4B77…).
After the negative control `translations/czech/salamand.slt` was restored with `git checkout
HEAD --` and the Czech module rebuilt; the after run repeated PASS.
Configuration > Recycle Bin (`specs/166-translation-layout/probe/cfgshot_probe.ps1 -Page 3`):
english and french pictures `probe/cfg_system_*_after.png` - link and "Hold SHIFT…" label whole
(the French capture needed a second run for the same paint race).

Observed, not in the code reading: the before picture cuts the **end** of the text ("k mas"), not
its start - the rightward growth by the merge moved the control past the field; the reporter's
"clipped from both sides" is not reproduced as such. The fix does not depend on it.

### T009 Romanian

All 11 `#102` rows of `translations/romanian/salamand.slt` read "indicii pentru măști"
(D2350 "indicii pentru măști extinse"); were "indicii masca" (5), "masca indicii" (4),
"mascheaza indiciile" (D191), "indicii masca extinse" (D2350).

### T010-T012

- `BL log` on the 8 `translations-clipped-labels-*` items: #102 rows done; corrected counts.
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `issue.md` copied, draft answer in `reply.md`.
- Deviation from T008: the "before" picture was taken in Czech only (the negative control with
  HEAD's `salamand.slt`); French and English are covered by the corrected checker at HEAD
  (`probe/layout_head_corrected_checker.txt`: french D191 #102 clipped) and need no second
  negative run.
