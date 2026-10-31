# Fix log - 359-uniso-udf-vat-cut

Backlog item `iso-plug-in-a-cut-udf-vat-image-may-hang-the-listing` - ISO plug-in: a UDF VAT image cut a few
sectors after its partition start may hang the listing.

## Measurement before (main 13bcb6a1, Debug x64 build of HEAD)

- Images: `mk_cdr.img` by `specs/356-uniso-udf-rest/probe/mkudf356.sh` in WSL Ubuntu - 300 sectors, the
  partition descriptor (sectors 98 and 242) says start 257, length 3743; the anchor at 256, the VDS at 96-101,
  the VAT (extended file entry of type 248) in sector 299. New helper `probe/rawimg359.py` writes it cut short,
  as 2048-byte sectors or as a raw Mode 1 dump (2352-byte sectors; sync + header + data + 288 zero bytes),
  optionally with both partition descriptors' start changed (the reader checks no descriptor CRC).
- New probe `probe/iso359_probe.ps1` (built on 358's): 
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <probe>\iso359_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -OutFile ..."`
- Result `probe/result_before.txt`: **PASS 9, FAIL 5**:
  - L-RAWCUT (Enter) and R-RAWCUT (Unpack) on the raw Mode 1 dump cut to 260 sectors with the partition start
    set to 288: END FAIL `WM_NULL False` - the main window stopped answering, the probe ended the process. The
    hang: the plug-in counts the file as 611520 / 2048 = 298 sectors -> nSectors = 10; the read at 3736 fails ->
    fallback window 3..9 (sectors 291-297, past the file's 260) -> the read at 3 fails -> `3 - 7` wraps ->
    `10 < 0xFFFFFFFC` -> the same window again, for ever.
  - L-CUT3 / R-CUT3 (the item's row: 2048-byte sectors cut to partition start + 3): PASS - alive, "Missing
    virtual allocation table.", image kept. **The item's trigger does not hang**: `continue` in the do-while
    tests `vatLoc < lastVatLoc` (wrapped 0xFFFFFFFC < 3 is false) and the loop ends unread.
  - L-CUT0 (cut at the partition start, 257 sectors): RUN FAIL against the new expectation - "Missing virtual
    allocation table." (the wrapped window ends the loop unread) instead of the read error.
  - L-RAWFULL (the whole volume as a raw Mode 1 dump): "Error reading virtual allocation table at sector
    #00000050" - the raw dump of a whole VAT volume does not open because of the same bytes / 2048 count:
    a separate defect (Inbox item, T010). L-MKCDR: PASS (no window).
  - Registry restored, identical.

## Sites (read at HEAD)

- `src/plugins/uniso/udf.cpp` `CUDF::ReadSupportingTables`, case `mapVirtual`: `vatLoc = PD.Length -
  ExtentOffset - 7`, `lastVatLoc = vatLoc + 14`; `do { if (!ReadBlockPhys(vatLoc)) { size =
  GetCurrentTrackEnd(); nSectors = (DWORD)(size / 2048) - PD.Start; if (nSectors < vatLoc - 7) { vatLoc =
  nSectors - 7; lastVatLoc = nSectors; continue; } VatMissing = TRUE; return Error(READING_VAT); } ... vatLoc++;
  } while (vatLoc < lastVatLoc && vatRet == ERR_CONTINUE);`
- `CISOImage::GetCurrentTrackEnd` (isoimage.cpp): bytes of the track (file size or the next track's start less
  this track's start) - called only here.
- `CUDF::ReadBlockPhys` -> `Image->ReadBlock(PD.Start + lbNum)` -> `GetSectorOffset` (`SectorRawSize`): a read
  past the file's real end fails.
- Callers: `ReadSupportingTables` <- `CUDF::Open` <- `CISOImage::OpenTrack` (fsUDF), `CUDFISO::Open`
  (hybrids); FALSE = the "not opened" path of 358.

## Decisions

- At most one fallback per search; computed in 64 bits; no fallback when the file holds no partition sector
  (read error at once - the item's Expected); the condition otherwise the old one without the wrap
  (`n + 7 < failed`). The first window (around the claimed end) unchanged - bounded (spec Clarifications).

## Implementation

- `src/common/salisoudfvat.h`: `SalIsoUdfVatFallback(fileSectors, partStart, failed, taken, first, last)` -
  64-bit; false when taken already, when `fileSectors <= partStart`, or when `n + 7 >= failed`; else the window
  `[max(n - 7, 0), n)` (`n` = the file's partition sectors).
- `src/plugins/uniso/udf.cpp` `ReadSupportingTables` (mapVirtual): a local `fallbackTaken` (reset per search);
  the fallback through the rule; a negative track size (track start past the file) takes no fallback (the read
  error, as the -1 size already did).
- `src/saltests/saltests.cpp` `TestIsoUdfVat_359` (28 checks): the measured cases, the old condition where it did
  not wrap, 64-bit counts, and a model of the search loop with 32-bit sector numbers over 13 file sizes x 9
  partition starts x 12 claimed lengths x 4 readable limits (exact, raw 2048/2352, none, 3 short) - every search
  ends, at most 21 reads.
- Note: each guard alone ends the loop (after the fallback every failed sector is below `n + 7`); `taken` is kept
  as the item's "at most once" and as a second guard.

## Measurements after (Debug x64)

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | BUILD SUCCEEDED |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | 29,606 checks, 0 failed (358: 29,578) |
| mutant (T004) | the rule replaced by the old 32-bit arithmetic (`n < failed - 7`, `n - 7` wrapped, no `taken`), build, saltests | 29,606 checks, **20 failed**; header restored, rebuilt, 0 failed |
| encoding | `python tools/check_encoding.py --strict` | TOTAL: 0 finding(s) |

- No UI string, menu or dialog changed - no `.slt` refresh (stop-rules 2.13 does not apply).
- Inbox: `iso-plug-in-a-raw-2352-byte-sector-dump-of-a-udf-vat-disc` (measure:359) - the raw count, row
  L-RAWFULL.

## Analyze

- speckit-analyze: CRITICAL 0, HIGH 0. MEDIUM U1 (L-RAWFULL passes while documenting the raw count defect):
  accepted - named in the spec and the Inbox item. LOW C1 (include check in T005), C2 (changelog / history by
  the run's closing step): accepted.
