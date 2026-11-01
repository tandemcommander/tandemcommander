# Fix log - 369-nrg-sinf-chunk-size

Backlog item `iso-plug-in-nrg-sinf-and-etn2-chunks-are-read-without-regard`.

## Measurement at 720a7472 (before)

- By reading (`src/plugins/uniso/nrg.cpp`):
  - `readSINF` reads `sizeof(DWORD)` whatever `header->Size`, does not check `read`, never seeks:
    still defective.
  - `readETN2` was rewritten by feature 365: whole `SAL_NRG_ETN2_ENTRY` entries into a stack buffer, each
    read checked, a chunk outside the image (`SalNrgChunkFits`) or implausible
    (`SalNrgEtn2ChunkPlausible`) skipped, `Seek(pos + Size)` at the end. The ETN2 half of the item's
    *Expected* already holds - no change.
  - `ReadNRGRoot` seeks to a chunk's end only for unknown chunks; `readDAOX` and `readSINF` do not end at
    their chunk's end themselves.
- Reachable: a `.nrg` file in the panel, Enter / Alt+F9 -> `CISOImage::Open` -> `ReadSessionInfo` ->
  `ReadSessionNRG` -> `ReadNRGRoot` -> `readSINF`.
- `.\build.cmd` (Debug x64, HEAD 720a7472) -> BUILD SUCCEEDED.
- Probe `probe/iso369_probe.ps1` + `probe/img369.py` (built on 340's; seeds by 334's `mkimg334.sh` in WSL),
  run from the session scratchpad with `-Lib` / `-MkImg` given:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile
  -ExecutionPolicy Bypass -File ...\iso369_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe
  -Lib ... -MkImg ... -Label before -OutFile ..."` -> `probe/result_before.txt` **PASS 6, FAIL 4**:
  - F-FIT (SINF 4: 1, 4: 1): PASS - both sessions, image deleted;
  - S-SINF8, S-SINF8TAIL, S-SINF2: only `Session 01/a.txt`, a box "UnISO - Unknown track type.", `b.txt`
    lost (image kept);
  - S-SINF0: only `Session 01/a.txt`, the same box, `Session 02/b.txt` lost.
  - Registry restored, identical SHA-256.
- `BL verify` recorded.

## Decisions

- A SINF chunk is used only at exactly 4 bytes, within the image, read whole; any other is refused (no
  count) and marks the listing incomplete (spec Assumptions: conservative - refuse rather than guess).
- `ReadNRGRoot` reads the next chunk header at `chunk start + Size` after every known reader (the item's
  first option), covering DAOX too.
