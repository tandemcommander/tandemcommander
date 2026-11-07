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

## Review

### Review 1 (independent agent, refute-first) - no MUST

Re-measured: checker on the branch identical to `probe/layout_after.txt`; at HEAD 60 hint rows
(the fix-log's numbers); no new CLIP / CROSS row by (language, module, dialog, control); room check
0 failed, negative control with HEAD's Czech `.slt` fails 15 rows; its own overlap scan of the 8
enabled languages' `salamand.slt`: no new overlapping pair (detector fires on a synthetic D2320
link); an in-memory `translate.merge --all --module salamand --dry-run` writes byte-identical
`.slt` / `.origin`; `slt --verify` byte-exact; encoding 0; all 11 `CHyperLink` callers and
`DisplayMore` only show / hide / move the link, hit test and focus use the text rectangle;
`comparedirs_shot.ps1` in Romanian and German: FIT / INK / END PASS (86/126, 79/126 px),
registry identical.

Findings and what was done:

- SHOULD 1 - the FTP plug-in has the same link, clipped (`IDT_ASCIIMASKHINTS`, ftp D520 #530,
  Configuration > Defaults; cs 67>66, fr 85>66, de 84>66, ro 93>66, es 115>66) and now
  different wordings from the core. Severity 3 -> **fixed here** (rule 11):
  `src/plugins/ftp/lang/lang.rc` 291,191,39 -> 246,191,84 (right edge 330 kept; the field above
  ends at y 189, nothing else on y 191..199); pins in a new `ftp` section of
  `translations/ui-overrides.json` (de/fr/es/ro the core's wordings; cs/sk "příklad masky" /
  "príklad masky", nl, hu unchanged), note `_feature_409`. §2.13 for module `ftp`: build, export
  (`530,246,191,84,8,0,"mask hints"`), dry run 0 gaps in 8 languages, real merge 0 gaps, 0 DeepL
  characters, 0 validation failures; exactly one row changed per language (row 530); `slt --verify`
  byte-exact; `build.cmd full` BUILD SUCCEEDED. Checker: `TOTAL clipped 2168 -> 2163`; the five
  `ftp D520 #530` rows gone, no new row (ru / uk, off, still clipped). No picture of the FTP page:
  the checker's numbers are the program's (finding 1 of *Findings fixed on the way*).
- SHOULD 2 - `reply.md` said Romanian got a shorter wording; it got a corrected (longer) one.
  Fixed; the reply also names the FTP page.
- NOTE pins vs `.origin`: with the rows already `human` in `.origin`, a merge keeps them even
  without the pins; the pins matter for `--retranslate` and for a re-key. Accepted - the pins
  are the documented place for a human choice (feature 245) and keep it under `--retranslate`.
- NOTE Romanian diacritics: the pin uses ș/ă like the recent pins (404); the rest of D191 has
  none. Accepted (correct Romanian; the corpus has 106 ș).
- NOTE ru / uk not refreshed: off languages, allowed by the spec; their texts fit 84 du.
- NOTE checker docstring named "MS Shell Dlg 2" but measures "MS Shell Dlg" (older than 409):
  fixed in the docstring.
- NOTE English D535 two lines 3 px lower: in the spec's edge cases.

### Review 2 (independent agent, refute-first, covering the review-1 fixes) - no MUST

Re-measured: corrected checker on main and on the branch matched by (language, module, dialog,
control): hint rows 60 -> 0, ftp `#530` 5 -> 0, no new CLIP / CROSS row, `TOTAL clipped 2230 ->
2163`, crossing 551 -> 551. Checker negative control (Czech D191 back to 51 du) ->
`91>77`, the program's own number. A real `translate.merge --all` for salamand and ftp in a scratch
worktree at HEAD: byte-identical; the German pin restores 10 rows set back to "Masken Hinweise";
merge estimates of every enabled language fit 84 / 120 du (tightest fr / ro 83, es 119); no new
overlap in any enabled `.slt`; Spanish Compare Directories on the hidden desktop FIT 87/126, INK,
END PASS, registry identical. Callers (11 `CHyperLink`, `DisplayMore`, ftp `AttachHyperLink`)
only show / hide / move the link.

- SHOULD 1 - the "after 409" counts logged on the `translations-clipped-labels-*` items predated
  the FTP fix (cs 133 / de 160 / es 144 / fr 267 / ro 130, now one lower each) and no item named the
  ftp row: a corrected *Log* line added to the five items (hu, nl, sk were right).
- NOTE 1 - `probe/layout_after.txt` predated the FTP fix: regenerated (`TOTAL clipped 2163
  crossing 551`).
- NOTE 2 - FTP page has no picture; proven by the checker, whose control widths match the program;
  text widths are measured in the assumed font in both the checker and FIT - the INK pixel test and
  the pictures are the independent proof, margins large (at most 93 of 126 px). Accepted.
- NOTE 3 - wordings still differ (cs/sk FTP "příklad masky", nl three spellings) - older than 409,
  cosmetic, the per-language items. Not changed.
- NOTE 4 - checksum `IDC_LABEL_HINT` ("clipboard hint", `checksum D1000 #1005`) clipped in fr/de/ro -
  a different link, already counted in the per-language items. Not changed.
- NOTE 5 - the Czech reply said "na snímku" (the reporter might read it as their screenshot):
  now "v našem testu".
- NOTE 6 - old review worktrees of other features registered in git - not 409's; not touched.
