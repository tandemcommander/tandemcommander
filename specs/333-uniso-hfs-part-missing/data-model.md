# Data model - 333-uniso-hfs-part-missing

## HFS+ volume header (1024 bytes into the HFS part, TN1150)

| Bytes | Meaning | Rule |
|---|---|---|
| 0-1 = "H+" | HFS+ volume header | declared |
| 0-1 = "BD", 124-125 = "H+" | HFS wrapper (master directory block) with an embedded HFS+ volume | declared |
| 0-1 = "BD", 124-125 other | original HFS | not declared |
| 0-1 = "HX" | HFSX | not declared |
| anything else, fewer than 2 bytes read | no HFS+ volume (e.g. an EFI FAT image of an install ISO) | not declared |

`SalHfsVolumeHeaderDeclaresHfsPlus(hdr, size)`: true only for the two "declared" rows; "BD" needs at
least 126 bytes.

## States of the HFS part in `CUDFISO::Open`

| `CHFS::Open` | `CHFS::Declared` | Result |
|---|---|---|
| TRUE | TRUE | listed under `HFS (<name>)` (as before) |
| FALSE | TRUE | dropped, `PartMissing` = TRUE -> listing incomplete (new) |
| FALSE | FALSE | dropped without a mark (as before) |

## Apple partition map entry (review 1)

`SalHfsApmEntryIsHfs(e, size, &start)`: true for "PM" + pad 0 + `pmParType` exactly "Apple_HFS"
(byte 48, the zero at 57 included; needs 58 bytes); `start` = `pmPyPartStart` (byte 8, big-endian).
Used only after the map's walk failed: blocks 1-64, damaged entries passed over, a short read ends the
search; the volume header at `start` x block size + 1024 decides (table above).
