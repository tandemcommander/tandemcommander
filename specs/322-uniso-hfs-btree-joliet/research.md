# Research - feature 322

## R1. Which catalog fields come from the image, and what bounds them

Read at a222bd88, `src/plugins/uniso/hfs.cpp` `CHFS::BTree::BTree` and TN1150:

| Field | Where | Bound used now | Bound decided |
|---|---|---|---|
| catalog `logicalSize` | volume header fork | none (malloc) | > 0, not more than `totalBlocks * blockSize` (the load would fail later anyway) |
| header node descriptor + `BTHeaderRec` | offset 0 | none | 14 + 106 bytes inside the catalog |
| `nodeSize` | header rec +18 | none (0 allowed) | 120 .. catalog size (a header node holds its record; real images use 512..32768) |
| `firstLeafNode` | header rec +10 | none | 0 = empty tree (no records); else the node lies wholly inside the catalog |
| `fLink` | node +0 | none; a cycle never ends | the node lies wholly inside; a node seen twice refuses |
| `numRecords` | node +10 | none | descriptor (14) + record table (2 a record) fit the node |
| record offset | node table | none | >= 14 and offset + 2 <= start of the record table |
| `leafRecords` | header rec +6 | malloc of that many pointers | a hint only (MagicISO 5.2 writes a wrong count; the old code already re-grew the array) |
| key length, name length | record | none (223 bounded the name at 255) | key + record type inside the record's bytes; name inside the key |
| folder / file data | after the key | none | `sizeof(HFSPlusCatalogFolder)` / `sizeof(HFSPlusCatalogFile)` inside the record's bytes |

- Decision: a wrong node structure refuses the catalog (`SAL_HFSCAT_DAMAGED`); a record whose key
  or data does not fit is skipped by the consumers.
- Rationale: the spec's clarifications; never a read outside the loaded catalog.
- Alternatives: refuse the volume for one bad record (loses the rest of a volume that reads fine
  otherwise - rejected); check `kind == leaf` for each walked node (a stricter rule than any bounds
  need; MagicISO images are known to be quirky - rejected, conservative).

## R2. Where the walk lives

- Decision: header-only `src/common/salhfscatalog.h`, functions on a byte buffer, no globals, malloc'd
  result; `saltests` includes it.
- Rationale: CLAUDE.md - pure decisions into `src/common/` with `saltests` checks; shared rules for
  plug-ins are header-only (the plug-in cannot compile a `.cpp` of `src/common`).

## R3. Joliet names

`ListDirectoryRe` (files): `ConvJolietName(fileName, src, LengthOfFileIdentifier)` writes UTF-8,
then `ExtractFileName(fileName, fileName, dr)` -> `ExtractExtFileName` skips Rock Ridge for Joliet
and ends with `lstrcpyn(fileName, src, dr.LengthOfFileIdentifier + 1)` - the UCS-2 byte length.
Folders call `ConvJolietName` only. Worked example: 12 CJK letters + `.txt;1` = 18 units = 36
identifier bytes; UTF-8 = 36 + 6 = 42 bytes; the copy keeps 35 bytes + NUL - the 12th letter's
last bytes and `.txt` are lost.

- Decision: for Joliet `ExtractExtFileName` copies the converted name whole (bounded by its
  destination buffer, which holds any converted identifier: 255 bytes -> at most 127 units -> at
  most 381 UTF-8 bytes < 521).
- Alternatives: convert in `ExtractExtFileName` (a larger change of a shared path - rejected).

## R4. Test images

- IMAPI2 (`IMAPI2FS.MsftFileSystemImage`, `FileSystemsToCreate = 3`) - ISO 9660 + Joliet, as
  feature 223's probe.
- xorriso 1.5.6 (Ubuntu noble packages fetched with `apt-get download` and unpacked with `dpkg -x`
  into `~/tc-xorriso` in the maintainer's WSL - no root): `-hfsplus on -joliet on` writes an Apple
  partition map (`ER`, block size 2048), an HFS+ volume header (measured at offset 123904) and
  ISO 9660 + Rock Ridge + Joliet. Measured: the image of a 2-file tree is 458752 bytes.
- An HFS+-only image (reaches `CHFS` directly, errors not quiet): cut from the hybrid by the
  mutation script (the bytes from the HFS+ partition start), or the hybrid with its ISO 9660
  descriptors removed - decided in the implementation by measurement (fix-log).

## R5. The fuzzing pass

- Unit level: from built valid catalogs, N = 20000 deterministic mutations (an LCG seed; 1-8
  random bytes overwritten, or a 16/32-bit field set to an edge value 0 / 1 / 0xFFFF / size-ish);
  each mutation runs the walk on an exact-size heap copy and every returned record is checked to lie
  inside the buffer; the walk must return (bounded by nodes).
- Program level: the probe writes M mutated images per seed (HFS+ catalog bytes; ISO 9660 / Rock
  Ridge / Joliet volume descriptors and directory extents) and opens each in the program; a row
  fails on a program exit, a bug report or a hang (no main window answer in the time limit).
