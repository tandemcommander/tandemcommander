# Data model - 402-uniso-xbox-name-bound

## Xbox (XDVDFS) directory entry

| Offset | Size | Field |
|---|---|---|
| 0x00 | 2 | left subtree offset (not used by the walk) |
| 0x02 | 2 | right subtree offset (not used) |
| 0x04 | 4 | start sector |
| 0x08 | 4 | file size |
| 0x0C | 1 | attributes (0x10 folder) |
| 0x0D | 1 | name length `len` (0 - 255) |
| 0x0E | len | name |

The next entry starts at `offset + 14 + len` rounded up to 4; 0xFF bytes pad a sector's end.

## Rules (`src/common/salisoxboxentry.h`)

- `SalIsoXboxEntryHeadFits(size, offset)`: `offset <= size && size - offset >= 14`.
- `SalIsoXboxEntryFits(size, offset, nameLen, next)`: head fits and `size - offset - 14 >= nameLen`; then
  `next = (offset + 14 + nameLen + 3) / 4 * 4` (64-bit; may exceed `size` by up to 3 - the walk ends).
  False: `next = 0`.

## States of a directory's walk

`ERR_OK` (walked whole) -> a damaged record -> `ERR_CONTINUE` (the walk of this directory ends, the box
once per walk, the listing marked incomplete at the top).
