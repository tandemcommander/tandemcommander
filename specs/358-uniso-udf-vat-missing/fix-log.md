# Fix log - 358-uniso-udf-vat-missing

Backlog item `iso-plug-in-a-udf-image-with-a-vat-and-data-past-it-crashes` - ISO plug-in: a UDF image with a
VAT and data past it crashes Tandem Commander.

## Measurement before (main 249e35f0, Debug x64 build of HEAD)

- Probe `probe/iso358_probe.ps1` (new; built on 356's probe and review 2's `rev356b_probe.ps1`): images by
  `specs/356-uniso-udf-rest/probe/mkudf356.sh` in WSL Ubuntu, `probe/vatimg.py` appends data to `mk_cdr.img`
  as review 2's `compose2.py` did. Run:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <probe>\iso358_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -OutFile ..."`
- Result `probe/result_before.txt`: **PASS 14, FAIL 8** - R-VCDR100, R-VCLAIM16, R-VCLAIM100Z (Unpack, Alt+F9,
  "Delete archive after unpacking") and L-VCDR100 (Enter on the image - the panel listing alone) end in a bug
  report "access violation: read on 0x0000000000000000" after the box "Missing virtual allocation table."
  (END + RUN rows each). C-VCLAIM ("Error reading virtual allocation table at sector #00000E9F", kept),
  C-MKCDR / C-MKCDRC / C-MKDVDR / C-MKBDR / C-MKHD (no window, nothing extracted, deleted) and L-MKCDR pass.
  Registry restored, identical.

## Sites (read at HEAD)

- `src/plugins/uniso/udf.cpp` `CUDF::ReadSupportingTables`, case `mapVirtual`: `ret` is TRUE from the start;
  `vatRet == ERR_CONTINUE` after the search shows `IDS_UDF_MISSING_VAT` and keeps TRUE; `ERR_TERMINATE` (from
  `CheckForVAT` / `ReadVAT`: unknown allocation strategy, no memory) breaks and keeps TRUE too.
- `CUDF::LogSector`, case `mapVirtual`: `lbNum >= 0 && lbNum <= PartitionMapping.Entries` then
  `PartitionMapping.Translation[lbNum]` - NULL table read; `<=` one past the table.
- `CUDF::CUDF`: `Translation`, `VAT`, `nMetadataICBs` set, `Entries` / `Length` left uninitialized.
- `CUDF::CheckForVAT`: VAT 2.00 `Entries = (InformationLength - l_hd) / 4` - `l_hd` (a WORD from the table)
  is not checked against the table's length (underflow -> a huge count).
- Callers of `CUDF::Open` (`ReadSupportingTables`' only caller is `Open`): `CISOImage::OpenTrack` (fsUDF: Open
  FALSE -> the track does not open -> `ListTracks` marks it `SAL_ISO_TRACK_NOT_OPENED` -> incomplete; the
  single-track listing then fails: `ListArchive` FALSE, a whole unpack fails, image kept) and `CUDFISO::Open`
  (hybrids: the UDF part dropped, `PartMissing` when the anchor at 256 is there - feature 330).
- `LogSector` callers: `ListDirectory`, `ScanDir`, `MapICB`, `ReadBlockLog`, unpack paths - all already treat
  `INVALID_SECTOR_NUMBER` as a failed read (to be confirmed in implementation).

## Decisions

- Not finding the VAT (or a terminating error in the search) fails `ReadSupportingTables` -> `CUDF::Open` FALSE,
  the same as the existing "Error reading virtual allocation table" path (C-VCLAIM): conservative, the nearest
  existing behaviour; no new UI string.
