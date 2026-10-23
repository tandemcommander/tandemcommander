# Data model - 331-nrg-label-bounds

## CDTX chunk (from the image)

| Offset | Bytes | Meaning |
|---|---|---|
| 0 | 4 | flags (skipped) |
| 4 + 18k | 12 (clipped to the chunk) | text block k |
| 16 + 18k | 6 | other data (skipped) |

Gathered text = the text blocks in order. Strings = its 0-terminated parts: the first is the volume
label, then one per track in track order; a final string without a terminator ends at the text's end;
missing strings = no label.

Validation: the chunk's `Size` bytes must lie within the image after the 8-byte chunk header.

## DAOX chunk

0x16 bytes of header (first track number at 0x14, last at 0x15), then 0x2A bytes per track number
first..last. An entry applies only to a track number 1..(tracks added by CUEX).

## Listed audio name

`%02d %s` (number, label) or `Audio Track %02d`; length = the formatted length, unbounded by the
reader; the listing rule of feature 329 decides whether it is listed.
