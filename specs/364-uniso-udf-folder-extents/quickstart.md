# Quickstart - 364-uniso-udf-folder-extents

Prerequisites: WSL Ubuntu (genisoimage fetched by 330's `mkimg330.sh`), Python, a Debug x64 build.

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestIsoUdfFolderExtents_364`).
3. Probe (PowerShell, hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\364-uniso-udf-folder-extents\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\364-uniso-udf-folder-extents\probe\iso364_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS (before: 20 / 8) - the four fragmented images unpack all 80 files and are deleted; the
   type 3 / type 1 / short-extent images are kept; controls unchanged.
4. Regressions: probes `specs/330-iso-unreadable-folder/probe/iso330_probe.ps1`,
   `specs/361-uniso-udf-entry-bound/probe/iso361_probe.ps1`, `specs/362-uniso-udf-folder-no-descs/probe/iso362_probe.ps1`,
   `specs/363-uniso-udf-fid-bound/probe/iso363_probe.ps1` with their recorded counts (30 / 0, 24 / 0, 34 / 0, 24 / 0).
