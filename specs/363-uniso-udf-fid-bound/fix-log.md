# Fix log - 363-uniso-udf-fid-bound

Backlog item `iso-plug-in-a-udf-file-identifier-with-a-long-implementation` (source review:361, NOTE 1 of review 2).

## Measurement before (main 443ee778)

- Sites at HEAD: `CUDF::ReadFileIdentifier` (`src/plugins/uniso/udf.cpp`) reads L_FI (byte 19) and L_IU (word 36)
  and calls `DecodeOSTACompressed(sector + 38 + iu, fi, fileName)` with no bound, returns
  `4 * ((38 + fi + iu + 3) / 4)`; `CUDF::ScanDir` holds `Uint8 directory[2 * SECTOR_SIZE]` and reads each
  identifier at `directory + p`, `p <= SECTOR_SIZE` (it steps one sector when `p > SECTOR_SIZE`).
- Callers (grep): `ReadFileIdentifier` - only `ScanDir`; `ScanDir` - `ListDirectory` (root) and itself. No other
  walk of identifiers (`UDF_TAGID_FID` only in `ScanDir`, `udf.h`). `p` starts at the descriptor's `Offset`: 0, or
  `< SECTOR_SIZE` for embedded data (feature 361's `ReadFileEntry`).
- Reachable: Enter on an image (listing), Alt+F9 Unpack - both run `ListDirectory` -> `ScanDir`, default
  configuration (uniso is on).
- `.\build.cmd` -> BUILD SUCCEEDED. New probe `probe/iso363_probe.ps1` (seed ud.iso by 330's `mkimg330.sh`, one
  identifier changed by `probe/img363.py`), run on the hidden desktop:

  ```text
  powershell -File tools\run_on_hidden_desktop.ps1 -Log <tmp>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <tmp>\iso363_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Specs E:\Projects\tandemcommander\specs -Label before_main_443ee778"
  ```

  `probe/result_before.txt`: **PASS 12, FAIL 8**. No crash, no window in any row. L-AIU / L-AIU4K / L-AFI: no
  message. R-AIU / R-AIU4K / R-AFI extracted `UDF (TC330)/_/side.txt` (folder `a` under a made-up name - the name
  read past the buffer decoded empty, 327's safe name `_`); R-TIU an empty file `UDF (TC330)/_`; R-SIU `UDF
  (TC330)/a/_`; **the image deleted** in all five. Controls L-UD, C-UD PASS. Registry restored, identical.

## Decisions

- Bound = the padded length (the step to the next identifier) within `sizeof(directory) - p` (research R1, R2).
- Refusal = the existing invalid-tag path (`Error(IDS_UDF_INVALID_TAG_ID); return ERR_CONTINUE;`), research R3.
- Analyze: no CRITICAL / HIGH; LOW U1 (362's recorded result is 34 / 0 with the review rows), I1 (equivalent
  wording) - accepted.

## Implementation

- `src/common/salisoudfentry.h`: `SalIsoUdfFidLength(held, pos, lFI, lIU, len)` - the padded identifier length when
  it lies whole in `[pos, held)`, computed by subtracting from what is left (no wrap); else false, `len` 0.
- `src/plugins/uniso/udf.cpp` / `udf.h`: `CUDF::ReadFileIdentifier(sector, held, ...)` asks the rule and returns 0
  without decoding the name when refused; `CUDF::ScanDir` passes `sizeof(directory) - p` and on 0 takes the
  existing invalid-tag path (`Error(IDS_UDF_INVALID_TAG_ID); return ERR_CONTINUE;`).
- `src/saltests/saltests.cpp`: `TestIsoUdfFid_363` - 24 value checks (genisoimage's shapes, the probe's damaged
  identifiers, the bound, wrap values) and a grid model of the walk (4 checks).

## Checks after

- `.\build.cmd` -> BUILD SUCCEEDED.
- `saltests` 29,720 -> **29,748 checks, 0 failed**.
- Negative control (T010): the rule's body replaced by `len = old padded length; return true;` (no bound) ->
  `saltests: 29748 checks, 18 failed`; restored, rebuilt -> 0 failed.
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Probe `probe/result_after.txt` (Debug, hidden desktop): **PASS 20, FAIL 0** (before 12 / 8). Every damaged row:
  the box "Invalid UDF Tag ID.", the program answers, no bug report; R-AIU / R-AIU4K / R-AFI the ISO 9660 part only,
  R-TIU + UDF `a/side.txt`, R-SIU + UDF `top.txt`; **image kept** in all five. Controls L-UD, C-UD unchanged
  (C-UD: six files, image deleted). Registry restored, identical.
- No UI string, dialog or resource changed: no `.slt` refresh needed (stop-rules §2.13 not triggered).
- Regressions (hidden desktop, same build): `probe/regress_330.txt` **30 / 0**, `probe/regress_361.txt` **24 / 0**,
  `probe/regress_362.txt` **34 / 0** (the recorded results of those features); registry restored, identical each.
