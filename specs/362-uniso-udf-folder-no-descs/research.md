# Research - feature 362

## R1. Who calls the folder reader?

- Decision: `CUDF::MapICB(CAD, CICBTag*, CAD*)` has two callers, both for folders: `CUDF::ListDirectory` (the root
  ICB of the File Set Descriptor, also requiring file type 4) and `CUDF::ScanDir` (an identifier with
  `UDF_DIRECTORY`, listed with `ADD_LISTED`). The other overload `MapICB(CAD, CFileEntry*)` (files' size / time)
  is not touched.
- Rationale: Grep of `MapICB` at 5d74e338 (`udf.cpp` only; `udf.h` declarations).
- Alternatives: changing `ReadFileEntry` to refuse L_AD 0 - rejected: it also serves files (an empty file has L_AD
  0 and is valid), the unpack and the metadata partition.

## R2. Which reader results mean "no folder data"?

- Decision: the reader with `maxAds` 1 returns 1 (a descriptor stored), -1 (embedded data, only when the area is
  non-empty), 0 (no descriptor: the area is empty, i.e. L_AD 0, for every valid type 0 - 3), or `UDF_FE_REFUSED`
  (-2). A non-empty area of descriptors that holds less than one descriptor is already refused by 361's rule (not a
  whole number of descriptors). So 0 <=> L_AD 0 for an accepted entry. Walkable = `stored > 0 || stored == -1`.
- Rationale: code of `ReadFileEntry` and `SalIsoUdfEntryDescs`; checked by the grid model in `saltests`.
- Alternatives: decide on the entry's fields (L_AD) in `MapICB` - rejected, it would read the fields a second time;
  the reader's result already carries the answer.

## R3. Is an L_AD 0 folder ever valid?

- Decision: no. ECMA-167 4/14.4: a directory contains a File Identifier Descriptor for its parent (the root: one
  pointing to itself), so its information length is at least 38 bytes and its descriptors describe at least that.
  Measured controls: genisoimage's empty folder `e` (ue.iso, L_AD 8) and mkudffs's empty root (embedded, L_AD 40)
  list and unpack (probe rows L-UE, C-UE, C-MKCDR before the fix).
- Alternatives: keep listing such a folder empty but mark the listing - the same outcome for the image; going
  through `MapICB`'s 0 reuses 330's single path and also prevents the Release build's walk from the terminating
  descriptor's unset `Offset` (the item's note).

## R4. Root with L_AD 0 on a hybrid image

- Decision: "Bad root ICB" (existing `IDS_UDF_BAD_ROOT_ICB`), listing incomplete; the ISO 9660 part lists and
  unpacks as before. Measured before the fix: R-ROOTLAD0 extracted the ISO 9660 part's three files and deleted the
  image.
