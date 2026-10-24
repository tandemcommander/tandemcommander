# Fix log - 340-nrg-session-count

Backlog item `iso-plug-in-an-nrg-session-count-above-the-image-s-tracks`.

## Measurement at 2b3f0716 (before)

- `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED (HEAD built, incremental).
- By reading: the session loop is now `CISOImage::ListTracks` (`src/plugins/uniso/isoimage.cpp`, called by
  `ListImage`): `int trackCount = Session[session]; int lastSessionTrack = firstSessionTrack + trackCount;
  for (track = firstSessionTrack; track < lastSessionTrack; track++) switch (Tracks[track]->FSType)` - no
  bound. `Session` is `TDirectArray<int>`; `nrg.cpp` `readSINF` stores the byte-swapped DWORD through
  `AddSessionTracks(int)`, so a count >= 2^31 is negative.
- Reachable: a `.nrg` file in the panel, Enter or Alt+F9 (`CISOImage::Open` -> `ReadSessionNRG` ->
  `ReadNRGRoot` -> `readSINF`; listing `ListImage` -> `ListTracks`), "session as directory" on by default
  (`uniso.cpp`), two or more SINF chunks.
- Probe (scratch, then `probe/iso340_probe.ps1` + `probe/img340.py`; seeds by 334's `mkimg334.sh` in WSL):
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine "powershell
  -NoProfile -ExecutionPolicy Bypass -File ...\iso340_probe.ps1 -Exe build\...\tandemcommander.exe -Lib
  ... -MkImg ... -Label before"` -> `probe/result_before.txt`: **PASS 5, FAIL 9**:
  - F-FIT (1, 1), F-ZERO (0, 2): PASS (extracted, image deleted);
  - S-OVER (1, 2), S-OVER1000 (1, 1000), S-EXTRA (1, 1, 1): TRACE_C "arraylt.h Line 115: Index is out of
    range (index = 2, Count = 2)";
  - S-NEG (0xFFFFFFFF, 2): "Index is out of range (index = -1, Count = 2)";
  - S-NEGEND (1, 0xFFFFFFFF): no stop, `Session 02/b.txt` not extracted (image kept by 334's left-out mark).
  - Registry restored, identical SHA-256.
- `BL verify` recorded.
- Other readers of `Session` (enumerated): `img.cpp` (CCD: counts derived from its own track list, sum
  = tracks), `isoimage.cpp` `Session.Add(1)` (plain image), `ListTracks` (this item), `viewer.cpp`
  `DumpInfo` (F3 information: walks the track table, reads `Session[session]` when a track index reaches
  the running sum - past the session table when the counts add up to *fewer* tracks; another defect,
  Inbox item below).
