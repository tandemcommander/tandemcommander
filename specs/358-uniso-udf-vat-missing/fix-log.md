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

## Analyze

- speckit-analyze: CRITICAL 0, HIGH 0. MEDIUM C1 - no probe row for a UDF + ISO 9660 hybrid whose UDF part is a
  VAT volume without its VAT: accepted - the same `CUDF::Open` FALSE that 330's `CUDFISO::Open` already handles
  (`PartMissing` when the anchor at 256 is there). LOW U1 (T007's 2-byte table check) kept.

## Implementation

- `src/common/salisoudfvat.h` (new, header-only): `SalIsoUdfVatTranslates(lbNum, entries, hasTable)` = a table
  and `lbNum < entries`; `SalIsoUdfVat200Entries(infoLen, headerLen, tableLen, entries&)` refuses a header
  longer than the file or a file longer than the table held.
- `src/plugins/uniso/udf.cpp`: constructor sets `Entries` / `Length` to 0; `LogSector` (mapVirtual) through
  the rule; `CheckForVAT` (VAT 2.00) takes the count through the rule (a table under 2 bytes or a refused count
  -> not a VAT, `ERR_CONTINUE`); `ReadSupportingTables` returns FALSE when the VAT search ends without a VAT
  (`ERR_CONTINUE`: the existing "Missing virtual allocation table." box; `ERR_TERMINATE`: the callee's box).
- `src/saltests/saltests.cpp`: `TestIsoUdfVat_358` (25 checks; the 2.00 count rule also over a grid of
  65 x 24 x 15 lengths, summarized in two checks).
- Callers enumerated (research R4): `ReadSupportingTables` <- `CUDF::Open` only; `CUDF::Open` <-
  `CISOImage::OpenTrack` (fsUDF) and `CUDFISO::Open` (hybrids); `LogSector` <- `MapICB`, line 592,
  `ListDirectory`, `ScanDir`, `UnpackFile` - all take `INVALID_SECTOR_NUMBER` as a failed read.

## Measurements after (Debug x64)

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | BUILD SUCCEEDED (one pre-existing C4267 at udf.cpp:793, not a changed line) |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | 29,553 -> **29,578 checks, 0 failed** |
| negative control | `SalIsoUdfVatTranslates` mutated to `lbNum <= entries`, rebuilt | **4 failed** (0/0, 1/1, 300/300, 0xFFFFFFFF/0xFFFFFFFF); header restored, rebuilt, 0 failed |
| probe 358 | `iso358_probe.ps1 -Label after` (`probe/result_after.txt`) | **22 / 0** (before 14 / 8 on main 249e35f0: R-VCDR100, R-VCLAIM16, R-VCLAIM100Z, L-VCDR100 crashed) |
| regression 356 | `specs\356-uniso-udf-rest\probe\iso356_probe.ps1 -Label regress358` (`probe/regress_356.txt`) | **56 / 0** |
| encoding | `python tools/check_encoding.py --strict` | TOTAL: 0 finding(s) |

- After: each crash row shows exactly one box "Missing virtual allocation table." (the open by the Unpack / the
  listing), nothing extracted, the image kept, no bug report; C-VCLAIM keeps its "Error reading virtual
  allocation table" box; the plain mkudffs VAT images (cdr open / closed, dvdr, bdr) unpack with no window and
  are deleted as before.
- No UI string, menu or dialog changed - no `.slt` refresh (stop-rules 2.13 does not apply).
- Limit: the mkudffs images are empty file systems, so the probe's plain VAT rows prove "lists and unpacks
  successfully" (a failed translation would show "Error listing image" and keep the image) but extract no
  file; a VAT image with files needs a written disc (person step of 356 covers real images).

## Inbox

- `iso-plug-in-a-damaged-udf-vat-entry-writes-past-its-buffer` (measure:358) - `ReadVAT` / `ReadAllocDesc`
  copy descriptors into the table buffer without a bound (research R3; found by reading, not probed).

## Review

### Review 1 (refute-first, general-purpose agent) - no MUST

- Re-ran: saltests 29,578 / 0; probe 22 / 0 on the final build; 11 own rows on HEAD (UDF 1.50 VAT open / closed,
  VAT 2.00 without extended entries, both + 100 sectors, header longer than the file, header = file, one entry)
  all pass except X-OVF (the Inbox item). Negative control (main's `uniso.spl` in a copied tree): the 1.50 +
  data image crashes too (the committed probe did not cover the 1.50 path), the 0-entry header reads
  `Translation[0]` (#FDFDFDFD, the debug heap's guard bytes), the long header a garbage sector.
- SHOULD 1 - the Inbox item `iso-plug-in-a-damaged-udf-vat-entry-writes-past-its-buffer` reproduced (InformationLength
  160 -> 156, L_AD 160: Debug CRT "HEAP CORRUPTION DETECTED", block from `ReadVAT`; 358's count rule runs after the
  write). Taken: the reproduction recorded on the item (out of 358's scope).
- SHOULD 2 - the probe covered only VAT 2.00 in extended file entries and had no in-program control of the `<`
  bound. Taken: `probe/mkvat358.sh` (mkudffs UDF 1.50 open / closed, `--noefe`), `vatimg.py` kinds `hdlong`,
  `hdeq`; rows C-MK150, C-MK150C, C-MKNOEFE, R-V150D100, R-VNOEFED100, R-VHDLONG, R-VHDEQ (needs the invalid-sector
  box #FF567539 - the bound), L-VHDLONG, L-MK150. Result `probe/result_after2.txt`: **40 / 0**. Negative control
  with main's `uniso.spl` (reviewer's `%TEMP%\rev358\negtree`), new rows only:
  `probe/result_neg_main_uniso.txt` **7 / 7** (R-V150D100, R-VNOEFED100 crash; R-VHDLONG, L-VHDLONG read
  #8AAF3465 / #77A65B1F; R-VHDEQ #FDFDFDFD; C-MK150, L-MK150 pass).
- NOTE hybrid (by reading): `CUDFISO::Open` marked a UDF part that does not open only when an anchor is at
  sector 256 (330's sign); a UDF + ISO 9660 hybrid of a sequential medium whose VAT is missing and whose anchor is
  elsewhere would have its UDF part dropped with only the box, and "Delete archive after unpacking" could delete
  it - before 358 it crashed instead. Taken (fail closed, data safety): `CUDF::VatMissing` (set when the VAT is
  missing, its search terminated, or its sector unreadable - only after the volume descriptors were read), and
  `CUDFISO::Open` sets `PartMissing` from it. Not probed (no such hybrid can be built here; all mkudffs VAT images
  have the anchor at 256).
- NOTE viewer (F3 info) no longer prints the UDF info of a VAT image without its VAT (cosmetic); NOTE `UnpackFile`
  of a multi-session VAT image whose earlier track's VAT is missing, sessions-as-folders off: fails with "can't
  open track" (fails safely, not reproducible here); NOTE "#FF567539" in boxes is the internal invalid-sector
  marker (old, cosmetic) - recorded, not changed.
- NOTE padded real dumps (the VAT is in the file, sector 299 of 400) are refused - new Inbox item
  `iso-plug-in-a-udf-image-with-data-past-its-vat-does-not-open` (review:358).
- Housekeeping: the reviewer's bug report from its control run was already gone; its scratch is in
  `%TEMP%\rev358`. It reported a WSL command of its own that ran `rm -f *.img` in the repository root (variables
  empty); `git status` was clean - no tracked `.img` exists.
- After the changes: build SUCCEEDED, saltests 29,578 / 0, probe 40 / 0.
