# Fix log - 360-uniso-udf-vat-bound

Backlog item `iso-plug-in-a-damaged-udf-vat-entry-writes-past-its-buffer` (source measure:358).

## Measurement before (main ddf0465a, Debug x64, `build.cmd` up to date)

Probe `probe/iso360_probe.ps1` (written for this feature from 358's `iso358_probe.ps1`; images: mkudffs by
`specs/356-uniso-udf-rest/probe/mkudf356.sh` and `specs/358-uniso-udf-vat-missing/probe/mkvat358.sh` in WSL,
changed in place by `probe/vat360.py`), run from `%TEMP%\tc360work` on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File ...\iso360_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Label before-ddf0465a"
```

Result `probe/result_before.txt` - RUN rows:

| Row | Image | Before |
|---|---|---|
| R-ILM4 | VAT 2.00, extended entry, IL 160 -> 156 (L_AD 160) | FAIL: CRT "HEAP CORRUPTION DETECTED ... after end of heap buffer", block allocated in uniso udf.cpp (ReadVAT) |
| R-NILM4 | same, plain file entry (mkudffs --noefe) | FAIL: heap corruption |
| R-V150ILM4 | UDF 1.50 VAT, IL 44 -> 40 | FAIL: heap corruption |
| R-LADBIG | L_AD 160 -> 4096 | FAIL: an exception bug report (TC0.2.0X64-...TXT), no box |
| R-ADT5 | ICB descriptor type 5 (reserved) | FAIL: Run-Time Check Failure #3 (uninitialised variable) in uniso.spl |
| R-LEAHUGE | L_EA 0xFFFFFF00 | PASS (only the missing-VAT box: the wrapped area read the descriptor tag as table data; 358's header rule refused the result) |
| R-ILHUGE | IL + 2^32 | FAIL: Run-Time Check Failure - a cast to a smaller data type lost data (`(int)fe.InformationLength`) |
| C-MKCDR, C-MKCDRC, C-MKDVDR, C-MKBDR, C-MK150, C-MK150C, C-MKNOEFE | plain mkudffs VAT images | PASS (no window, deleted) |
| L-ILM4, L-LADBIG | Enter on the images | FAIL: heap corruption |
| L-ADT5 | Enter | FAIL: Run-Time Check Failure #3 |
| L-MKCDR | Enter on mk_cdr | PASS |

Totals: 9 RUN rows FAIL, 9 PASS (the file's "PASS 18, FAIL 18" counts the END rows too). Registry restored and
identical.

## Sites and callers (enumerated, fix protocol)

- `CUDF::ReadVAT` (`src/plugins/uniso/udf.cpp`) - one caller, `CUDF::CheckForVAT` (both the VAT 2.00 and the
  UDF 1.50 branch); `CheckForVAT` has one caller, `CUDF::ReadSupportingTables` (case `mapVirtual`), which passes
  its 2048-byte stack `sector`. Reached by Enter / Alt+F9 / F3 on an image (`CUDF::Open`).
- `CUDF::ReadAllocDesc` - one caller, `ReadVAT` (Grep: `ReadAllocDesc` appears in udf.cpp and udf.h only).
- Additional site found by the measurement: `ReadAllocDesc`'s switch has no case for descriptor types 4 - 7 -
  `ad` uninitialised, `ReadBlock` writes `ad.Length` bytes at `vat + *o`, and `len` 0 never advances the walk.

## Decisions

- Refusal = `ERR_CONTINUE` ("not a VAT"; feature 358's missing-VAT path), no new message (research R2).
- Descriptors that cover less than the information length: accepted as before (research R3) - Inbox item.
- The strategy check stays first; length, area and type are decided before the allocation (research R4).

## Implementation

- `src/common/salisoudfvat.h`: `SalIsoUdfVatTableLength` (<= 2^32 - 1, never cut), `SalIsoUdfVatDescArea`
  (fixed part 176 / 216 + L_EA + L_AD within the sector, 64-bit), `SalIsoUdfVatDescSize` (8 / 16 / 20, 0 =
  embedded, -1 = reserved 4 - 7), `SalIsoUdfVatDescFits` (a descriptor inside the area), `SalIsoUdfVatCopyFits`
  (a copy inside the table).
- `CUDF::ReadVAT`: after the unchanged strategy check, refuses (`ERR_CONTINUE`, nothing allocated) a length over
  2^32 - 1, an area outside the sector, a reserved descriptor type; the walk passes the area's remaining bytes
  and the table's length.
- `CUDF::ReadAllocDesc` (+ `udf.h`): embedded data copies the whole remaining area only when it fits the table;
  a descriptor cut by the area's end or an extent past the table returns -1 (`ReadVAT` frees the table,
  `ERR_CONTINUE`).
- `saltests`: `TestIsoUdfVat_360` - the measured cases and a grid simulation of the walk (every taken copy in
  the table, every descriptor in the sector, the walk ends, mkudffs' shape always taken).

## Checks

- `.\build.cmd` → BUILD SUCCEEDED (one warning C4267 at udf.cpp `fd.NameLen = strlen(...)` - pre-existing, the
  line only moved).
- `saltests.exe` → `saltests: 29661 checks, 0 failed`.
- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
- Probe after (`probe/result_after.txt`, run from `specs\360-uniso-udf-vat-bound\probe`): **Rows: PASS 36, FAIL
  0** (18 RUN + 18 END rows); every damaged entry now shows only "Missing virtual allocation table.", the image
  is kept, no fatal window, no bug report; the controls unchanged. Registry restored and identical.
