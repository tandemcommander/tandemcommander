# Data model - 350-nrg-cuex-bounds

## CUEX chunk (from the image)

| Field | Source | Rule |
|---|---|---|
| Size | chunk header, big-endian DWORD | the chunk is read only when `[pos, pos + Size)` lies within the file (`SalNrgChunkFits`) |
| header | 16 bytes | skipped; read whole or no entry is taken |
| entries | 16 bytes each | `SalNrgCuexEntryCount(Size)` = `Size < 16 ? 0 : (Size - 16) / 16`; each read whole or the reader stops |
| entry byte 4..7 | big-endian DWORD | the audio track's `ExtentOffset` (unchanged) |

After the chunk: the next chunk header starts at `pos + Size`.

## Pure rule (src/common/salnrgcdtext.h)

`unsigned long long SalNrgCuexEntryCount(unsigned long long size)` - never more than `size / 16`,
0 for `size < 32`.
