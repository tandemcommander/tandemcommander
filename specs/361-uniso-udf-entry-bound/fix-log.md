# Fix log - 361-uniso-udf-entry-bound

Backlog item `iso-plug-in-a-damaged-udf-file-entry-hangs-the-listing-or` (source review:360).

## Measurement before (main 73bb1246, Debug x64, `build.cmd` up to date - BUILD SUCCEEDED)

- `git log --oneline 65c7e6a3..HEAD -- src/plugins/uniso src/common/salisoudfvat.h` prints nothing: the reader is
  the one review 1 of feature 360 measured - `vatext360.py rootadt5` (mk_cdr.img, the root folder's file entry
  descriptor type 5), Enter: the main window stopped answering (WM_NULL False), ended by the probe
  (`specs/360-uniso-udf-vat-bound/probe/result_rootadt5_review1.txt`, L-ROOTADT5 END FAIL).
- Code at HEAD, `CUDF::ReadFileEntry(Uint8*, bool, Uint16, CICBTag*, CAD*, int)`: `p = 176 (+40) + l_ea` and
  `while (p < l_ea + l_ad)` in 32 bits, no sector bound; the `switch (Flags & 7)` has no case 4 - 7 (no progress).

## Sites and callers (enumerated with Grep, fix protocol)

| Caller | maxAds | Reached by | On failure today |
|---|---|---|---|
| `ReadPartitionMap` (metadata partition map) | 32 | `CUDF::Open` of a UDF 2.50 volume | `nMetadataICBs` = count |
| `MapICB(CAD, CICBTag*, CAD*)` | 1 | `ListDirectory` (root) and `ScanDir` (each sub-folder) | 0 → "Bad root ICB" / listed empty + incomplete (330) |
| `UnpackFile` | 32 | Unpack / Copy of a file | mismatch box + `UNPACK_ERROR` |

Files are listed through `ReadFileEntry(BYTE*, bool, CFileEntry*)` (no descriptor walk): a damaged file entry is
reached by Unpack only. Embedded data (type 3): `Offset` = area start, `Length` = L_AD, used by `UnpackFile`
(`sector + Offset`, one 2048-byte buffer) and `ScanDir` (`directory + Offset`, two sectors).

## Decisions

- Refusal value `UDF_FE_REFUSED` (-2); callers map it to their existing unreadable-entry paths; no new UI string
  (spec Clarifications).
- A cut descriptor (L_AD not a multiple of the size) and a reserved type with L_AD 0 are refused too (360's rule;
  conservative).

## Probe before (73bb1246's build, `probe/result_before.txt`)

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\361-uniso-udf-entry-bound\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\tandemcommander\specs\361-uniso-udf-entry-bound\probe\iso361_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Label before-73bb1246"
```

Seeds: mk_cdr.img (`mkudf356.sh`), ud.iso (`mkimg330.sh`), imapi250.iso (`imapiudf356.ps1 -Revision 0x250`); damaged
copies by `probe/img361.py`. **Rows: PASS 11, FAIL 13** (RUN + END rows); registry restored and identical.

| Row | Before |
|---|---|
| L-ROOT5, R-ROOT5 | hang: no window, WM_NULL False, ended by the probe |
| L-FOLD5, R-FOLD5 | hang (the walk descends into a); R-FOLD5 extracted nothing |
| L-FOLDLEA, R-FOLDLEA | access violation "read on 0x...106EEC90" in uniso.spl (`ListArchive`), bug report |
| R-FILE5 | hang inside the unpack (progress window "Unpacking ISO Archive" left, timed out); the ISO 9660 part extracted |
| L-META5, L-IMAPI250 | PASS both: the IMAPI2FS 2.50 image fails earlier ("Cannot read sector #00000000", 356's older limit) - the metadata caller is not reached through it (deviation, below) |
| L-UD, C-UD, C-MKCDR | PASS (controls) |

## Implementation

- `src/common/salisoudfentry.h` (new): `SalIsoUdfEntryDescs(sectorLen, extended, lEA, lAD, type, first, end, size)`
  on 360's `SalIsoUdfVatDescArea` / `SalIsoUdfVatDescSize` - the area in the sector, 8 / 16 / 20 / 0; refused for
  a reserved type (also with L_AD 0), an area outside the sector, a cut descriptor.
- `CUDF::ReadFileEntry` (general): asks the rule first, returns `UDF_FE_REFUSED` (-2, `udf.h`); walks
  `for (p = first; p < end; p += size)`; embedded data as before (`Offset` now `(Uint16)first` - the field's type;
  the first build warned C4244 on a `(Uint32)` cast, fixed).
- Callers: `MapICB(CAD, CICBTag*, CAD*)` returns 0; `UnpackFile` - `IDS_UDF_ICB_AND_FILESIZE_MISMATCH` naming the
  file, `UNPACK_ERROR`; `ReadPartitionMap` (metadata) - 0 extents.
- `saltests`: `TestIsoUdfEntry_361` - measured cases; a grid (2 entry kinds x 10 L_EA x 18 L_AD x 8 types x 2
  maxAds) with the old 32-bit walk beside the new one: every taken entry's walk ends, stays in the sector and
  reads the same descriptors as before; every entry on which the old walk looped or read past the sector is
  refused; mkudffs / genisoimage shapes are taken.

## Checks

- `.\build.cmd` → BUILD SUCCEEDED (one warning C4267 at `fd.NameLen = strlen(...)` - pre-existing).
- `saltests.exe` → `saltests: 29697 checks, 0 failed` (29,661 before).
- clang-format: the changed lines formatted (`--lines`); the files keep main's count of legacy findings
  (udf.cpp 3, saltests.cpp include block as on main).

## Analyze (speckit-analyze, one run - no CRITICAL / HIGH)

- C1 MEDIUM: the metadata-partition caller has no probe row - tried below (mkudffs `--udfrev=0x0250`), else
  recorded.
- C2 LOW: no probe row for an embedded area past the sector - the `saltests` grid covers the rule.
- U1 LOW: the exact extracted list of the hybrid is fixed by the control row's measurement.
