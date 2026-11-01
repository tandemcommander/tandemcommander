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
