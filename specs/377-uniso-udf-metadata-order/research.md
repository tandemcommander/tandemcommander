# Research - 377

## R1 Where the metadata file entry is read

- Decision: record the metadata file location in the partition map while the LVD is read; read the entry in
  `CUDF::ReadSupportingTables`, case `mapMetadata` (called by `Open` after the descriptor loop ends with the
  terminating descriptor).
- Rationale: `ReadSupportingTables` already exists for the same purpose (the VAT of a virtual partition is
  resolved there, after the PD is known); its `mapMetadata` case is empty. The read keeps its code (sector,
  tag check, `ReadFileEntry` with 361's refusal, the error box with `quiet` = false).
- Alternatives: (a) read the whole sequence twice / sort it so the PD comes first - more code, same effect;
  (b) re-read the metadata entry when the PD arrives - order-dependent, would read a wrong sector first.

## R2 Measured layout (IMAPI2FS, Windows 11, `UDFRevision = 0x250`)

Main sequence 32 PVD, 33 IUVD, 34 LVD (FSD at block 0 of partition reference 1; map 0 type 1 physical,
partition 0; map 1 type 2 `*UDF Metadata Partition`, partition 0, metadata file 0, mirror 96, bitmap
0xFFFFFFFF), 35 PD (number 0, start 288, length 160), 36 USD, 37 TD. Metadata file entry: EFE, file type
250, at partition block 0 (sector 288), one short_ad: 64 KB at partition block 32. FSD at sector 320.
Folder entries use short_ad (metadata partition), file entries long_ad into partition 0.

`CUDF::PD` is not set by the constructor: before the PD is met `PD.Start` is heap content
(0xCDCDCDCD in the Debug build), so the read failed and the box showed the block number 0
("Cannot read sector #00000000."). The second box comes from `ListDirectory` (FSD translation through
an empty metadata map).

## R3 Pure decision for saltests?

- Decision: none. The change is an ordering of reads inside the reader, not a rule that can be stated
  without the image reader; the probe proves it (a PD-first copy of the same image and a crafted unreadable
  metadata location as controls).

## R4 Test images

- IMAPI2FS (`specs/356-uniso-udf-rest/probe/imapiudf356.ps1 -Revision 0x250`) is the only 2.50 writer here
  (mkudffs 2.3 refuses 2.50 for a plain file).
- `img377.py swap`: the same image with sectors 34 and 35 exchanged (PD first, tag locations and tag
  checksums fixed) - must list as well, before and after (control that the PD-first path is unchanged;
  before the fix it lists, which proves the order is the cause).
- `img377.py metafar`: the metadata file location set past the image - the read fails: the old error box,
  nothing extracted, image kept (FR-004).
