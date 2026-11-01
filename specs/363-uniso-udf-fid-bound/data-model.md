# Data model - 363-uniso-udf-fid-bound

## File Identifier Descriptor (ECMA-167 4/14.4)

| Offset | Field | Size | Use here |
|---|---|---|---|
| 0 | descriptor tag (id 257) | 16 | `ReadDescriptorTag` |
| 18 | file characteristics | 1 | folder / parent / hidden / deleted |
| 19 | L_FI | 1 | name length, 0 - 255 |
| 20 | ICB (long_ad) | 16 | the entry's file entry |
| 36 | L_IU | 2 | implementation-use length, 0 - 65535 |
| 38 | implementation use | L_IU | skipped |
| 38 + L_IU | file identifier (name) | L_FI | decoded (OSTA compressed) |
| | padding | to 4 | |

Length = `4 * ((38 + L_IU + L_FI + 3) / 4)`; UDF: at most one logical block.

## Rule `SalIsoUdfFidLength(held, pos, lFI, lIU, len)`

- Inputs: `held` - bytes of the buffer; `pos` - the identifier's position in it; `lFI`, `lIU` - from the image.
- True, `len` = padded length: `pos <= held` and `len <= held - pos` (64-bit; the head, `lIU`, `lFI` and the
  padding are each subtracted from what is left, so nothing can wrap).
- False, `len` = 0: otherwise. The caller then reads nothing past the 38-byte head and refuses the folder.

## Walk state (`ScanDir`)

`p` - position in `directory[2 * SECTOR_SIZE]`, `<= SECTOR_SIZE` at each read; after an accepted identifier
`p + len <= 2 * SECTOR_SIZE`, so after the one-sector step again `<= SECTOR_SIZE`.
