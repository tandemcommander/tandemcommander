# Data model - 364-uniso-udf-folder-extents

## Folder entry (from the image)

| Field | Where | Meaning |
|---|---|---|
| Information Length | entry offset 56, 64 bits (File Entry and Extended File Entry) | the folder's size in bytes |
| allocation descriptors | the entry's descriptor area (L_AD bytes; 361's rule) | extent length (30 bits), type (2 bits: 0 recorded, 1 allocated not recorded, 2 not allocated, 3 continuation), location, partition |
| embedded data | descriptor area, ICB flags type 3 | one piece: offset in the entry's sector, L_AD bytes |

## CUDFFolder (plug-in, new)

| Field | Meaning |
|---|---|
| `Ext[32]` | the descriptors read (`CAD`) |
| `Count` | extents walked (the rule's `walk`) |
| `Length` | bytes walked (the rule's `walkLen`, 64-bit) |
| `Offset` | embedded data's offset in the entry's sector, else 0 |
| `Whole` | `Length >= Information Length` |

## Rules (salisoudfentry.h)

- `SalIsoUdfFolderExtents(types[], lens[], count, blockLen, infoLen, walk, walkLen) -> whole`
  - walk the leading descriptors with type 0 and length > 0; stop after one whose length is not a multiple of
    `blockLen`.
  - `whole = walkLen >= infoLen`.
- `SalIsoUdfFolderSector(lens[], walk, blockLen, sector, extent, block) -> bool`
  - false when `walk == 0`; else the extent holding window block `sector` (extent i covers
    `ceil(lens[i] / blockLen)` blocks), past the last: the last extent with `block` counted on.
