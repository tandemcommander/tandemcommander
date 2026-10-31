# Data model - 361-uniso-udf-entry-bound

## File entry (ECMA-167 4/14.9, 4/14.17) as the reader sees it

| Field | Plain entry | Extended entry | Rule |
|---|---|---|---|
| ICB tag flags & 7 | offset 16 + 18 | same | 0 short (8), 1 long (16), 2 extended (20), 3 embedded; 4 - 7 reserved → refused |
| L_EA | 168 | 208 | fixed part + L_EA within the sector |
| L_AD | 172 | 212 | area end within the sector; a multiple of the descriptor size (types 0 - 2) |
| descriptor area | 176 + L_EA | 216 + L_EA | `[first, end)`, `end <= 2048` |

## `SalIsoUdfEntryDescs(sectorLen, extended, lEA, lAD, type, first, end, size)`

- true: `first`, `end` = the area, `size` = 8 / 16 / 20, or 0 for embedded data (the whole area);
- false (refused): area outside the sector (360's `SalIsoUdfVatDescArea`), reserved type, or `lAD % size != 0`.

## Reader result

| Result | Meaning |
|---|---|
| `>= 0` | descriptors stored (as before; at most `maxAds`, a terminating entry when room is left) |
| `-1` | embedded data (`Offset`, `Length` set; as before) |
| `UDF_FE_REFUSED` (-2) | new: the entry is refused, nothing stored |
