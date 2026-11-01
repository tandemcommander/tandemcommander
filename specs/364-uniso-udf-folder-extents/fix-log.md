# Fix log - 364-uniso-udf-folder-extents

Backlog item `iso-plug-in-a-udf-folder-stored-in-more-than-one-extent-is` (source review:362).

## Measurement before (main, b1d9e31b)

Sites at HEAD (found by name):

- `CUDF::MapICB(CAD, CICBTag*, CAD*)` (`src/plugins/uniso/udf.cpp`) reads the folder's entry with
  `ReadFileEntry(sector, ..., file, 1)` - room for one descriptor; the reader traces "UNSUPPORTED: Not enough CAD
  structures" and stops at the second.
- `CUDF::ScanDir(CAD dirICB, ...)` walks `dirICB.Length` bytes of the first extent from
  `LogSector(dirICB.Location)` with a two-sector window, contiguously; returns `ERR_OK`.
- Callers of `MapICB(CAD, CICBTag*, CAD*)`: `CUDF::ListDirectory` (the root) and `CUDF::ScanDir` (each
  sub-folder). Callers of `ScanDir`: the same two. Reached from Enter on an image and from Unpack (Alt+F9) - both
  list the image through `ListDirectory`.

Reproduction - new probe `probe/iso364_probe.ps1` (written before specify in `%TEMP%\tc364work`, copied here),
seeds `mkimg364.sh` (genisoimage -udf -R: root and `sub` with 40 files each; root 2,964 bytes, sub 2,920 bytes, one
short descriptor each, Information Length equal), 330's `mkimg330.sh` (ud.iso), changed by `img364.py`:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log %TEMP%\tc364work\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File %TEMP%\tc364work\iso364_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Specs E:\Projects\tandemcommander\specs -Label before"
```

Result `probe/result_before.txt`: **20 PASS / 8 FAIL**:

| Row | Before |
|---|---|
| R-ROOTSPLIT (2048 + 916 contiguous) | 28 of 80 UDF files (12 root + 40 sub missing), image deleted |
| R-ROOTFRAG (second extent at free block 89, block 4 zeroed) | 28 + one garbled name `a_rather_long_file_name_2`, deleted |
| R-SUBSPLIT | 68 (sub 28 .. 39 missing), deleted |
| R-SUBFRAG | 68 + garbled, deleted |
| R-ROOTCONT (second descriptor type 3) | the 28 files of the first extent, deleted, nothing marked |
| R-ROOTUNREC (second extent type 1) | the same, deleted |
| R-ALEN38 / R-ALEN40 (folder a 38 / 40 bytes, Information Length 88) | a/side.txt missing, deleted |
| C-BIG, C-UD, L-* | PASS (controls) |

Registry restored, identical (SHA-256 07F63FE1...).

## Decisions

- Walk every recorded extent (up to 32, as `UnpackFile`'s `icbs[32]`), and mark the listing incomplete when the
  walked extents are shorter than the entry's Information Length (both alternatives of *Expected*).
- Type 3 (allocation extent continuation) is not followed (files do not follow it either) - marked.
- The walk length stays the sum of the walked extents (not cut to a smaller Information Length): cutting would hide
  entries without a mark.
- A non-last extent not a whole number of blocks ends the walk (ECMA-167 4/12.1: only the last may end inside a
  block); a first descriptor that is not type 0 leaves nothing to walk -> 362's refusal.

## Analyze

`speckit-analyze` (one run): 0 CRITICAL, 0 HIGH; LOW C1 (listing rows only for the non-contiguous images - the
unpack rows list the contiguous ones first) and LOW U1 (embedded folders not named in T005 - data-model covers
them) accepted.

## Implementation

- `src/common/salisoudfentry.h`: `SAL_ISO_UDF_FOLDER_MAX_EXTENTS` (32), `SalIsoUdfFolderExtents` (walked extents,
  bytes, whole = bytes >= Information Length), `SalIsoUdfFolderSector` (which extent holds folder block k).
- `src/plugins/uniso/udf.h` / `udf.cpp`: `CUDFFolder`; `MapICB(CAD, CICBTag*, CUDFFolder*)` reads up to 32
  descriptors, takes the Information Length (offset 56 of both entry kinds), keeps 362's walkable check on the first
  WALKED extent; `ReadFolderWindow` fills the walk's two-block window through the extents (one two-block read inside
  an extent or past the last - the old reads for a one-extent folder; two one-block reads across a boundary);
  `ScanDir(const CUDFFolder&, ...)` walks with a 64-bit end; the root (`ListDirectory`) and every sub-folder mark
  `ListingLeftOut` incomplete when not `Whole`, then walk what was read.
- Changed for a case the item does not name (spec edge case): a folder whose FIRST descriptor is not a recorded
  extent (type 1 / 2 / 3) now takes 362's unreadable-folder path; before it was walked over bytes that are not
  recorded.
- `saltests`: `TestIsoUdfFolderExtents_364` (+43 checks).

## Measurement after

- `.\build.cmd` -> BUILD SUCCEEDED (the one warning, `udf.cpp` `fd.NameLen = strlen(...)` C4267, predates the feature).
- `saltests.exe` -> `saltests: 29791 checks, 0 failed` (was 29,748 at 363).
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- clang-format (VS 2022) on the feature's hunks only (`--lines`): no change.
- Probe `iso364_probe` after -> **28 PASS / 0 FAIL** (`probe/result_after.txt`; before 20 / 8): R-ROOTSPLIT,
  R-ROOTFRAG, R-SUBSPLIT, R-SUBFRAG 80 of 80 files, deleted; R-ROOTCONT, R-ROOTUNREC 28 files, KEPT; R-ALEN38 /
  R-ALEN40 5 files, KEPT; controls unchanged. Registry restored, identical.
- Regressions (same build): 330 30 / 0, 361 24 / 0, 362 34 / 0, 363 24 / 0, 356 56 / 0, 358 52 / 0
  (`probe/regress_*.txt`) - the recorded counts.
- No UI string, dialog or menu changed - no `.slt` refresh.
