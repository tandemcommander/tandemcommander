# Data model - 313

## Key of a character (`SalQFDetail::CharKey`)

| Step | Result |
|---|---|
| ASCII | lower-cased ASCII unit (unchanged; the fast path) |
| 1 | canonical decomposition (`NormalizeString(NormalizationD)`; a lone surrogate stays as it is) |
| 2 | invariant lower case (`LCMapStringEx(LOCALE_NAME_INVARIANT, LCMAP_LOWERCASE)`) |
| 3 (new) | each nonspacing mark of the blocks of research R1 is dropped (enclosing marks stay) |
| 4 (new) | each unit of the table of R2 is replaced by its ASCII letters |

Return: number of units (0 = empty key), -1 = does not fit into the caller's room.

## Per-character cache (BMP)

`Count[c]`: 0 = not computed, 1..4 = units cached, `0xFE` = empty key (new), `0xFF` = longer than
4 units (computed every time).

## Key of a text (`CSalQFKey`, unchanged layout)

`Units[0..Count)`, `Offsets[0..Count]` (byte offset of the character a unit comes from;
`Offsets[Count]` = length), `Starts[i]`: 1 = first unit of a character, 2 = later unit of a folded
letter (a match may end before it), 0 = other later unit (review 313). A character with an empty
key has no unit.

## Mask keys (`CSalQFMaskKeys`)

Segments with an empty key are not stored (new); `Count == 0` = every name matches.
