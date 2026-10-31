# Fix log - 350-nrg-cuex-bounds

Backlog item `iso-plug-in-an-nrg-cuex-chunk-under-16-bytes-makes-a-huge` - "ISO plug-in: an NRG CUEX
chunk under 16 bytes makes a huge track count". Autonomous run (`/tandem-backlog-implement`), started
2026-10-31 on `main` at cadc65bb.

## Measure first (main, cadc65bb)

- Site: `src/plugins/uniso/nrg.cpp` `readCUEX` - unchanged since the item was written:
  `int trackCount = (header->Size - 0x10) / 0x10;` (DWORD from the image), the 16-byte header read
  without a length check, each entry read without a length check, `new CAudioTrack` + `AddTrack` per
  entry. No seek to the chunk's end.
- Reachable: opening any `*.nrg` in a panel - `CISOImage::Open` -> `ReadSessionInfo` (extension `nrg`)
  -> `ReadSessionNRG` -> `ReadNRGRoot` -> `readCUEX`. `uniso=on` in `plugins.cfg`.
- `CBufferedFile::Read` returns FALSE once a read reaches past the end of the file, so the loop ends
  there - after building one track from every 16 bytes up to it. `ReadNRGRoot` ignores the reader's
  result and reads the next header from where the reader stopped.
- Probe `probe/nrg350_probe.ps1` (images by `probe/img350.py`), Debug x64 build of cadc65bb, hidden
  desktop:

  ```text
  powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\nrg350_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib <repo>\specs\098-long-path-overruns\probe\fix_probe_lib.ps1 -OutFile <scratch>\rows_before.txt"
  ```

  Result `probe/result_before.txt`: PASS 5, FAIL 3 (rows RUN + END per case):
  - N-OK (control) PASS: opened, two tracks ("Copy 2 files", "Audio tracks cannot be extracted"),
    peak working set 84 MB, answering after 0.7 s;
  - N-SHORT FAIL: CUEX of 8 bytes + 96 MiB chunk + the good chunks - peak 1036 MB, 49.9 s, "Unknown
    file format or not a valid ISO image", not opened;
  - N-PAST FAIL: CUEX claiming 0xFFFFFFF0 bytes + 96 MiB chunk - peak 1037 MB, 49.9 s, same box;
  - N-ODD FAIL: CUEX 4 bytes longer than its two entries - not opened (the next header read 4 bytes
    early, "DAOX" taken as a size).
  Registry restored, identical (SHA-256 4576C7DA...).

`BL verify` recorded the reproduction.

## Decisions

- Entry count: `Size < 16 ? 0 : (Size - 16) / 16`, as a pure rule in `src/common/salnrgcdtext.h`
  next to 331's rules (FR-006).
- A chunk that does not lie within the image (`SalNrgChunkFits`) is skipped like an unknown chunk,
  as 331's CDTX reader does: no track. The image then does not open as NRG (as before) - but without
  building tracks first.
- After a chunk that fits, the reader seeks to the chunk's end (FR-004): a whole-entries chunk is
  consumed exactly as before; a short or odd-sized chunk no longer shifts the next header.
- A short read of the header or an entry: no track from it, the reader stops (returns FALSE as
  before).
- No 99-track cap (the item asks only for the chunk / image bounds) - a limit, see the closing report.

## Implementation

- `src/common/salnrgcdtext.h`: `SalNrgCuexEntryCount(size)` (+ `SAL_NRG_CUEX_HEADER` /
  `SAL_NRG_CUEX_ENTRY`), the header comment extended.
- `src/plugins/uniso/nrg.cpp` `readCUEX`: the chunk's position and the file size taken as in
  `readCDTX`; a chunk that does not fit is skipped (seek past, FALSE); the 16-byte header read only
  when the chunk holds it, every read checked for its full length (a short read: no track, FALSE);
  entries from the rule; after them a seek to `pos + Size`.
- `src/saltests/saltests.cpp`: `TestNrgCuex350` (15 checks: sizes 0..300 against an entry-by-entry
  reference, the named sizes, the old 32-bit formula, two `SalNrgChunkFits` cases).
- Analysis findings C1 / C2 (MEDIUM) taken into the probe: a bound row also needs the window
  answering within 5 s; an opened row needs "Copy 2 files" (both tracks listed). `result_before.txt`
  was taken with the earlier, looser conditions - its three FAIL rows fail the stricter ones too.

## Checks

- Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Build: `.\build.cmd` -> `BUILD SUCCEEDED` (uniso.spl and saltests.exe rebuilt after the edits,
  timestamps checked). No UI strings, menus or dialogs changed - no `.slt` refresh, no `full` build
  needed.
- saltests: `saltests: 29197 checks, 0 failed` (main: 29,182; +15).
- Probe after (`probe/result_after.txt`): PASS 8, FAIL 0 - N-OK 84 MB / 0.7 s; N-SHORT opened with
  its two tracks, 74 MB, 0.6 s (before 1036 MB, 49.9 s, not opened); N-PAST not opened (as wanted),
  74 MB, 0.6 s (before 1037 MB, 49.9 s); N-ODD opened with its two tracks (before not opened).
  Registry restored, identical.
- Regression: 329's probe `-Only A-OPEN` (`probe/regress_329.txt`): PASS 2, FAIL 0.

## Negative controls

- Mutant 1 (the rule back to `(unsigned int)(size - 16) / 16`, no guard): saltests 5 failed
  (smallOk, sizes 0, 8, 15, the old-formula check).
- Mutant 2 (the remainder counted as an entry, `(size - 16 + 15) / 16`): saltests 5 failed
  (smallOk, sizes 31, 52, 63, 0xFFFFFFFF).
- Mutant 3 (no seek to the chunk's end in `readCUEX`): probe `probe/result_mutant_no_seek.txt` PASS 7,
  FAIL 1 - N-ODD fails (not opened), the others pass. N-SHORT does not catch it: its 8 chunk bytes are
  zeros, which the chunk list reads as an empty unknown chunk - a limit of that row, N-ODD covers the
  seek.
- Each mutant restored from a copy; `grep MUTANT` -> 0; rebuilt; saltests 29,197 / 0.

## Limits

- No 99-track cap: a CUEX chunk that lies within the image can still hold (file size - 16) / 16
  entries when the footer's chunk offset points far before the end of the file (crafted only).
