# Research - 409 mask hints link

## R1. Where the per-language width comes from

- Decision: set the width in the English template `src/lang/lang.rc`.
- Rationale: `tools/translate/merge.py` starts every dialog row's geometry from the exported English
  template and then runs `layout.widen()` (comment near "Geometry now always starts from the
  template"); `translate.relayout` does the same. A width written only into a language's `.slt`
  is overwritten by the next merge.
- Alternatives: per-language `.slt` edits (lost on the next merge); teaching `widen()` to grow
  right-aligned controls leftward (would re-lay out every right-aligned control of every module
  on its next merge - outside the item, spec *Clarifications*).

## R2. Why the merge must not widen these rows itself

- Finding: `widen()` compares an estimate (`estimate_width`: 4.05 du per character + 2) with the
  control width and grows the control to the **right**, up to the dialog margin or the next
  control. For the right-aligned link that moves its right edge (Czech D191 at HEAD: cx 42 -> 51,
  right edge 242 -> 251, no longer aligned with the field above).
- Decision: the English width is at least the estimate of every enabled language's text after the
  pins - then `needed <= cx` and `widen()` does nothing for these rows.
- Estimates (du) after the pins - "mask hints": cs 66, sk 66, de 58, fr 83, es 78, ro 83, nl 50,
  hu 42 -> **84**; "extended mask hints": cs 115, sk 115, de 103, fr 115, es 119, ro 115, nl 50,
  hu 99 -> **120**. Real widths (dialog font, the checker's metrics) are lower: at most 58.4 du
  (fr) and 91.8 du (cs).

## R3. The room to the left

| Dialog | English x,cx -> right | new x (cx) | nearest control to the left on the same lines |
|---|---|---|---|
| D100 Select | 154,42 -> 196 | 112 (84) | none (the combo ends at y 32) |
| D104 Unselect | 158,38 -> 196 | 112 (84) | none |
| D191 Compare Directories | 200,42 -> 242 | 158 (84) | none (the edit ends at y 245) |
| D205 Copy/Move more | 203,41 -> 244 | 160 (84) | none |
| D405 Change filter | 185,39 -> 224 | 140 (84) | none (the combo's closed height ends at y 46) |
| D520 Unpack | 175,41 -> 216 | 132 (84) | none |
| D535 Cfg System | 250,38 -> 288 | 204 (84) | "Hold SHIFT…" ends at x 195 |
| D630 Cfg Viewer | 247,46 -> 293 | 209 (84) | none |
| D2320 Cfg Unpackers | 257,38 -> 295 | 211 (84) | the *Unpack with* combo ends at x 153 |
| D2350 Cfg Associations | 223,72 -> 295 | 175 (120) | none (the list ends at y 163) |
| D2490 Convert | 152,41 -> 193 | 109 (84) | the combo above (closed 15..29) already overlaps the link's first line by 1 du at HEAD - unchanged |

The probe `hint_room_check.py` verifies this table mechanically (no new overlap).

## R4. English rendering

- `CStaticText` (`src/gui.cpp`, the base of `CHyperLink`) draws right-aligned text at
  `Width - TextWidth`; hit test (`TextHitTest`) and focus rectangle (`DrawFocus`) use the text's
  rectangle only. A wider control changes nothing in English.

## R5. Wordings

| Language | now | pinned "mask hints" | pinned "extended mask hints" |
|---|---|---|---|
| german | "Masken Hinweise" (D191 "Masken-Hinweise") | Maskenhinweise | erweiterte Maskenhinweise (was "Zusätzliche Masken Hinweise" = additional) |
| french | "indications sur les masques" | aide sur les masques | aide sur les masques étendus |
| spanish | "sugerencias de plantilla" | ayuda de plantillas | ayuda de plantillas ampliadas |
| romanian | "indicii masca" / "masca indicii" / D191 "mascheaza indiciile" | indicii pentru măști | indicii pentru măști extinse |
| czech, slovak | "nápověda k masce" / "nápoveda k maske" | unchanged (no shorter natural wording) | unchanged |
| dutch, hungarian | fit | unchanged | unchanged |

Terms: the Spanish corpus says "plantilla" for a mask (27 rows), French "masque", German "Maske".
