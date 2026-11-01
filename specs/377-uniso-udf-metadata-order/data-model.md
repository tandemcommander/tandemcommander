# Data model - 377

Plug-in internal structures in `src/plugins/uniso/udf.h` (no interface):

- `CUDF::CPartitionMap` - one per partition map of the LVD: `Type`, `VolumeSequenceNumber`,
  `PartitionNumber`; **new** `MetadataFileLocation` (`Uint32`, the metadata partition map's metadata file
  location minus `ExtentOffset`, as the old local `icb.Location`; meaningful only for `mapMetadata`).
- `CUDF::CPartitionMapping` - unchanged: `MetadataICBs[32]` / `nMetadataICBs` filled from the metadata file
  entry, now in `ReadSupportingTables`.

Order of states in `CUDF::Open`:

1. anchor at 256 → main sequence extent;
2. sequence loop: PVD, PD (`PD.Start`), LVD (maps recorded, no read), … until the terminating descriptor;
3. `ReadSupportingTables`: VAT for a virtual map (unchanged), metadata file entry for a metadata map (moved).
