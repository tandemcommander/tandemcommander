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
