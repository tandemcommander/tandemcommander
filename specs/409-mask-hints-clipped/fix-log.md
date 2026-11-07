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
