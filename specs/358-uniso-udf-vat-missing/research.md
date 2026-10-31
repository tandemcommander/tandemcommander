# Research - 358-uniso-udf-vat-missing

## R1. What a missing VAT should do

- Decision: `CUDF::Open` fails (ReadSupportingTables FALSE) when the VAT search ends without a VAT, with the
  existing message "Missing virtual allocation table." (shown only for a non-quiet open).
- Rationale: the nearest existing behaviour - an unreadable VAT sector (`IDS_UDF_ERROR_READING_VAT`) already
  returns FALSE (probe row C-VCLAIM: kept, no crash). A volume whose virtual blocks cannot be translated cannot
  be listed: every block of its file set lies in the virtual partition. Failing the open lets the existing
  rules mark the listing: `CISOImage::ListTracks` -> `MarkTrack(SAL_ISO_TRACK_NOT_OPENED)` (334) for a UDF-only
  track, `CUDFISO::Open` -> `PartMissing` (330) for a hybrid. A single-volume image then does not open
  (`ListArchive` FALSE); a whole unpack fails and keeps the image.
- Alternatives: open the volume and list nothing with `SetIncomplete` - needs a listing path that never calls
  `LogSector` and adds a new state; rejected (more change, same outcome). Search the whole file for the VAT -
  out of scope (spec Clarifications).

## R2. The translation bound

- Decision: `lbNum < entries` and a table present (`SalIsoUdfVatTranslates`). `lbNum` is `Uint32` (the
  `lbNum >= 0` test was always true); `entries` is `Uint64`.
- Rationale: entries are indices 0 .. entries-1 (UDF 2.60 2.2.11: the table holds `entries` 32-bit entries).

## R3. The VAT 2.00 entry count

- Decision: `SalIsoUdfVat200Entries(infoLen, headerLen, tableLen, &entries)`: false when `headerLen > infoLen`
  or `infoLen > tableLen` (the table buffer holds `tableLen` bytes - `ReadVAT` allocates `(DWORD)InformationLength`)
  ; else `entries = (infoLen - headerLen) / 4`. A false result makes `CheckForVAT` free the table and return
  `ERR_CONTINUE` (not a VAT).
- Rationale: a crafted header length larger than the table made `Entries` wrap to ~2^64 and `Translation` point
  past the buffer; bounding it keeps `LogSector` inside the table. Cheap and inside the item's "never reads past
  the table".
- Not covered (separate defect): `ReadVAT` / `ReadAllocDesc` copy each allocation descriptor's whole length into
  the table buffer without checking it against the buffer's size (a crafted image can write past it), and a
  64-bit InformationLength is truncated to 32 bits for the allocation. To Inbox (`measure:358`).

## R4. Callers of `LogSector` and an invalid sector

- `LogSector` already returns `INVALID_SECTOR_NUMBER` for blocks it cannot translate (the `else` branch);
  callers (`MapICB`, `ReadFileEntry`-path at 592, `ListDirectory`, `ScanDir`, `UnpackFile` at 1066) read
  through `ReadBlockLog` (refuses `INVALID_SECTOR_NUMBER` = -11111111 outright) or `ReadBlockPhys` (reads
  sector `PD.Start + 0xFF5672B9`, far past any image, so the read fails) - both already handled as a read
  error (330's marks). With R1 a volume without a table never reaches `LogSector`; R2 only matters for a found
  table and a block number at or past its end (crafted images).
