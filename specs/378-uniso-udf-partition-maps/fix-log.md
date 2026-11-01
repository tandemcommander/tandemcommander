# Fix log - 378-uniso-udf-partition-maps

Backlog item `iso-plug-in-a-crafted-udf-partition-map-count-reads-past-the`: a crafted UDF partition map count
reads past the descriptor buffer in the ISO plug-in.

## Measurement at HEAD (main 514396d3, before the feature)

- Site: `CUDF::ReadLVD` (`src/plugins/uniso/udf.cpp`) unchanged since the 377 review: `mapCount` (byte 268) and
  `offset += ReadPartitionMap(sector + offset)` (the map's own length byte) bounded by nothing; the map table
  length (byte 264) read and unused; `ReadPartitionMap` allocates a `CPartitionMap` before anything is checked.
- Reachability: Enter / Alt+F9 on an image -> `CISOImage` track open -> `CUDF::Open` (UDF-only track, `fsUDF`)
  or `CUDFISO::Open` -> `CUDF::Open` (ISO 9660 + UDF) -> volume descriptor sequence loop -> `ReadLVD`.
  Callers enumerated: `ReadLVD` <- `CUDF::Open` only; `ReadPartitionMap` <- `ReadLVD` only; `CUDF::Open` <-
  `CISOImage` track open (`isoimage.cpp`) and `CUDFISO::Open` (`udfiso.cpp`). uniso is `on` in `plugins.cfg`.
- Seeds by IMAPI2FS (356's `imapiudf356.ps1`): UDF 2.01 / 2.01 bridge = LVD at sector 34, map table length 6,
  count 1, one type 1 map (`01 06 ...`); UDF 2.50 = table length 70, count 2 (type 1 + metadata map).
- New `probe/img378.py` crafts from them: `count` (count 100000, zero bytes after the map = length 0), `len0`,
  `table` (table length 4), `run` (count 100000, the rest of the sector 0xFF = maps of length 255 walking off
  the sector), `many` (268 six-byte maps filling the sector, count 300), and `count` on the bridge.
- The maintainer's Tandem Commander was running at the start (installed + this Debug build launched from it;
  the probe refuses then): a copy of the HEAD build was frozen in `%TEMP%\tcudfmaps_before\Debug_x64`
  (uniso.spl SHA-256 728DDE50...2A92) and the before run used it once the program was closed.
- `iso378_probe.ps1 -Label before` on the hidden desktop, frozen HEAD build (`probe/result_before.txt`, bridge
  rows again after their expectation was corrected: `probe/result_before2.txt`):

| Row | before (HEAD 514396d3) |
|---|---|
| C-U201, C-U250 | PASS - a.txt, no window, deleted |
| C-B201 | PASS (corrected expectation) - `ISO (UDF356)/A.TXT`, `UDF (UDF356)/a.txt`, no window, KEPT |
| R-COUNT, R-LEN0, R-TABLE, R-RUN, R-MANY | FAIL - a.txt extracted, no window, image DELETED (the damaged descriptor accepted; R-RUN / R-MANY read past the sector without a visible effect - no crash) |
| R-BCOUNT | FAIL - both folders, no window (UDF part accepted) |

  Registry restored and identical both runs. The read past the buffer itself is not visible from the GUI
  (no crash: the bytes past the sector on the stack happen to give maps that are taken); the probe shows that
  the descriptor is accepted, the rule's saltests show where the walk would go.
- Found on the way: the well-formed IMAPI2FS ISO 9660 + UDF image is KEPT by a whole unpack with "Delete archive
  after unpacking" and no window: its ISO 9660 volume says 297 sectors, the file holds 576 (the UDF part), and
  the rest rule (330 / 356) marks the listing. Fails closed, not this item -> Inbox (measure:378).

## Decisions

- Pure rule `src/common/salisoudfmaps.h` (`SalIsoUdfLvdMapsFit`): the area is [440, min(held, 440 + table
  length)); every declared map needs its 2 header bytes inside it, a length >= 2 and >= the bytes the reader
  takes from its type (type 1: 6, type 2: 44), and must end inside it. Count 0 = accepted (unchanged).
- `ReadLVD` returns BOOL and checks the rule before any map is recorded; `CUDF::Open` refuses the volume with
  `IDS_ERROR_LISTING_IMAGE` (existing text, the descriptor's sector), following `quiet`. No UI string change.

## Analyze

Run 1: 0 CRITICAL; HIGH F1 (US2 / SC-002 said the ISO 9660 + UDF seed is deleted - measured kept by the rest
rule) - fixed (US2 scenario 2, SC-002); LOW F2 (T003 wording) accepted. Run 2: 0 CRITICAL, 0 HIGH.

## Implementation

- `src/common/salisoudfmaps.h` (new, header-only): `SalIsoUdfPartitionMapMinLen(type)` (1 -> 6, 2 -> 44,
  others 2) and `SalIsoUdfLvdMapsFit(lvd, held, count)` - the area [440, min(held, 440 + MT_L)), every declared
  map's header, length (>= 2, >= its type's minimum) and end inside it, 64-bit arithmetic by subtraction.
- `udf.cpp` `CUDF::ReadLVD` returns `BOOL`: the rule first (nothing read, no `CPartitionMap` created when it
  refuses), then the unchanged walk over the checked count. `udf.h`: the declaration.
- `udf.cpp` `CUDF::Open`, `UDF_TAGID_LOGVOL`: a refused descriptor -> `Error(IDS_ERROR_LISTING_IMAGE, quiet,
  block)` and `return FALSE` (the existing path of a sector that cannot be read). No UI string, resource or
  plug-in interface change (no `.slt` refresh).
- `saltests.cpp` `TestIsoUdfMaps_378` (+31 checks): the measured IMAPI2FS shapes, count 0, a table longer
  than the sector, 268 maps filling the sector, the five crafted shapes, a map starting at byte 2047, a map
  ending 2 bytes past the sector, short type 1 / type 2 maps, count 2^32 - 1, short buffers; a grid (17 table
  lengths x 14 counts x 10 fill bytes x 5 first map types) - the rule accepts exactly the descriptors whose old
  walk stayed inside the area with long-enough maps, an accepted walk stays inside the area, the count is at
  most 804.
- Negative control: the rule with the table bound removed (`if (false && mapLen < ...)`) -> saltests 30268
  checks, **4 failed** (table 4, run with table 1608, grid `asOld`, `inArea`); restored -> 0 failed.

## Probes

`iso378_probe.ps1` (seeds by IMAPI2FS, crafted by `img378.py`):

| Row | before (frozen HEAD build, 514396d3) | after |
|---|---|---|
| C-U201 | PASS - a.txt, no window, deleted | PASS - the same |
| C-U250 | PASS - a.txt, no window, deleted | PASS - the same |
| C-B201 | PASS - both folders, no window, kept (rest rule, Inbox) | PASS - the same |
| R-COUNT | FAIL - a.txt, no window, deleted | PASS - nothing, "Error reading directory structure at sector #00000022. Incomplete content of ISO image.", kept |
| R-LEN0 | FAIL - as R-COUNT | PASS - as R-COUNT |
| R-TABLE | FAIL - as R-COUNT | PASS - as R-COUNT |
| R-RUN | FAIL - as R-COUNT (the walk past the sector gave no crash) | PASS - as R-COUNT |
| R-MANY | FAIL - as R-COUNT | PASS - as R-COUNT |
| R-BCOUNT | FAIL - both folders, no window | PASS - only `ISO (UDF356)/A.TXT`, the box twice (presumably once per opening of the image - the listing succeeds, the unpack opens it again; not traced), kept |

Totals (RUN + END rows): before 11 / 7 (`probe/result_before.txt`; bridge rows re-run with the corrected
expectation: `probe/result_before2.txt`, C-B201 PASS, R-BCOUNT FAIL), after 18 / 0 (`probe/result_after.txt`).
Registry restored and identical every run. Sector #00000022 = 34, the descriptor's sector.

## Regressions (new build)

- `iso356_probe.ps1` -> 56 / 0 (`probe/regress_356.txt`), `iso358_probe.ps1` -> 52 / 0 (`probe/regress_358.txt`),
  `iso361_probe.ps1` -> 24 / 0 (`probe/regress_361.txt`), `iso377_probe.ps1` -> 12 / 0 (`probe/regress_377.txt`) -
  as each feature recorded; registry restored and identical every run.

## Checks

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (warning C4267 at `udf.cpp` `AddFileDir` `fd.NameLen = strlen(...)` is
  older code, as recorded by 377).
- `saltests.exe` -> `saltests: 30268 checks, 0 failed` (377 recorded 30237; +31 of `TestIsoUdfMaps_378`).
