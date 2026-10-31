# Closing report - 360-uniso-udf-vat-bound
Backlog item: iso-plug-in-a-damaged-udf-vat-entry-writes-past-its-buffer - ISO plug-in: a damaged UDF VAT file entry makes the reader write past its table buffer
Outcome: closed

## What changed

- `src/common/salisoudfvat.h`: `SalIsoUdfVatTableLength` (information length <= 2^32 - 1, never cut),
  `SalIsoUdfVatDescArea` (the descriptor area inside the 2048-byte sector, 64-bit), `SalIsoUdfVatDescSize`
  (8 / 16 / 20, 0 embedded, -1 reserved 4 - 7), `SalIsoUdfVatDescFits`, `SalIsoUdfVatCopyFits`.
- `src/plugins/uniso/udf.cpp` / `udf.h`: `CUDF::ReadVAT` refuses (not a VAT, `ERR_CONTINUE`) an over-long
  length, an area outside the sector and a reserved descriptor type before allocating; `CUDF::ReadAllocDesc`
  takes the area's remaining bytes and the table's length and refuses a cut descriptor or a copy past the table.
- `src/saltests/saltests.cpp`: `TestIsoUdfVat_360`.
- Probe `probe/iso360_probe.ps1`, `probe/vat360.py`, `probe/vatext360.py` (review 1).
- No UI string, dialog or plug-in interface change; no translation refresh needed.

## Measurements (before / after, commands)

- Before (main ddf0465a, Debug): `probe/result_before.txt` - 9 RUN rows FAIL: heap corruption (R-ILM4, R-NILM4,
  R-V150ILM4, L-ILM4, L-LADBIG), a bug report (R-LADBIG), Run-Time Check Failure #3 (R-ADT5, L-ADT5), a lossy-cast
  run-time check (R-ILHUGE); controls pass.
- After: `probe/result_after.txt` 36 / 0; after review 1 (extent rows) `probe/result_after2.txt` **50 / 0**.
- Command: `powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile
  -ExecutionPolicy Bypass -File specs\360-uniso-udf-vat-bound\probe\iso360_probe.ps1 -Exe
  build\tandemcommander\Debug_x64\tandemcommander.exe ..."` (quickstart.md).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` → TOTAL: 0 finding(s).
- `.\build.cmd` → BUILD SUCCEEDED (one pre-existing C4267 warning at an unchanged line).
- `saltests` → 29,661 checks, 0 failed (29,613 before); mutants: copy bound dropped 5 failed, area bound dropped
  5 failed.
- Probes: 360 50 / 0; regressions 358 52 / 0 (`probe/regress_358.txt`), 359 14 / 0 (`probe/regress_359.txt`);
  registry restored and identical after every run.

## Reviews (findings and what was done)

- Review 1 (refute-first): no MUST. Its negative control (old `uniso.spl`) 12 / 8 FAIL. SHOULD 1 (extent path
  untested) - taken: `vatext360.py` and 7 rows. SHOULD 2 (`CUDF::ReadFileEntry` hangs on a reserved type, reads
  past the sector) - Inbox item. NOTEs recorded (refuse rather than clamp a rounded extent; probe text fixed;
  zero-length extent unchanged).

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below (`CHANGELOG.md` has no `[Unreleased]` section; versions are the maintainer's):

  ```text
  - **A damaged UDF disc image of a CD-R / DVD-R / BD-R could corrupt memory in the ISO plug-in** (feature 360).
    - **Before:** an image whose virtual allocation table (VAT) entry claimed more table data than the file's
      length, a descriptor area longer than its sector, a reserved descriptor type or a length over 4 GB made the
      plug-in write past its table buffer while the image was listed or unpacked - a crash, or memory corrupted
      without notice.
    - **Now:** such an entry is not taken as the table: the volume does not open ("Missing virtual allocation
      table."), nothing is extracted, and "Delete archive after unpacking" keeps the image.
    - **Limitation:** a table whose descriptors cover less than its length is still read (its tail is not
      defined); other damaged UDF file entries are a separate fix.
  ```

- No person-step item: everything was driven on the hidden desktop.

## New Inbox items (slug - title)

- `iso-plug-in-a-udf-vat-whose-descriptors-cover-less-than-its` - ISO plug-in: a UDF VAT whose descriptors cover
  less than its length is read with heap content (measure:360)
- `iso-plug-in-a-damaged-udf-file-entry-hangs-the-listing-or` - ISO plug-in: a damaged UDF file entry hangs the
  listing or reads past its sector (review:360)
