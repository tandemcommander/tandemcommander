# Fix log - 377-uniso-udf-metadata-order

Backlog item `iso-plug-in-a-udf-2-50-image-written-by-windows-imapi2fs`: an IMAPI2FS UDF 2.50 image does not
list in the ISO plug-in.

## Measurement at HEAD (main aac7105e, before the feature)

- `iso356_probe.ps1 -Only N-U250,C-PLAIN -Label before376` on the hidden desktop, current Debug build:
  N-U250 RUN (its expectation is the old defect, so PASS): files 0, image kept, windows
  "Cannot read sector #00000000." and "Error reading directory structure at sector #FF567539. Incomplete
  content of ISO image."; C-PLAIN (UDF 1.02): a.txt extracted, image deleted, no window. Registry restored,
  identical.
- Fresh IMAPI2FS 2.50 image of `a.txt`, `sub\b.txt` dumped with a scratch Python script (research.md R2):
  32 PVD, 33 IUVD, **34 LVD**, **35 PD** (start 288, length 160), 36 USD, 37 TD; LVD map 1 = `*UDF Metadata
  Partition`, metadata file at partition block 0 (sector 288, EFE type 250, extent 64 KB at block 32).
- Reachability: Enter / Alt+F9 on the image → `CISOImage` opens the UDF track → `CUDF::Open` → sequence loop
  → `ReadLVD` (sector 34) → `ReadPartitionMap` → `ReadBlockLog(0)` = `Image->ReadBlock(PD.Start + 0)` with `PD`
  not read yet (`CUDF` does not initialise `PD`; Debug heap 0xCDCDCDCD) → read fails → "Cannot read sector
  #00000000" (the box prints the block, 0) → no metadata extents → `ListDirectory` cannot translate the FSD
  (partition reference 1) → second box. Default configuration (uniso is `on` in plugins.cfg).

## Analyze

Run 1: 0 CRITICAL, 0 HIGH; MEDIUM C1 (US1 scenario 2 named Enter, the probe drives whole Unpack) - fixed by
rewording; LOW C2 (FR-005 no task - covered by the step-6 check), LOW I1 (wording) accepted. Run 2: 0
CRITICAL, 0 HIGH.

## Decisions

- The metadata file entry read moves unchanged from `ReadPartitionMap` to `ReadSupportingTables`
  (`mapMetadata`), after the whole sequence (research R1). No pure rule for saltests (research R3).

## Implementation

- `udf.h`: `CPartitionMap::MetadataFileLocation` (set to 0 for every map, the metadata map's location minus
  `ExtentOffset` for a `*UDF Metadata Partition` map).
- `udf.cpp` `CUDF::ReadPartitionMap`: records the location only, no read.
- `udf.cpp` `CUDF::ReadSupportingTables`, case `mapMetadata`: the moved read - `ReadBlockLog(location)`, the
  same error box (`IDS_ERROR_READING_SECTOR`, quiet false as before), the tag check, `ReadFileEntry` with 361's
  refusal. Called by `Open` after the sequence loop ended with the terminating descriptor (as before for the
  VAT). Callers enumerated: `ReadPartitionMap` <- `ReadLVD` <- `Open` only; `ReadSupportingTables` <- `Open`
  only; `nMetadataICBs` / `MetadataICBs` read only by `LogSector`, which runs after `Open`.
- No UI string, no resource, no plug-in interface change (no `.slt` refresh).
- `specs/356-uniso-udf-rest/probe/iso356_probe.ps1`: row `N-U250` (its expectation was this defect) is now
  `C-U250` (a.txt, deleted, no window).

## Probes

`iso377_probe.ps1` (IMAPI2FS seeds by 356's `imapiudf356.ps1`; `img377.py swap` / `metafar`):

| Row | before (main build, aac7105e) | after |
|---|---|---|
| C-U250 | FAIL - nothing, two read-error boxes, kept | PASS - a.txt, no window, deleted |
| C-U250SUB | FAIL - as C-U250 | PASS - a.txt, sub/b.txt, deleted |
| C-U250SWAP (PD first) | PASS | PASS |
| C-U201SUB | PASS | PASS |
| C-PLAIN | PASS | PASS |
| R-U250FAR | PASS - "Cannot read sector #00FFFF00", kept | PASS - the same |

Totals (RUN + END rows): before 10 / 2 (`probe/result_before.txt`), after 12 / 0 (`probe/result_after.txt`);
registry restored and identical both times. The swap control passes before the fix: the order of the two
descriptors is the cause (the item's reasoning, not verified in a debugger, is now measured).

## Checks

- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
- `.\build.cmd` → `BUILD SUCCEEDED` (warning C4267 at `udf.cpp` `AddFileDir` `fd.NameLen = strlen(...)` is
  older code, not this change).
- `saltests.exe` → `saltests: 30237 checks, 0 failed` (no new check - research R3).

## Regressions (new build)

- `iso356_probe.ps1` → 56 / 0 (`probe/regress_356.txt`; as recorded by 356, with row `C-U250` - formerly
  `N-U250` - now a.txt extracted, no window, image deleted).
- `iso358_probe.ps1` → 52 / 0 (`probe/regress_358.txt`; as recorded).
- `iso361_probe.ps1` → 24 / 0 (`probe/regress_361.txt`). Changed windows, both rows accept any box:
  `L-IMAPI250` (the unchanged 2.50 image) before "Cannot read sector #00000000." + directory error, now no
  window (it lists); `L-META5` (the metadata file entry with descriptor type 5) now reaches 361's refusal in
  the metadata caller - only "Error reading directory structure ... Incomplete content", no "Cannot read
  sector" - the 361 limit "the metadata-partition caller is reached by no probe" is reached now.
