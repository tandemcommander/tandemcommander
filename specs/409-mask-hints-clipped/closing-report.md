# Closing report - 409-mask-hints-clipped
Backlog item: porovnani-adresaru - The mask hints link is clipped in translated dialogs (Compare Directories and 10 more)
Outcome: closed

## What changed

- `src/lang/lang.rc`: the 11 `RTEXT ... IDC_FILEMASK_HINT` links widened to the left, right edge
  kept: cx 84 du ("mask hints"), 120 du (D2350 "extended mask hints"). Configuration > Recycle Bin
  (D535): `IDC_STATIC_8` / `IDC_STATIC_9` 2 du down so the link and the "Hold SHIFT…" label no
  longer share a line (the merge's widening would otherwise give the label less room).
- `src/plugins/ftp/lang/lang.rc`: the same link of Configuration > Defaults (`IDT_ASCIIMASKHINTS`)
  widened to the left, 39 -> 84 du, right edge kept (review 1).
- `translations/ui-overrides.json`: pins `#mask hints` / `#extended mask hints` for salamand
  (de "Maskenhinweise" / "erweiterte Maskenhinweise", fr "aide sur les masques" / "… étendus",
  es "ayuda de plantillas" / "… ampliadas", ro "indicii pentru măști" / "… extinse") and for ftp
  (`#mask hints`, the same four wordings).
- `translations/<8 languages>/salamand.slt` (13 rows each) and `ftp.slt` (1 row each): refreshed
  by `translate.merge` - 0 gaps, 0 DeepL characters.
- `specs/166-translation-layout/probe/layout_check.py`: integer dialog base units and MulDiv
  rounding, as Windows (finding fixed on the way).
- New probes `specs/409-mask-hints-clipped/probe/hint_room_check.py`, `comparedirs_shot.ps1`.

## Measurements (before / after, commands)

- `python -I -X utf8 specs/166-translation-layout/probe/layout_check.py translations --list`,
  corrected checker: at HEAD f38220a2 (`git archive`) `TOTAL clipped 2230 crossing 551`, hint rows
  in enabled languages 60 (+ 5 ftp `#530`); after `TOTAL clipped 2163 crossing 551`, hint rows 0,
  ftp rows 0, no new CLIP / CROSS row (two more gone: D535 `#1157` fr, es). Old checker: 55 -> 0,
  1251 -> 1196.
- `python -I -X utf8 specs/409-mask-hints-clipped/probe/hint_room_check.py`: HEAD 11 failed (EST)
  -> 0 failed; negative control (link over a combo) fails ROOM.
- `comparedirs_shot.ps1` on the hidden desktop: Czech with HEAD's `salamand.slt` FIT FAIL 91/77 px,
  INK FAIL 0/41 (picture "nápověda k mas"); after cs 91/126, fr 98/126, en 50/126 - FIT, INK, END
  PASS; registry restored and identical every run. Review 1 also ran ro, de: PASS.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd full` -> BUILD SUCCEEDED, 20 plug-ins, 189 language modules.
- `python -m translate.slt --verify` -> 298 files, round-trip byte-exact.
- `saltests`: not run - no core or `src/common/` code changed (resources and translation data only).
- Probes: as above; no NOT DRIVEN row.

## Reviews (findings and what was done)

- Review 1: no MUST. SHOULD 1 (the FTP link, same defect) - fixed; SHOULD 2 (reply said Romanian
  was shortened) - fixed; NOTEs accepted or fixed (checker docstring) - fix-log *Review*.
- Review 2: no MUST. SHOULD (the item counts logged before the FTP fix) - corrected *Log* lines on
  five items; NOTEs: `layout_after.txt` regenerated, the Czech reply reworded, the rest accepted.

## Owed to a person (the lines added to the release checklist)

- None added: every row was driven on the hidden desktop.
- Answer and close GitHub issue #11 (draft in `specs/409-mask-hints-clipped/reply.md`).
- Add the CHANGELOG entry below (there is no `[Unreleased]` section):

  - **The "mask hints" link was cut off in translated dialogs** (feature 409; GitHub #11). In
    Compare Directories and ten more dialogs (Select / Unselect files, Unpack, Convert, Copy/Move
    more options, Change filter, the Recycle Bin, Viewer, Unpackers and Archive associations
    configuration pages) and in the FTP configuration, the link under a mask field lost letters in
    most translations. It now has room to the left in every dialog, its right edge where it was;
    German, French and Spanish use shorter wordings, the Romanian text is corrected ("hints for
    masks"). On the Recycle Bin page the two lines under the mask field are 2 dialog units lower.
    Other clipped labels of the translations remain (tracked per language).

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- The layout checker (166) counted controls ~11% wider than on screen (51 du: 85 px instead of the
  program's 77) and so under-counted clipping - fixed (integer base unit, MulDiv rounding); the
  8 `translations-clipped-labels-*` items got their corrected counts in *Log*.
- The FTP plug-in's identical link (review 1 SHOULD 1) - fixed.
- The Recycle Bin label clips the widening caused in fr / ro / es - fixed (2 du move).

## New Inbox items (slug - title)

- None.
