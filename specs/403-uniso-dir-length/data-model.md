# Data model - 403-uniso-dir-length

## Folder record (ISO 9660 directory record, from the image)

- `LocationOfExtent` (32-bit) - less `ExtentOffset`, plus `ExtendedAttributeRecordLength` = the block
  the walk reads.
- `DataLength` (32-bit unsigned) - the directory's bytes.

## Rules (`src/common/salisowalk.h`)

| Rule | Input | Result |
|------|-------|--------|
| `SalIsoDirLengthReadable(length)` | length (64-bit) | true for 1 .. `SAL_ISO_DIR_MAX_LENGTH` (268,435,456) |
| `SalIsoDirLastBlock(block, length, sectorSize, &last)` | block, length >= 1, sector size >= 1 | true and `last = block + (length - 1) / sectorSize` when `last <= 0xFFFFFFFF`; false otherwise (also length 0 or sector size 0) |

## Walk outcome of a refused folder

Same as a failed read (features 330 / 400): the box once per walk (quiet in fit / count walks),
ERR_TERMINATE (ERR_CONTINUE for the root), the listing marked incomplete; later folders walked.
